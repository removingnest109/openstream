# openstream

Openstream is a lightweight, portable self-hosted music library and streaming server. It scans a user defined music directory, ingests metadata into a SQLite database, and provides a REST API and Web UI for browsing and streaming your music collection.

## Features

- Automatic music library scanning and ingestion
- Web UI for listening and managing the server
- Metadata extraction, including embedded album art
- Metadata editor for tracks
- REST API for tracks, albums, playlists, and artists
- Streaming support for common audio formats (mp3, flac, wav, ogg, m4a)

## Getting Started

### Server

#### Download a release

Release archives can be downloaded from the Releases page of this repo.
Each archive contains an `openstream/` folder with:

- the target binary
- `webui/`
- `install.sh`
- `openstream.service`

Extract the archive and enter the extracted folder.

#### Optional - Customize paths and port
`openstream.service` can be edited before running `install.sh` in order to change the installation paths if needed

#### Install
```bash
sudo ./install.sh
```

`install.sh` reads the paths directly from `openstream.service`, copies the binary to the unit's `ExecStart` path, copies the web bundle to the unit's `WEB_UI_DIR`, installs the service into `/etc/systemd/system/`, reloads systemd, and enables the service. The included systemd unit uses these variables:

- ExecStart: `/bin/openstream`
- WEB_UI_DIR: `/opt/openstream/webui`
- MUSIC_LIBRARY_PATH: `/media/music`
- DB_PATH: `/media/music/openstream.db`
- PORT: `80`

After running the install script, the service will be running and openstream should be available.

## Client

Download the Linux client release zip from the Releases page, extract it, and run:

```bash
sudo ./install-client.sh
```

That installer copies the bundle into `/opt/openstream-client`, installs a launcher at `/usr/local/bin/openstream-client`, and registers the desktop entry in `/usr/share/applications`.

The release zip includes `install-client.sh` at its root next to the `openstream/` bundle.

## Development

### Clone the repo and build from source

```bash
git clone https://github.com/removingnest109/openstream.git
cd openstream
scripts/rebuild-web.sh
scripts/build.sh native
```

### Run the server manually

To run the server directly without the systemd service:

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
The Flutter client lives in [`flutter/`](flutter).
Ship the `webui/` directory with the binary, or point `WEB_UI_DIR` at another directory that contains the built Flutter web bundle.
`WEB_UI_DIR` defaults to `./webui` relative to the current working directory when the server starts.

Use `scripts/rebuild-web.sh` to clear and rebuild the Flutter web bundle and copy to `webui/`.
Use `scripts/build.sh native` to build the server binary for the current platform.
Use `scripts/package-release.sh all` to build server release zip archives for all targets that include the binary, `webui/`, `install.sh`, and `openstream.service`.

### Packaging for release

#### Server

Build and refresh the web assets:

```bash
scripts/rebuild-web.sh
```

Build the server binaries for all targets:
```bash
scripts/build.sh all
```

Or for a single target:

```bash
scripts/build.sh linux-arm64
```

Create release archives for all targets:

```bash
scripts/package-release.sh all
```

Or for a single target:

```bash
scripts/package-release.sh linux-arm64
```

#### Client
Build client package:

```bash
scripts/build-client-release.sh
```


### Environment variables

- `PORT` (default `9090`)
- `DB_PATH` (default `./openstream.db`)
- `MUSIC_LIBRARY_PATH` (default `./music`)
- `LOGO_FALLBACK_PATH` (default empty)
- `WEB_UI_DIR` (default `./webui`)
- `SCAN_INTERVAL` (default `5m`)
- `MAX_UPLOAD_MB` (default `1024`)

### API endpoints

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
