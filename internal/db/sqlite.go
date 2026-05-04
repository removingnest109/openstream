package db

import (
	"context"
	"database/sql"
	_ "embed"
	"errors"
	"fmt"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

//go:embed schema.sql
var schemaSQL string

type Store struct {
	db *sql.DB
}

type TrackSource struct {
	Title         string
	Path          string
	DurationTicks int64
	TrackNumber   int
	AlbumTitle    string
	ArtistName    string
	Year          *int
	AlbumArtPath  *string
}

func Open(dbPath string) (*Store, error) {
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, err
	}

	db.SetMaxOpenConns(1)
	db.SetConnMaxLifetime(0)

	if err = db.Ping(); err != nil {
		return nil, err
	}

	store := &Store{db: db}
	if err = store.init(); err != nil {
		return nil, err
	}

	return store, nil
}

func (s *Store) Close() error {
	if s == nil || s.db == nil {
		return nil
	}
	return s.db.Close()
}

func (s *Store) init() error {
	_, err := s.db.Exec(schemaSQL)
	return err
}

func (s *Store) DB() *sql.DB {
	return s.db
}

func (s *Store) GetTracks(ctx context.Context, search string) ([]Track, error) {
	q := `
SELECT
    t.id,
    t.title,
    t.path,
    t.duration_ticks,
    t.track_number,
    t.album_id,
    t.date_added_utc,
    a.id,
    a.title,
    a.artist_id,
    a.year,
    a.album_art_path,
    ar.id,
    ar.name
FROM tracks t
JOIN albums a ON a.id = t.album_id
JOIN artists ar ON ar.id = a.artist_id
`
	args := []any{}
	if strings.TrimSpace(search) != "" {
		q += `WHERE t.title LIKE ? OR a.title LIKE ? OR ar.name LIKE ? `
		like := "%" + search + "%"
		args = append(args, like, like, like)
	}
	q += `ORDER BY ar.name, a.title, t.track_number, t.title`

	rows, err := s.db.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	tracks := []Track{}
	for rows.Next() {
		var (
			trackID, title, path, createdAt string
			durationTicks                   int64
			trackNum, albumID               int
			albumTitle                      string
			artistID                        int
			artistName                      string
			year                            sql.NullInt64
			albumArt                        sql.NullString
		)

		if err := rows.Scan(
			&trackID,
			&title,
			&path,
			&durationTicks,
			&trackNum,
			&albumID,
			&createdAt,
			&albumID,
			&albumTitle,
			new(int),
			&year,
			&albumArt,
			&artistID,
			&artistName,
		); err != nil {
			return nil, err
		}

		dt, err := time.Parse(time.RFC3339, createdAt)
		if err != nil {
			dt = time.Now().UTC()
		}

		var yearPtr *int
		if year.Valid {
			y := int(year.Int64)
			yearPtr = &y
		}

		var artPtr *string
		if albumArt.Valid && albumArt.String != "" {
			apiPath := fmt.Sprintf("/api/albumart/%s", albumArt.String)
			artPtr = &apiPath
		}

		artist := &Artist{ID: artistID, Name: artistName}
		album := &Album{
			ID:           albumID,
			Title:        albumTitle,
			ArtistID:     artistID,
			Artist:       artist,
			Year:         yearPtr,
			AlbumArtPath: artPtr,
		}

		tracks = append(tracks, Track{
			ID:          trackID,
			Title:       title,
			Path:        path,
			Duration:    ticksToDuration(durationTicks),
			TrackNumber: trackNum,
			AlbumID:     albumID,
			Album:       album,
			DateAdded:   dt,
		})
	}

	return tracks, rows.Err()
}

func (s *Store) GetTrackByID(ctx context.Context, id string) (*Track, error) {
	tracks, err := s.GetTracks(ctx, "")
	if err != nil {
		return nil, err
	}
	for i := range tracks {
		if tracks[i].ID == id {
			return &tracks[i], nil
		}
	}
	return nil, nil
}

func (s *Store) DeleteTrack(ctx context.Context, id string) (string, error) {
	var path string
	err := s.db.QueryRowContext(ctx, `SELECT path FROM tracks WHERE id = ?`, id).Scan(&path)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", sql.ErrNoRows
		}
		return "", err
	}

	_, err = s.db.ExecContext(ctx, `DELETE FROM tracks WHERE id = ?`, id)
	if err != nil {
		return "", err
	}

	return path, nil
}

func (s *Store) GetAlbumByID(ctx context.Context, id int) (*Album, error) {
	row := s.db.QueryRowContext(ctx, `
SELECT a.id, a.title, a.artist_id, a.year, a.album_art_path, ar.id, ar.name
FROM albums a
JOIN artists ar ON ar.id = a.artist_id
WHERE a.id = ?`, id)

	var (
		albumID, artistID int
		title, artistName string
		year              sql.NullInt64
		art               sql.NullString
	)
	if err := row.Scan(&albumID, &title, &artistID, &year, &art, &artistID, &artistName); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}

	var yearPtr *int
	if year.Valid {
		y := int(year.Int64)
		yearPtr = &y
	}

	var artPtr *string
	if art.Valid {
		v := art.String
		artPtr = &v
	}

	return &Album{
		ID:           albumID,
		Title:        title,
		ArtistID:     artistID,
		Artist:       &Artist{ID: artistID, Name: artistName},
		Year:         yearPtr,
		AlbumArtPath: artPtr,
	}, nil
}

