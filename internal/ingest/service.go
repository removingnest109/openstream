package ingest

import (
	"context"
	"crypto/sha1"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/dhowden/tag"
	"github.com/removingnest109/openstream-lite/internal/db"
)

var supportedExtensions = map[string]struct{}{
	".mp3":  {},
	".flac": {},
	".m4a":  {},
	".wav":  {},
	".ogg":  {},
}

type Service struct {
	store        *db.Store
	musicDir     string
	logoFallback string
	logger       *slog.Logger
}

func NewService(store *db.Store, musicDir string, logoFallback string, logger *slog.Logger) *Service {
	return &Service{store: store, musicDir: musicDir, logoFallback: logoFallback, logger: logger}
}

func (s *Service) MusicDir() string {
	return s.musicDir
}

func (s *Service) LogoFallbackPath() string {
	return s.logoFallback
}

func (s *Service) IsSupported(path string) bool {
	_, ok := supportedExtensions[strings.ToLower(filepath.Ext(path))]
	return ok
}

func (s *Service) ScanLibrary(ctx context.Context) error {
	if err := os.MkdirAll(s.musicDir, 0o755); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Join(s.musicDir, "albumart"), 0o755); err != nil {
		return err
	}

	existing, err := s.store.ListTrackPaths(ctx)
	if err != nil {
		return err
	}

	seen := make(map[string]struct{})
	var addCount int

	err = filepath.WalkDir(s.musicDir, func(path string, d os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return nil
		}
		if d.IsDir() {
			if strings.EqualFold(d.Name(), "albumart") {
				return filepath.SkipDir
			}
			return nil
		}
		if !s.IsSupported(path) {
			return nil
		}

		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		norm := strings.ToLower(path)
		seen[norm] = struct{}{}
		if _, ok := existing[norm]; ok {
			return nil
		}

		src, err := s.readTrack(path)
		if err != nil {
			s.logger.Warn("readTrack failed", "path", path, "err", err)
			return nil
		}
		if src == nil {
			return nil
		}

		created, err := s.store.UpsertTrackFromScan(ctx, *src)
		if err != nil {
			s.logger.Warn("UpsertTrackFromScan failed", "path", path, "err", err)
			return nil
		}
		if created {
			addCount++
		}
		return nil
	})
	if err != nil && !errors.Is(err, context.Canceled) {
		return err
	}

	staleIDs := make([]string, 0)
	for p, id := range existing {
		if _, ok := seen[p]; !ok {
			staleIDs = append(staleIDs, id)
		}
	}

	if err := s.store.RemoveTracksByIDs(ctx, staleIDs); err != nil {
		return err
	}

	s.logger.Info("scan complete", "newTracks", addCount, "removedTracks", len(staleIDs))
	return nil
}

func (s *Service) readTrack(path string) (*db.TrackSource, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	meta, err := tag.ReadFrom(f)
	if err != nil {
		return nil, err
	}

	title := strings.TrimSpace(meta.Title())
	if title == "" {
		title = strings.TrimSuffix(filepath.Base(path), filepath.Ext(path))
	}

	albumTitle := strings.TrimSpace(meta.Album())
	if albumTitle == "" {
		albumTitle = "Unknown Album"
	}

	artistName := strings.TrimSpace(meta.Artist())
	if artistName == "" {
		artistName = "Unknown Artist"
	}
	trackArtists := splitArtistNames(artistName)
	if len(trackArtists) == 0 {
		trackArtists = []string{"Unknown Artist"}
	}

	albumArtists := readAlbumArtists(meta)
	if len(albumArtists) == 0 {
		albumArtists = append([]string(nil), trackArtists...)
	}

	trackNumber, _ := meta.Track()
	y := meta.Year()
	var year *int
	if y > 0 {
		yy := y
		year = &yy
	}

	var durationTicks int64

	var albumArtPath *string
	if picture := meta.Picture(); picture != nil && len(picture.Data) > 0 {
		artName := s.makeAlbumArtName(albumTitle, albumArtists)
		artFullPath := filepath.Join(s.musicDir, "albumart", artName)
		if _, statErr := os.Stat(artFullPath); errors.Is(statErr, os.ErrNotExist) {
			if writeErr := os.WriteFile(artFullPath, picture.Data, 0o644); writeErr != nil {
				s.logger.Warn("album art write failed", "path", artFullPath, "err", writeErr)
			}
		}
		albumArtPath = &artName
	}

	return &db.TrackSource{
		Title:         title,
		Path:          path,
		DurationTicks: durationTicks,
		TrackNumber:   trackNumber,
		AlbumTitle:    albumTitle,
		ArtistNames:   trackArtists,
		AlbumArtists:  albumArtists,
		Year:          year,
		AlbumArtPath:  albumArtPath,
	}, nil
}

