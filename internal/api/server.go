package api

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"log/slog"
	"mime"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/bogem/id3v2/v2"
	"github.com/go-chi/chi/v5"
	"github.com/removingnest109/openstream-lite/internal/db"
	"github.com/removingnest109/openstream-lite/internal/ingest"
)

type Server struct {
	store         *db.Store
	ingestService *ingest.Service
	staticDir     string
	embeddedUIFS  fs.FS
	webUIEnabled  bool
	maxUploadSize int64
	logger        *slog.Logger
}

func NewServer(store *db.Store, ingestService *ingest.Service, staticDir string, embeddedUIFS fs.FS, webUIEnabled bool, maxUploadSizeMB int64, logger *slog.Logger) *Server {
	return &Server{
		store:         store,
		ingestService: ingestService,
		staticDir:     staticDir,
		embeddedUIFS:  embeddedUIFS,
		webUIEnabled:  webUIEnabled,
		maxUploadSize: maxUploadSizeMB * 1024 * 1024,
		logger:        logger,
	}
}

func (s *Server) Handler() http.Handler {
	r := chi.NewRouter()

	r.Get("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		_, _ = w.Write([]byte("Healthy"))
	})

	r.Route("/api", func(api chi.Router) {
		api.Get("/tracks", s.getTracks)
		api.Get("/tracks/{id}/stream", s.streamTrack)
		api.Post("/tracks/upload", s.uploadTrack)
		api.Put("/tracks/{id}", s.editTrack)
		api.Delete("/tracks/{id}", s.deleteTrack)

		api.Get("/albumart/{fileName}", s.getAlbumArt)
		api.Post("/albums/{id}/art", s.uploadAlbumArt)

		api.Get("/playlists", s.getPlaylists)
		api.Get("/playlists/{id}", s.getPlaylist)
		api.Post("/playlists", s.createPlaylist)

		api.Post("/ingestion/scan", s.scanLibrary)
	})

	if !s.webUIEnabled {
		return r
	}

	return s.spaFallback(r)
}

func (s *Server) spaFallback(api http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/api/") || r.URL.Path == "/health" {
			api.ServeHTTP(w, r)
			return
		}

		assetPath := strings.TrimPrefix(path.Clean("/"+r.URL.Path), "/")
		if assetPath != "" && assetPath != "." {
			if s.serveAsset(w, r, assetPath) {
				return
			}
		}

		if s.serveAsset(w, r, "index.html") {
			return
		}

		http.NotFound(w, r)
	})
}

func (s *Server) serveAsset(w http.ResponseWriter, r *http.Request, assetPath string) bool {
	for _, source := range s.assetSources() {
		assetFile, err := source.fsys.Open(assetPath)
		if err != nil {
			continue
		}
		defer assetFile.Close()

		info, err := assetFile.Stat()
		if err != nil || info.IsDir() {
			continue
		}

		if reader, ok := assetFile.(io.ReadSeeker); ok {
			http.ServeContent(w, r, info.Name(), info.ModTime(), reader)
			return true
		}

		data, err := io.ReadAll(assetFile)
		if err != nil {
			continue
		}
		http.ServeContent(w, r, info.Name(), info.ModTime(), bytes.NewReader(data))
		return true
	}

	return false
}

type staticAssetSource struct {
	name string
	fsys fs.FS
}

func (s *Server) assetSources() []staticAssetSource {
	sources := make([]staticAssetSource, 0, 2)

	if s.staticDir != "" {
		if info, err := os.Stat(s.staticDir); err == nil && info.IsDir() {
			sources = append(sources, staticAssetSource{name: "disk", fsys: os.DirFS(s.staticDir)})
		}
	}

	if s.embeddedUIFS != nil {
		sources = append(sources, staticAssetSource{name: "embedded", fsys: s.embeddedUIFS})
	}

	return sources
}

func (s *Server) getTracks(w http.ResponseWriter, r *http.Request) {
	tracks, err := s.store.GetTracks(r.Context(), r.URL.Query().Get("search"))
	if err != nil {
		s.error(w, http.StatusInternalServerError, err)
		return
	}
	s.json(w, http.StatusOK, tracks)
}

