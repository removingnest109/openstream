# openstream-lite

![WebUI](screenshots/openstream.png)

Openstream-lite is a lightweight, portable Go rewrite of the self-hosted music library and streaming server Openstream. It scans a user defined music directory, ingests metadata into a SQLite database, and provides a REST API and Web UI for browsing and streaming your music collection.

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
./openstream
```

```bash
# Example - DB_PATH, MUSIC_LIBRARY_PATH, and PORT can be customized
DB_PATH=./openstream.db MUSIC_LIBRARY_PATH=./music PORT=9090 ./bin/openstream
```

The binary serves the React app directly from embedded assets by default (no launch script or separate static file process needed).

## Development

### Clone the repo and build from source

```bash
git clone example.git
cd openstream-lite

git submodule update --init --recursive

go mod tidy
go build -o ./bin/openstream ./cmd/server
```

### When changing the web UI

After any React UI change, rebuild the frontend and then rebuild the Go binary so updated assets are embedded:

```bash
cd .web
npm run build

cd ../../..
go build -o ./bin/openstream ./cmd/server
```

Then restart `./bin/openstream`.

### Environment

- `PORT` (default `9090`)
- `DB_PATH` (default `./openstream.db`)
- `MUSIC_LIBRARY_PATH` (default `./music`)
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
