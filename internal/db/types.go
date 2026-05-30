package db

import "time"

type Artist struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

type Album struct {
	ID           int     `json:"id"`
	Title        string  `json:"title"`
	ArtistID     int     `json:"artistId"`
	Artist       *Artist `json:"artist,omitempty"`
	Artists      []Artist `json:"artists,omitempty"`
	Year         *int    `json:"year"`
	AlbumArtPath *string `json:"albumArtPath"`
}

type Track struct {
	ID          string        `json:"id"`
	Title       string        `json:"title"`
	Path        string        `json:"path"`
	Duration    time.Duration `json:"duration"`
	TrackNumber int           `json:"trackNumber"`
	AlbumID     int           `json:"albumId"`
	Album       *Album        `json:"album"`
	Artists     []Artist      `json:"artists,omitempty"`
	DateAdded   time.Time     `json:"dateAdded"`
}

type Playlist struct {
	ID        int       `json:"id"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"createdAt"`
	Tracks    []Track   `json:"tracks"`
}

type PlaylistCreateInput struct {
	Name     string   `json:"name"`
	TrackIDs []string `json:"trackIds"`
}

type TrackEditInput struct {
	Title            string   `json:"title"`
	AlbumTitle       string   `json:"albumTitle"`
	ArtistName       string   `json:"artistName"`
	ArtistNames      []string `json:"artistNames"`
	AlbumArtistNames []string `json:"albumArtistNames"`
}