func (s *Server) streamTrack(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	trackPath, err := s.store.GetTrackFilePath(r.Context(), id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.NotFound(w, r)
			return
		}
		s.error(w, http.StatusInternalServerError, err)
		return
	}
	if _, err := os.Stat(trackPath); err != nil {
		http.NotFound(w, r)
		return
	}

	ct := mediaType(trackPath)
	if ct != "" {
		w.Header().Set("Content-Type", ct)
	}
	http.ServeFile(w, r, trackPath)
}

func (s *Server) uploadTrack(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, s.maxUploadSize)
	if err := r.ParseMultipartForm(s.maxUploadSize); err != nil {
		s.json(w, http.StatusBadRequest, map[string]string{"error": "No file uploaded."})
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		s.json(w, http.StatusBadRequest, map[string]string{"error": "No file uploaded."})
		return
	}
	defer file.Close()

	if !s.ingestService.IsSupported(header.Filename) {
		s.json(w, http.StatusBadRequest, map[string]string{"error": "Unsupported file format."})
		return
	}

	savedPath, err := s.ingestService.SaveUploadedTrack(header.Filename, file)
	if err != nil {
		s.error(w, http.StatusInternalServerError, err)
		return
	}

	if err := s.ingestService.ScanLibrary(r.Context()); err != nil {
		s.error(w, http.StatusInternalServerError, err)
		return
	}

	s.json(w, http.StatusOK, map[string]string{"path": savedPath, "status": "Uploaded and scanned successfully."})
}

func (s *Server) editTrack(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var input db.TrackEditInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		s.json(w, http.StatusBadRequest, map[string]string{"error": "Invalid request body."})
		return
	}

	trackPath, err := s.store.UpdateTrackMetadata(r.Context(), id, input)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			s.json(w, http.StatusBadRequest, map[string]string{"error": "Track not found."})
			return
		}
		s.error(w, http.StatusInternalServerError, err)
		return
	}

	if err := writeFileMetadata(trackPath, input); err != nil {
		s.json(w, http.StatusBadRequest, map[string]string{"error": "Metadata updated in DB, but failed to update file: " + err.Error()})
		return
	}

	s.json(w, http.StatusOK, map[string]string{"status": "Track metadata updated successfully."})
}

func (s *Server) deleteTrack(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	deleteFile := strings.EqualFold(r.URL.Query().Get("deleteFile"), "true")

	trackPath, err := s.store.DeleteTrack(r.Context(), id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			s.json(w, http.StatusNotFound, map[string]string{"error": "Track not found."})
			return
		}
		s.error(w, http.StatusInternalServerError, err)
		return
	}

	if deleteFile {
		if err := os.Remove(trackPath); err != nil && !errors.Is(err, os.ErrNotExist) {
			s.json(w, http.StatusOK, map[string]string{"status": "Track deleted from DB, but failed to delete file.", "error": err.Error()})
			return
		}
	}

	s.json(w, http.StatusOK, map[string]string{"status": "Track deleted successfully."})
}

func (s *Server) getAlbumArt(w http.ResponseWriter, r *http.Request) {
	name := filepath.Base(chi.URLParam(r, "fileName"))
	artPath := filepath.Join(s.ingestService.MusicDir(), "albumart", name)
	if _, err := os.Stat(artPath); err == nil {
		w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
		http.ServeFile(w, r, artPath)
		return
	}

	if fallback := s.ingestService.LogoFallbackPath(); fallback != "" {
		if _, err := os.Stat(fallback); err == nil {
			w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
			http.ServeFile(w, r, fallback)
			return
		}
	}

	http.NotFound(w, r)
}