func (s *Service) SaveUploadedTrack(fileName string, reader io.Reader) (string, error) {
	if err := os.MkdirAll(s.musicDir, 0o755); err != nil {
		return "", err
	}
	targetName := fmt.Sprintf("%s_%s", dbSafeNowID(), strings.ReplaceAll(filepath.Base(fileName), " ", "_"))
	fullPath := filepath.Join(s.musicDir, targetName)

	out, err := os.Create(fullPath)
	if err != nil {
		return "", err
	}
	defer out.Close()

	if _, err := io.Copy(out, reader); err != nil {
		return "", err
	}

	return fullPath, nil
}

func (s *Service) SaveAlbumArt(ctx context.Context, albumID int, reader io.Reader) (string, error) {
	if _, err := s.store.GetAlbumByID(ctx, albumID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", err
		}
		return "", err
	}

	dir := filepath.Join(s.musicDir, "albumart")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}

	name := strconv.Itoa(albumID) + ".jpg"
	fullPath := filepath.Join(dir, name)

	out, err := os.Create(fullPath)
	if err != nil {
		return "", err
	}
	defer out.Close()

	if _, err := io.Copy(out, reader); err != nil {
		return "", err
	}

	if err := s.store.UpdateAlbumArt(ctx, albumID, name); err != nil {
		return "", err
	}

	return name, nil
}

func (s *Service) makeAlbumArtName(albumTitle string, albumArtists []string) string {
	artists := strings.Join(splitArtistNames(strings.Join(albumArtists, "|")), "|")
	hash := sha1.Sum([]byte(strings.ToLower(strings.TrimSpace(albumTitle + "|" + artists))))
	return hex.EncodeToString(hash[:]) + ".jpg"
}

func readAlbumArtists(meta tag.Metadata) []string {
	if provider, ok := meta.(interface{ AlbumArtist() string }); ok {
		if names := splitArtistNames(provider.AlbumArtist()); len(names) > 0 {
			return names
		}
	}

	if provider, ok := meta.(interface{ Raw() map[string]interface{} }); ok {
		raw := provider.Raw()
		candidates := []string{"albumartist", "album artist", "tpe2", "aart", "----:com.apple.itunes:album artist"}
		for _, key := range candidates {
			for rawKey, rawValue := range raw {
				if !strings.EqualFold(strings.TrimSpace(rawKey), key) {
					continue
				}
				if names := splitArtistNames(fmt.Sprint(rawValue)); len(names) > 0 {
					return names
				}
			}
		}
	}

	return nil
}

func splitArtistNames(value string) []string {
	v := strings.TrimSpace(value)
	if v == "" {
		return nil
	}

	parts := []string{v}
	separators := []string{";", "/", "|", " feat. ", " ft. ", " featuring ", ", "}
	for _, sep := range separators {
		next := make([]string, 0, len(parts))
		for _, part := range parts {
			next = append(next, strings.Split(part, sep)...)
		}
		parts = next
	}

	seen := make(map[string]struct{}, len(parts))
	cleaned := make([]string, 0, len(parts))
	for _, part := range parts {
		name := strings.TrimSpace(part)
		if name == "" {
			continue
		}
		key := strings.ToLower(name)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		cleaned = append(cleaned, name)
	}

	return cleaned
}

func dbSafeNowID() string {
	return strconv.FormatInt(time.Now().UTC().UnixNano(), 10)
}
