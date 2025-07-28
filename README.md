# Openstream

![Build Status](https://github.com/removingnest109/openstream/actions/workflows/docker-image.yml/badge.svg)
![Docker Pulls](https://img.shields.io/docker/pulls/removingnest109/openstream)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

Openstream is a self-hosted music library and streaming server. It scans a user defined music directory, ingests metadata into a SQL database, and provides a REST API and Web UI for browsing and streaming your music collection.

## Features

- Automatic music library scanning and ingestion
- REST API for tracks, albums, and artists
- Streaming support for common audio formats (mp3, flac, wav, ogg, m4a)
- Web UI for managing and accessing the server - included with server
- Mobile app for iOS and Android (WIP) - [openstream_player](https://github.com/removingnest109/openstream_player)
- Automatic downloader for Youtube and Spotify links - uses yt-dlp and spotdl

## Planned Features

- Album art support
- qBittorrent integration

## Requirements

- Docker Compose (Includes all dependencies by default)

OR

- .NET 8 SDK - REQUIRED
- SQL Server (local or Docker) - REQUIRED
- Bash (for scripts) - REQUIRED
- yt-dlp (for youtube downloads) - OPTIONAL
- spotdl (for spotify downloads) - OPTIONAL
  - Python (required only if using spotdl)

git clone <https://github.com/removingnest109/openstream.git>
cd openstream
yt-dlp and spotdl are optional, but are required in order for the automatic link downloader to work for the respective links.
sudo apt install yt-dlp

pip3 install spotdl
./start-server.sh
docker-compose up

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/removingnest109/openstream.git
cd openstream
```

### 2. Prepare Your Music Library

Place your music files in a directory (default: `./music`). Supported formats: mp3, flac, wav, ogg, m4a.

Music files can also be uploaded to the running server.

### 3. Run the Server

#### Using .NET (Recommended for Development)

yt-dlp and spotdl are optional, but are required in order for the automatic link downloader to work for the respective links.

```bash
sudo apt install yt-dlp
pip3 install spotdl
```

Edit `start-server.sh` or use environment variables to set your SQL Server connection string if needed.

```bash
./start-server.sh
```

Options:

- `-p` SQL password (default: YourStrong!Passw0rd)
- `-u` SQL username (default: sa)
- `-s` SQL server address (default: localhost)
- `-m` Music library path (default: ./music)

#### Using Docker

Edit `docker-compose.yml` to set your SQL Server connection string if needed.

```bash
docker-compose up
```

This will start both the SQL Server and the Openstream server.

#### Using Prebuilt Docker Image

You can also pull and run the latest image from Docker Hub:

```bash
docker pull removingnest109/openstream:latest
docker run -p 9090:9090 -v $(pwd)/music:/music removingnest109/openstream:latest
```

## Environment Variables

You can configure Openstream using the following environment variables:

| Variable                | Description                        | Default                        |
|-------------------------|------------------------------------|---------------------------------|
| `ConnectionStrings__DefaultConnection` | SQL Server connection string         | See `appsettings.json`          |
| `Ingestion__MusicLibraryPath`          | Path to music library                | `/music`                       |
| `ASPNETCORE_ENVIRONMENT`               | ASP.NET Core environment             | `Production`                   |

You can also use command-line arguments as described above.

## API Endpoints

- `GET /api/tracks` — List all tracks (supports search)
- `GET /api/tracks/{id}/stream` — Stream a track by ID
- `GET /api/playlists` — List all playlists
- `GET /api/playlists/id` — List songs in a selected playlist
- `GET /health` — Health check
- `POST /api/tracks/upload` — Upload a track from a local file
- `POST /api/download` — Download a track from Youtube or Spotify
- `POST /api/ingestion/scan` — Scan for new tracks
- `POST /api/playlists` — Create a new playlist

## Customization

You can change the music library path and database connection via command-line arguments or environment variables.

To run Openstream without serving the frontend use:

```bash
./start-server.sh --no-frontend
```

## License

MIT
