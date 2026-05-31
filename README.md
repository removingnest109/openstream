# openstream

![WebUI](screenshots/openstream.png)

Openstream is a lightweight, portable self-hosted music library and streaming server. It scans a user defined music directory, ingests metadata into a SQLite database, and provides a REST API and Web UI for browsing and streaming your music collection.

## Features

- Automatic music library scanning and ingestion
- Web UI for listening and managing the server
- Metadata extraction, including embedded album art
- Metadata editor for tracks
- REST API for tracks, albums, playlists, and artists
- Streaming support for common audio formats (mp3, flac, wav, ogg, m4a)

## Getting Started

### Download the binary

Binaries can be downloaded from the Releases page of this repo.

### Start the server

```bash
# Example with default options
# Music directory and database created in working directory
# Web server hosted on port 9090
./bin/openstream-linux-amd64
```

```bash
# Example - DB_PATH, MUSIC_LIBRARY_PATH, PORT, and WEB_UI_DIR can be customized
DB_PATH=./openstream.db \
MUSIC_LIBRARY_PATH=./music \
WEB_UI_DIR=./webui \
PORT=9090 \
./bin/openstream-linux-amd64
```

The server serves the Flutter web app from a local `webui/` directory by default.
The Flutter client lives in [`flutter/`](flutter), and the Go binary does not embed the web assets.
Ship the `webui/` directory with the binary, or point `WEB_UI_DIR` at another directory that contains the built Flutter web bundle.

`WEB_UI_DIR` defaults to `./webui` relative to the current working directory when the server starts.

Use `scripts/rebuild-web.sh` to clear and rebuild the Flutter web bundle, then resync `webui/`.
Use `scripts/build.sh native` to package the server binary and refresh `webui/` from `flutter/build/web` when it exists.

## Development

### Clone the repo and build from source

```bash
git clone example.git
cd openstream-lite

scripts/rebuild-web.sh

go mod tidy
go build -o ./bin/openstream-linux-amd64 ./cmd/server
```

Or build the packaged binary with:

```bash
scripts/build.sh native
```

### Environment

- `PORT` (default `9090`)
- `DB_PATH` (default `./openstream.db`)
- `MUSIC_LIBRARY_PATH` (default `./music`)
- `LOGO_FALLBACK_PATH` (default empty)
- `WEB_UI_DIR` (default `./webui`)
- `SCAN_INTERVAL` (default `5m`)
- `MAX_UPLOAD_MB` (default `1024`)

### Implemented endpoints

- `GET /health`
- `GET /api/tracks`
- `GET /api/tracks/{id}/stream`
- `POST /api/tracks/upload`
- `PUT /api/tracks/{id}`
- `DELETE /api/tracks/{id}`
- `GET /api/albumart/{fileName}`
- `POST /api/albums/{id}/art`
- `GET /api/playlists`
- `GET /api/playlists/{id}`
- `POST /api/playlists`
- `POST /api/ingestion/scan`
