package db

import (
	"context"
	"database/sql"
	_ "embed"
	"errors"
	"fmt"
	"sort"
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
	ArtistNames   []string
	AlbumArtists  []string
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
	a.primary_artist_id,
    a.year,
    a.album_art_path,
    ar.id,
    ar.name
FROM tracks t
JOIN albums a ON a.id = t.album_id
LEFT JOIN artists ar ON ar.id = a.primary_artist_id
`
	args := []any{}
	if strings.TrimSpace(search) != "" {
		q += `WHERE t.title LIKE ? OR a.title LIKE ? OR ar.name LIKE ? OR EXISTS (
			SELECT 1
			FROM track_artists ta
			JOIN artists sar ON sar.id = ta.artist_id
			WHERE ta.track_id = t.id AND sar.name LIKE ?
		) `
		like := "%" + search + "%"
		args = append(args, like, like, like, like)
	}
	q += `ORDER BY ar.name, a.title, t.track_number, t.title`

	rows, err := s.db.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	tracks := []Track{}
	trackByID := make(map[string]*Track)
	for rows.Next() {
		var (
			trackID, title, path, createdAt string
			durationTicks                   int64
			trackNum, albumID               int
			albumTitle                      string
			artistID                        sql.NullInt64
			artistName                      sql.NullString
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

		artist := &Artist{ID: 0, Name: "Unknown Artist"}
		if artistID.Valid {
			artist.ID = int(artistID.Int64)
		}
		if artistName.Valid && strings.TrimSpace(artistName.String) != "" {
			artist.Name = artistName.String
		}
		album := &Album{
			ID:           albumID,
			Title:        albumTitle,
			ArtistID:     artist.ID,
			Artist:       artist,
			Year:         yearPtr,
			AlbumArtPath: artPtr,
		}

		track := Track{
			ID:          trackID,
			Title:       title,
			Path:        path,
			Duration:    ticksToDuration(durationTicks),
			TrackNumber: trackNum,
			AlbumID:     albumID,
			Album:       album,
			DateAdded:   dt,
		}
		tracks = append(tracks, track)
		trackByID[trackID] = &tracks[len(tracks)-1]
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	if err := s.hydrateTrackArtists(ctx, trackByID); err != nil {
		return nil, err
	}
	if err := s.hydrateAlbumArtists(ctx, tracks); err != nil {
		return nil, err
	}

	return tracks, nil
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
SELECT a.id, a.title, a.primary_artist_id, a.year, a.album_art_path, ar.id, ar.name
FROM albums a
LEFT JOIN artists ar ON ar.id = a.primary_artist_id
WHERE a.id = ?`, id)

	var (
		albumID          int
		primaryArtistID  int
		title            string
		artistID         sql.NullInt64
		artistName       sql.NullString
		year              sql.NullInt64
		art               sql.NullString
	)
	if err := row.Scan(&albumID, &title, &primaryArtistID, &year, &art, &artistID, &artistName); err != nil {
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

	album := &Album{
		ID:           albumID,
		Title:        title,
		ArtistID:     primaryArtistID,
		Artist:       &Artist{ID: primaryArtistID, Name: "Unknown Artist"},
		Year:         yearPtr,
		AlbumArtPath: artPtr,
	}
	if artistID.Valid {
		album.Artist.ID = int(artistID.Int64)
		album.ArtistID = int(artistID.Int64)
	}
	if artistName.Valid && strings.TrimSpace(artistName.String) != "" {
		album.Artist.Name = artistName.String
	}

	artists, err := s.getAlbumArtists(ctx, []int{albumID})
	if err != nil {
		return nil, err
	}
	if list, ok := artists[albumID]; ok {
		album.Artists = list
		if len(list) > 0 {
			album.Artist = &Artist{ID: list[0].ID, Name: list[0].Name}
			album.ArtistID = list[0].ID
		}
	}

	return album, nil
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
	a.primary_artist_id,
    a.year,
    a.album_art_path,
    ar.id,
    ar.name
FROM playlist_tracks pt
JOIN tracks t ON t.id = pt.track_id
JOIN albums a ON a.id = t.album_id
LEFT JOIN artists ar ON ar.id = a.primary_artist_id
WHERE pt.playlist_id = ?
ORDER BY ar.name, a.title, t.track_number, t.title`

	rows, err := s.db.QueryContext(ctx, q, playlistID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	tracks := []Track{}
	trackByID := make(map[string]*Track)
	for rows.Next() {
		var (
			trackID, title, path, createdAt string
			durationTicks                   int64
			trackNum, albumID               int
			albumTitle                      string
			artistID                        sql.NullInt64
			artistName                      sql.NullString
			year                            sql.NullInt64
			albumArt                        sql.NullString
		)

		if err := rows.Scan(&trackID, &title, &path, &durationTicks, &trackNum, &albumID, &createdAt, &albumID, &albumTitle, new(int), &year, &albumArt, &artistID, &artistName); err != nil {
			return nil, err
		}
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

		albumArtist := Artist{ID: 0, Name: "Unknown Artist"}
		if artistID.Valid {
			albumArtist.ID = int(artistID.Int64)
		}
		if artistName.Valid && strings.TrimSpace(artistName.String) != "" {
			albumArtist.Name = artistName.String
		}

		track := Track{
			ID:          trackID,
			Title:       title,
			Path:        path,
			Duration:    ticksToDuration(durationTicks),
			TrackNumber: trackNum,
			AlbumID:     albumID,
			Album: &Album{
				ID:           albumID,
				Title:        albumTitle,
				ArtistID:     albumArtist.ID,
				Artist:       &albumArtist,
				Year:         yearPtr,
				AlbumArtPath: artPtr,
			},
			DateAdded: dt,
		}
		tracks = append(tracks, track)
		trackByID[trackID] = &tracks[len(tracks)-1]
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if err := s.hydrateTrackArtists(ctx, trackByID); err != nil {
		return nil, err
	}
	if err := s.hydrateAlbumArtists(ctx, tracks); err != nil {
		return nil, err
	}
	return tracks, nil
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

	trackArtists := normalizeArtistNames(src.ArtistNames)
	albumArtists := normalizeArtistNames(src.AlbumArtists)
	if len(trackArtists) == 0 {
		trackArtists = []string{"Unknown Artist"}
	}
	if len(albumArtists) == 0 {
		albumArtists = append([]string(nil), trackArtists...)
	}

	albumID, existingArtPath, err := getOrCreateAlbum(ctx, tx, src.AlbumTitle, albumArtists, src.Year)
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

	artistRows, err := getOrCreateArtists(ctx, tx, trackArtists)
	if err != nil {
		return false, err
	}
	if err := replaceTrackArtists(ctx, tx, id, artistRows); err != nil {
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

	trackArtists := normalizeArtistNames(input.ArtistNames)
	if len(trackArtists) == 0 {
		trackArtists = splitArtistString(input.ArtistName)
	}
	if len(trackArtists) == 0 {
		trackArtists = []string{"Unknown Artist"}
	}

	albumArtists := normalizeArtistNames(input.AlbumArtistNames)
	if len(albumArtists) == 0 {
		albumArtists = append([]string(nil), trackArtists...)
	}

	albumID, _, err := getOrCreateAlbum(ctx, tx, input.AlbumTitle, albumArtists, nil)
	if err != nil {
		return "", err
	}

	_, err = tx.ExecContext(ctx, `UPDATE tracks SET title = ?, album_id = ? WHERE id = ?`, input.Title, albumID, trackID)
	if err != nil {
		return "", err
	}

	artistRows, err := getOrCreateArtists(ctx, tx, trackArtists)
	if err != nil {
		return "", err
	}
	if err := replaceTrackArtists(ctx, tx, trackID, artistRows); err != nil {
		return "", err
	}

	if err := tx.Commit(); err != nil {
		return "", err
	}

	return oldPath, nil
}

func getOrCreateArtists(ctx context.Context, tx *sql.Tx, names []string) ([]Artist, error) {
	normalized := normalizeArtistNames(names)
	if len(normalized) == 0 {
		normalized = []string{"Unknown Artist"}
	}

	result := make([]Artist, 0, len(normalized))
	for _, name := range normalized {
		var id int
		err := tx.QueryRowContext(ctx, `SELECT id FROM artists WHERE name = ?`, name).Scan(&id)
		if err == nil {
			result = append(result, Artist{ID: id, Name: name})
			continue
		}
		if !errors.Is(err, sql.ErrNoRows) {
			return nil, err
		}

		res, err := tx.ExecContext(ctx, `INSERT INTO artists(name) VALUES(?)`, name)
		if err != nil {
			return nil, err
		}
		newID, err := res.LastInsertId()
		if err != nil {
			return nil, err
		}
		result = append(result, Artist{ID: int(newID), Name: name})
	}

	return result, nil
}

func getOrCreateAlbum(ctx context.Context, tx *sql.Tx, title string, artistNames []string, year *int) (int, *string, error) {
	if strings.TrimSpace(title) == "" {
		title = "Unknown Album"
	}
	artists := normalizeArtistNames(artistNames)
	if len(artists) == 0 {
		artists = []string{"Unknown Artist"}
	}

	signature := artistSignature(artists)
	var (
		id          int
		existingArt sql.NullString
	)
	err := tx.QueryRowContext(ctx, `SELECT id, album_art_path FROM albums WHERE title = ? AND artist_signature = ?`, title, signature).Scan(&id, &existingArt)
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

	artistRows, err := getOrCreateArtists(ctx, tx, artists)
	if err != nil {
		return 0, nil, err
	}
	primaryArtistID := artistRows[0].ID

	res, err := tx.ExecContext(ctx, `INSERT INTO albums(title, primary_artist_id, artist_signature, year) VALUES(?, ?, ?, ?)`, title, primaryArtistID, signature, year)
	if err != nil {
		return 0, nil, err
	}
	newID, err := res.LastInsertId()
	if err != nil {
		return 0, nil, err
	}
	albumID := int(newID)
	for i, artist := range artistRows {
		isPrimary := 0
		if i == 0 {
			isPrimary = 1
		}
		if _, err := tx.ExecContext(ctx, `
INSERT INTO album_artists(album_id, artist_id, artist_order, is_primary)
VALUES(?, ?, ?, ?)
`, albumID, artist.ID, i, isPrimary); err != nil {
			return 0, nil, err
		}
	}

	return albumID, nil, nil
}

func replaceTrackArtists(ctx context.Context, tx *sql.Tx, trackID string, artists []Artist) error {
	if _, err := tx.ExecContext(ctx, `DELETE FROM track_artists WHERE track_id = ?`, trackID); err != nil {
		return err
	}
	for i, artist := range artists {
		isPrimary := 0
		if i == 0 {
			isPrimary = 1
		}
		if _, err := tx.ExecContext(ctx, `
INSERT INTO track_artists(track_id, artist_id, artist_order, is_primary)
VALUES(?, ?, ?, ?)
`, trackID, artist.ID, i, isPrimary); err != nil {
			return err
		}
	}
	return nil
}

func normalizeArtistNames(names []string) []string {
	seen := make(map[string]struct{}, len(names))
	result := make([]string, 0, len(names))
	for _, raw := range names {
		v := strings.TrimSpace(raw)
		if v == "" {
			continue
		}
		key := strings.ToLower(v)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		result = append(result, v)
	}
	return result
}

func splitArtistString(value string) []string {
	v := strings.TrimSpace(value)
	if v == "" {
		return nil
	}

	parts := []string{v}
	separators := []string{";", "/", "|", " feat. ", " ft. ", " featuring ", ", "}
	for _, sep := range separators {
		next := make([]string, 0, len(parts))
		for _, item := range parts {
			fragments := strings.Split(item, sep)
			for _, fragment := range fragments {
				next = append(next, fragment)
			}
		}
		parts = next
	}
	return normalizeArtistNames(parts)
}

func artistSignature(artistNames []string) string {
	normalized := normalizeArtistNames(artistNames)
	if len(normalized) == 0 {
		normalized = []string{"Unknown Artist"}
	}
	lowered := make([]string, 0, len(normalized))
	for _, name := range normalized {
		lowered = append(lowered, strings.ToLower(strings.TrimSpace(name)))
	}
	sort.Strings(lowered)
	return strings.Join(lowered, "\x1f")
}

func (s *Store) hydrateTrackArtists(ctx context.Context, trackByID map[string]*Track) error {
	if len(trackByID) == 0 {
		return nil
	}

	rows, err := s.db.QueryContext(ctx, `
SELECT ta.track_id, ar.id, ar.name
FROM track_artists ta
JOIN artists ar ON ar.id = ta.artist_id
ORDER BY ta.track_id, ta.artist_order, ar.name`)
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var (
			trackID    string
			artistID   int
			artistName string
		)
		if err := rows.Scan(&trackID, &artistID, &artistName); err != nil {
			return err
		}
		track, ok := trackByID[trackID]
		if !ok {
			continue
		}
		track.Artists = append(track.Artists, Artist{ID: artistID, Name: artistName})
	}
	if err := rows.Err(); err != nil {
		return err
	}

	for _, track := range trackByID {
		if len(track.Artists) > 0 {
			track.Album.Artist = &Artist{ID: track.Album.ArtistID, Name: track.Album.Artist.Name}
			continue
		}
		track.Artists = []Artist{{ID: track.Album.ArtistID, Name: track.Album.Artist.Name}}
	}

	return nil
}

func (s *Store) hydrateAlbumArtists(ctx context.Context, tracks []Track) error {
	albumIDs := make(map[int]struct{}, len(tracks))
	for _, track := range tracks {
		if track.Album != nil {
			albumIDs[track.Album.ID] = struct{}{}
		}
	}
	if len(albumIDs) == 0 {
		return nil
	}

	ids := make([]int, 0, len(albumIDs))
	for id := range albumIDs {
		ids = append(ids, id)
	}
	artistsByAlbum, err := s.getAlbumArtists(ctx, ids)
	if err != nil {
		return err
	}

	for i := range tracks {
		if tracks[i].Album == nil {
			continue
		}
		if artists, ok := artistsByAlbum[tracks[i].Album.ID]; ok && len(artists) > 0 {
			tracks[i].Album.Artists = artists
			tracks[i].Album.Artist = &Artist{ID: artists[0].ID, Name: artists[0].Name}
			tracks[i].Album.ArtistID = artists[0].ID
			continue
		}
		tracks[i].Album.Artists = []Artist{{ID: tracks[i].Album.ArtistID, Name: tracks[i].Album.Artist.Name}}
	}

	return nil
}

func (s *Store) getAlbumArtists(ctx context.Context, albumIDs []int) (map[int][]Artist, error) {
	if len(albumIDs) == 0 {
		return map[int][]Artist{}, nil
	}

	placeholders := strings.TrimRight(strings.Repeat("?,", len(albumIDs)), ",")
	args := make([]any, 0, len(albumIDs))
	for _, id := range albumIDs {
		args = append(args, id)
	}

	rows, err := s.db.QueryContext(ctx, `
SELECT aa.album_id, ar.id, ar.name
FROM album_artists aa
JOIN artists ar ON ar.id = aa.artist_id
WHERE aa.album_id IN (`+placeholders+`)
ORDER BY aa.album_id, aa.artist_order, ar.name`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make(map[int][]Artist, len(albumIDs))
	for rows.Next() {
		var (
			albumID    int
			artistID   int
			artistName string
		)
		if err := rows.Scan(&albumID, &artistID, &artistName); err != nil {
			return nil, err
		}
		result[albumID] = append(result[albumID], Artist{ID: artistID, Name: artistName})
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return result, nil
}

func durationToTicks(d time.Duration) int64 {
	return d.Nanoseconds() / 100
}

func ticksToDuration(ticks int64) time.Duration {
	return time.Duration(ticks * 100)
}