func (s *Server) uploadAlbumArt(w http.ResponseWriter, r *http.Request) {
	albumID, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		s.json(w, http.StatusBadRequest, map[string]string{"error": "Invalid album id."})
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		s.json(w, http.StatusBadRequest, map[string]string{"error": "No file uploaded."})
		return
	}
	defer file.Close()

	contentType := strings.ToLower(header.Header.Get("Content-Type"))
	name := strings.ToLower(header.Filename)
	if !strings.Contains(contentType, "jpeg") && !strings.HasSuffix(name, ".jpg") && !strings.HasSuffix(name, ".jpeg") {
		s.json(w, http.StatusBadRequest, map[string]string{"error": "Only JPG images are supported."})
		return
	}

	if _, err := s.ingestService.SaveAlbumArt(r.Context(), albumID, file); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			s.json(w, http.StatusBadRequest, map[string]string{"error": "Album not found."})
			return
		}
		s.error(w, http.StatusInternalServerError, err)
		return
	}

	s.json(w, http.StatusOK, map[string]string{"status": "Album art uploaded successfully."})
}

func (s *Server) getPlaylists(w http.ResponseWriter, r *http.Request) {
	items, err := s.store.GetPlaylists(r.Context())
	if err != nil {
		s.error(w, http.StatusInternalServerError, err)
		return
	}
	s.json(w, http.StatusOK, items)
}

func (s *Server) getPlaylist(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		s.json(w, http.StatusBadRequest, map[string]string{"error": "Invalid playlist id."})
		return
	}

	item, err := s.store.GetPlaylist(r.Context(), id)
	if err != nil {
		s.error(w, http.StatusInternalServerError, err)
		return
	}
	if item == nil {
		http.NotFound(w, r)
		return
	}
	s.json(w, http.StatusOK, item)
}

func (s *Server) createPlaylist(w http.ResponseWriter, r *http.Request) {
	var input db.PlaylistCreateInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		s.json(w, http.StatusBadRequest, map[string]string{"error": "Invalid request body."})
		return
	}

	item, err := s.store.CreatePlaylist(r.Context(), input)
	if err != nil {
		s.error(w, http.StatusInternalServerError, err)
		return
	}
	s.json(w, http.StatusCreated, item)
}

func (s *Server) scanLibrary(w http.ResponseWriter, r *http.Request) {
	if err := s.ingestService.ScanLibrary(r.Context()); err != nil {
		s.error(w, http.StatusInternalServerError, err)
		return
	}
	s.json(w, http.StatusOK, map[string]string{"status": "Scan complete"})
}

func (s *Server) json(w http.ResponseWriter, code int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(payload)
}

func (s *Server) error(w http.ResponseWriter, code int, err error) {
	s.logger.Error("request failed", "status", code, "err", err)
	s.json(w, code, map[string]string{"error": err.Error()})
}

func mediaType(path string) string {
	ext := strings.ToLower(filepath.Ext(path))
	switch ext {
	case ".mp3":
		return "audio/mpeg"
	case ".flac":
		return "audio/flac"
	case ".wav":
		return "audio/wav"
	case ".ogg":
		return "audio/ogg"
	case ".m4a":
		return "audio/mp4"
	default:
		return mime.TypeByExtension(ext)
	}
}

func writeFileMetadata(path string, input db.TrackEditInput) error {
	if strings.ToLower(filepath.Ext(path)) != ".mp3" {
		return fmt.Errorf("metadata write currently supports only .mp3 files")
	}

	tag, err := id3v2.Open(path, id3v2.Options{Parse: true})
	if err != nil {
		return err
	}
	defer tag.Close()

	tag.SetTitle(input.Title)
	artist := input.ArtistName
	if len(input.ArtistNames) > 0 {
		artist = strings.Join(input.ArtistNames, "; ")
	}
	tag.SetArtist(artist)
	tag.SetAlbum(input.AlbumTitle)
	return tag.Save()
}

func RunServer(ctx context.Context, addr string, handler http.Handler, logger *slog.Logger) error {
	httpServer := &http.Server{Addr: addr, Handler: handler, ReadHeaderTimeout: 10 * time.Second}
	errCh := make(chan error, 1)

	go func() {
		logger.Info("go-openstream listening", "addr", addr)
		errCh <- httpServer.ListenAndServe()
	}()

	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		return httpServer.Shutdown(shutdownCtx)
	case err := <-errCh:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	}
}

func ReadAll(body io.Reader) ([]byte, error) {
	if body == nil {
		return nil, nil
	}
	return io.ReadAll(body)
}