func (s *Store) UpdateAlbumArt(ctx context.Context, albumID int, fileName string) error {
	res, err := s.db.ExecContext(ctx, `UPDATE albums SET album_art_path = ? WHERE id = ?`, fileName, albumID)
	if err != nil {
		return err
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (s *Store) GetPlaylists(ctx context.Context) ([]Playlist, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id, name, created_at_utc FROM playlists ORDER BY created_at_utc DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	playlists := []Playlist{}
	for rows.Next() {
		var (
			id            int
			name, created string
		)
		if err := rows.Scan(&id, &name, &created); err != nil {
			return nil, err
		}
		dt, _ := time.Parse(time.RFC3339, created)
		tracks, err := s.getPlaylistTracks(ctx, id)
		if err != nil {
			return nil, err
		}
		playlists = append(playlists, Playlist{ID: id, Name: name, CreatedAt: dt, Tracks: tracks})
	}
	return playlists, rows.Err()
}

func (s *Store) GetPlaylist(ctx context.Context, id int) (*Playlist, error) {
	var (
		name    string
		created string
	)
	err := s.db.QueryRowContext(ctx, `SELECT name, created_at_utc FROM playlists WHERE id = ?`, id).Scan(&name, &created)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	dt, _ := time.Parse(time.RFC3339, created)
	tracks, err := s.getPlaylistTracks(ctx, id)
	if err != nil {
		return nil, err
	}
	return &Playlist{ID: id, Name: name, CreatedAt: dt, Tracks: tracks}, nil
}

func (s *Store) CreatePlaylist(ctx context.Context, input PlaylistCreateInput) (*Playlist, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	created := time.Now().UTC().Format(time.RFC3339)
	res, err := tx.ExecContext(ctx, `INSERT INTO playlists(name, created_at_utc) VALUES(?, ?)`, input.Name, created)
	if err != nil {
		return nil, err
	}
	pid64, err := res.LastInsertId()
	if err != nil {
		return nil, err
	}
	pid := int(pid64)

	for _, tid := range input.TrackIDs {
		if _, err := tx.ExecContext(ctx, `INSERT OR IGNORE INTO playlist_tracks(playlist_id, track_id) VALUES(?, ?)`, pid, tid); err != nil {
			return nil, err
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}

	return s.GetPlaylist(ctx, pid)
}

func (s *Store) getPlaylistTracks(ctx context.Context, playlistID int) ([]Track, error) {
	q := `
SELECT
    t.id,
    t.title,
    t.path,
    t.duration_ticks,
    t.track_number,
    t.album_id,
    t.date_added_utc,
    a.id,
    a.title,
    a.artist_id,
    a.year,
    a.album_art_path,
    ar.id,
    ar.name
FROM playlist_tracks pt
JOIN tracks t ON t.id = pt.track_id
JOIN albums a ON a.id = t.album_id
JOIN artists ar ON ar.id = a.artist_id
WHERE pt.playlist_id = ?
ORDER BY ar.name, a.title, t.track_number, t.title`

	rows, err := s.db.QueryContext(ctx, q, playlistID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	tracks := []Track{}
	for rows.Next() {
		var (
			trackID, title, path, createdAt        string
			durationTicks                          int64
			trackNum, albumID, artistID, artistID2 int
			albumTitle, artistName                 string
			year                                   sql.NullInt64
			albumArt                               sql.NullString
		)

		if err := rows.Scan(&trackID, &title, &path, &durationTicks, &trackNum, &albumID, &createdAt, &albumID, &albumTitle, &artistID2, &year, &albumArt, &artistID, &artistName); err != nil {
			return nil, err
		}
		_ = artistID2
		dt, _ := time.Parse(time.RFC3339, createdAt)

		var yearPtr *int
		if year.Valid {
			y := int(year.Int64)
			yearPtr = &y
		}
		var artPtr *string
		if albumArt.Valid {
			v := albumArt.String
			artPtr = &v
		}

		tracks = append(tracks, Track{
			ID:          trackID,
			Title:       title,
			Path:        path,
			Duration:    ticksToDuration(durationTicks),
			TrackNumber: trackNum,
			AlbumID:     albumID,
			Album: &Album{
				ID:           albumID,
				Title:        albumTitle,
				ArtistID:     artistID,
				Year:         yearPtr,
				AlbumArtPath: artPtr,
			},
			DateAdded: dt,
		})
	}
	return tracks, rows.Err()
}

func (s *Store) ListTrackPaths(ctx context.Context) (map[string]string, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id, path FROM tracks`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := map[string]string{}
	for rows.Next() {
		var id, path string
		if err := rows.Scan(&id, &path); err != nil {
			return nil, err
		}
		result[strings.ToLower(path)] = id
	}
	return result, rows.Err()
}

func (s *Store) RemoveTracksByIDs(ctx context.Context, ids []string) error {
	if len(ids) == 0 {
		return nil
	}
	placeholders := strings.TrimRight(strings.Repeat("?,", len(ids)), ",")
	args := make([]any, 0, len(ids))
	for _, id := range ids {
		args = append(args, id)
	}
	_, err := s.db.ExecContext(ctx, `DELETE FROM tracks WHERE id IN (`+placeholders+`)`, args...)
	return err
}

func (s *Store) UpsertTrackFromScan(ctx context.Context, src TrackSource) (bool, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return false, err
	}
	defer tx.Rollback()

	artistID, err := getOrCreateArtist(ctx, tx, src.ArtistName)
	if err != nil {
		return false, err
	}
	albumID, existingArtPath, err := getOrCreateAlbum(ctx, tx, src.AlbumTitle, artistID, src.Year)
	if err != nil {
		return false, err
	}

	if src.AlbumArtPath != nil && *src.AlbumArtPath != "" && (existingArtPath == nil || *existingArtPath != *src.AlbumArtPath) {
		if _, err := tx.ExecContext(ctx, `UPDATE albums SET album_art_path = ? WHERE id = ?`, *src.AlbumArtPath, albumID); err != nil {
			return false, err
		}
	}

	id := newUUID()
	now := time.Now().UTC().Format(time.RFC3339)
	_, err = tx.ExecContext(ctx, `
INSERT INTO tracks(id, title, path, duration_ticks, track_number, album_id, date_added_utc)
VALUES(?, ?, ?, ?, ?, ?, ?)
`, id, src.Title, src.Path, src.DurationTicks, src.TrackNumber, albumID, now)
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "unique") {
			return false, nil
		}
		return false, err
	}

	if err := tx.Commit(); err != nil {
		return false, err
	}
	return true, nil
}

func (s *Store) GetTrackFilePath(ctx context.Context, id string) (string, error) {
	var path string
	err := s.db.QueryRowContext(ctx, `SELECT path FROM tracks WHERE id = ?`, id).Scan(&path)
	if err != nil {
		return "", err
	}
	return path, nil
}

func (s *Store) UpdateTrackMetadata(ctx context.Context, trackID string, input TrackEditInput) (string, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return "", err
	}
	defer tx.Rollback()

	var oldPath string
	err = tx.QueryRowContext(ctx, `SELECT path FROM tracks WHERE id = ?`, trackID).Scan(&oldPath)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", sql.ErrNoRows
		}
		return "", err
	}

	artistID, err := getOrCreateArtist(ctx, tx, input.ArtistName)
	if err != nil {
		return "", err
	}
	albumID, _, err := getOrCreateAlbum(ctx, tx, input.AlbumTitle, artistID, nil)
	if err != nil {
		return "", err
	}

	_, err = tx.ExecContext(ctx, `UPDATE tracks SET title = ?, album_id = ? WHERE id = ?`, input.Title, albumID, trackID)
	if err != nil {
		return "", err
	}

	if err := tx.Commit(); err != nil {
		return "", err
	}

	return oldPath, nil
}

func getOrCreateArtist(ctx context.Context, tx *sql.Tx, name string) (int, error) {
	if strings.TrimSpace(name) == "" {
		name = "Unknown Artist"
	}
	var id int
	err := tx.QueryRowContext(ctx, `SELECT id FROM artists WHERE name = ?`, name).Scan(&id)
	if err == nil {
		return id, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return 0, err
	}
	res, err := tx.ExecContext(ctx, `INSERT INTO artists(name) VALUES(?)`, name)
	if err != nil {
		return 0, err
	}
	newID, err := res.LastInsertId()
	if err != nil {
		return 0, err
	}
	return int(newID), nil
}

func getOrCreateAlbum(ctx context.Context, tx *sql.Tx, title string, artistID int, year *int) (int, *string, error) {
	if strings.TrimSpace(title) == "" {
		title = "Unknown Album"
	}
	var (
		id          int
		existingArt sql.NullString
	)
	err := tx.QueryRowContext(ctx, `SELECT id, album_art_path FROM albums WHERE title = ? AND artist_id = ?`, title, artistID).Scan(&id, &existingArt)
	if err == nil {
		var art *string
		if existingArt.Valid {
			v := existingArt.String
			art = &v
		}
		return id, art, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return 0, nil, err
	}

	res, err := tx.ExecContext(ctx, `INSERT INTO albums(title, artist_id, year) VALUES(?, ?, ?)`, title, artistID, year)
	if err != nil {
		return 0, nil, err
	}
	newID, err := res.LastInsertId()
	if err != nil {
		return 0, nil, err
	}
	return int(newID), nil, nil
}

func durationToTicks(d time.Duration) int64 {
	return d.Nanoseconds() / 100
}

func ticksToDuration(ticks int64) time.Duration {
	return time.Duration(ticks * 100)
}
