package db

import (
	"context"
	"path/filepath"
	"testing"
	"time"
)

func TestGetPlaylistsWithTracksSingleConnection(t *testing.T) {
	t.Parallel()

	store, err := Open(filepath.Join(t.TempDir(), "openstream.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	defer store.Close()

	ctx := context.Background()

	res, err := store.DB().ExecContext(ctx, `INSERT INTO artists(name) VALUES(?)`, "Test Artist")
	if err != nil {
		t.Fatalf("insert artist: %v", err)
	}
	artistID, err := res.LastInsertId()
	if err != nil {
		t.Fatalf("artist id: %v", err)
	}

	res, err = store.DB().ExecContext(ctx, `
		INSERT INTO albums(title, primary_artist_id, artist_signature, year, album_art_path)
		VALUES(?, ?, ?, ?, ?)
	`, "Test Album", artistID, "test-artist", 2024, nil)
	if err != nil {
		t.Fatalf("insert album: %v", err)
	}
	albumID, err := res.LastInsertId()
	if err != nil {
		t.Fatalf("album id: %v", err)
	}

	if _, err := store.DB().ExecContext(ctx, `
		INSERT INTO album_artists(album_id, artist_id, artist_order, is_primary)
		VALUES(?, ?, 0, 1)
	`, albumID, artistID); err != nil {
		t.Fatalf("insert album artist: %v", err)
	}

	if _, err := store.DB().ExecContext(ctx, `
		INSERT INTO tracks(id, title, path, duration_ticks, track_number, album_id, date_added_utc)
		VALUES(?, ?, ?, ?, ?, ?, ?)
	`, "track-1", "Track One", "/tmp/track-1.mp3", 1234, 1, albumID, time.Now().UTC().Format(time.RFC3339)); err != nil {
		t.Fatalf("insert track: %v", err)
	}

	if _, err := store.DB().ExecContext(ctx, `
		INSERT INTO track_artists(track_id, artist_id, artist_order, is_primary)
		VALUES(?, ?, 0, 1)
	`, "track-1", artistID); err != nil {
		t.Fatalf("insert track artist: %v", err)
	}

	playlist, err := store.CreatePlaylist(ctx, PlaylistCreateInput{
		Name:     "Test Playlist",
		TrackIDs: []string{"track-1"},
	})
	if err != nil {
		t.Fatalf("create playlist: %v", err)
	}
	if playlist == nil {
		t.Fatal("expected playlist")
	}

	readCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	playlists, err := store.GetPlaylists(readCtx)
	if err != nil {
		t.Fatalf("get playlists: %v", err)
	}
	if len(playlists) != 1 {
		t.Fatalf("expected 1 playlist, got %d", len(playlists))
	}
	if len(playlists[0].Tracks) != 1 {
		t.Fatalf("expected 1 track, got %d", len(playlists[0].Tracks))
	}
	if playlists[0].Tracks[0].ID != "track-1" {
		t.Fatalf("expected track-1, got %q", playlists[0].Tracks[0].ID)
	}
}