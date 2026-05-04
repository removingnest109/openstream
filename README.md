# go-openstream backend

Lightweight Go rewrite of the Openstream backend using SQLite

## Run

```bash
go mod tidy
go build -o ./bin/openstream ./cmd/server
DB_PATH=./openstream.db MUSIC_LIBRARY_PATH=./music PORT=9090 ./bin/openstream
```

The binary serves the React app directly from embedded assets by default (no launch script or separate static file process needed).

## When changing the web UI

After any React UI change, rebuild the frontend and then rebuild the Go binary so updated assets are embedded:

```bash
cd .web
npm run build

cd ../../..
go build -o ./bin/openstream ./cmd/server
```

Then restart `./bin/openstream`.

## Environment

- `PORT` (default `9090`)
- `DB_PATH` (default `./openstream.db`)
- `MUSIC_LIBRARY_PATH` (default `./music`)
- `STATIC_DIR` (optional override; when set, server reads static files from disk first)
- `LOGO_FALLBACK_PATH` (optional fallback image path for missing album art)
- `SCAN_INTERVAL` (default `5m`)
- `MAX_UPLOAD_MB` (default `1024`)

## Implemented endpoints

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
