# go-openstream backend

Lightweight Go rewrite of the Openstream backend using SQLite

## Run

```bash
cd go-openstream
./scripts/build.sh
DB_PATH=./data/openstream.db MUSIC_LIBRARY_PATH=../music PORT=9090 ./bin/openstream
```

## Environment

- `PORT` (default `9090`)
- `DB_PATH` (default `./openstream.db`)
- `MUSIC_LIBRARY_PATH` (default `./music`)
- `STATIC_DIR` (default `../web/build`)
- `LOGO_FALLBACK_PATH` (default `../web/src/logo.svg`)
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
