# Openstream

[![Docker Image](https://github.com/removingnest109/openstream/actions/workflows/docker-image.yml/badge.svg)](https://hub.docker.com/r/removingnest109/openstream)
![Backend Tests](https://github.com/removingnest109/openstream/actions/workflows/backend-tests.yml/badge.svg)
![Frontend Tests](https://github.com/removingnest109/openstream/actions/workflows/frontend-tests.yml/badge.svg)
[![Docker Pulls](https://img.shields.io/docker/pulls/removingnest109/openstream)](https://hub.docker.com/r/removingnest109/openstream)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![C#](https://custom-icon-badges.demolab.com/badge/C%23-%23239120.svg?logo=cshrp&logoColor=white)
![.NET](https://img.shields.io/badge/.NET-512BD4?logo=dotnet&logoColor=fff)
![React](https://img.shields.io/badge/React-%2320232a.svg?logo=react&logoColor=%2361DAFB)
![Microsoft SQL Server](https://custom-icon-badges.demolab.com/badge/Microsoft%20SQL%20Server-CC2927?logo=mssqlserver-white&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=fff)

Openstream is a self-hosted music library and streaming server. It scans a user defined music directory, ingests metadata into a SQL database, and provides a REST API and Web UI for browsing and streaming your music collection.

## Features

- Automatic music library scanning and ingestion
- Web UI for managing and accessing the server
- Metadata extraction, including embedded album art
- Metadata editor for tracks
- REST API for tracks, albums, playlists, and artists
- Streaming support for common audio formats (mp3, flac, wav, ogg, m4a)
- Mobile app for iOS and Android (WIP) - [openstream_player](https://github.com/removingnest109/openstream_player)

## Requirements

- Docker Compose (Includes all dependencies by default)

OR

- Docker
- SQL Server (local or Docker)

OR

- .NET 8 SDK
- NPM
- SQL Server (local or Docker)
- Bash (for scripts)

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

#### Using Docker Compose

Edit `docker-compose.yml` to set your SQL Server connection string if needed.

```bash
docker-compose up -d
```

This will start both the SQL Server and the Openstream server.

-d runs the containers in detached mode.

The Docker Compose file will automatically setup mssql-server with the user "sa" and the password in the docker-compose.yml.

#### Using Prebuilt Docker Image

You can also pull and run the latest image from Docker Hub:

```bash
docker pull removingnest109/openstream:latest
docker run -p 9090:9090 -v $(pwd)/music:/music removingnest109/openstream:latest
```

With the prebuilt Docker Image, you will need a separate instance of mssql-server running and accessible on the host machine port 1433.

#### Using .NET

Edit `start-server.sh` or use environment variables to set your SQL Server connection string if needed.

```bash
./start-server.sh
```

Options:

- `-p` SQL password (default: YourStrong!Passw0rd)
- `-u` SQL username (default: sa)
- `-s` SQL server address (default: localhost)
- `-m` Music library path (default: ./music)
- `--nobuild` Disable build steps and use existing dll and wwwroot

To run with .NET, you will need a separate instance of mssql-server running and accessible on the host machine port 1433.

## Environment Variables

You can configure Openstream using the following environment variables:

| Variable                | Description                        | Default                        |
|-------------------------|------------------------------------|---------------------------------|
| `ConnectionStrings__DefaultConnection` | SQL Server connection string         | See `appsettings.json`          |
| `Ingestion__MusicLibraryPath`          | Path to music library                | `/music`                       |
| `ASPNETCORE_ENVIRONMENT`               | ASP.NET Core environment             | `Production`                   |

You can also use command-line arguments as described above.

## API Endpoints

### Tracks

- `GET /api/tracks` — List all tracks (optionally filter by `?search=`)
- `GET /api/tracks/{id}/stream` — Stream a track by ID
- `POST /api/tracks/upload` — Upload a new track (multipart/form-data)
- `PUT /api/tracks/{id}` — Edit track metadata (title, album, artist)
- `GET /api/albumart/{fileName}` — Get album art image by filename

### Albums

- `POST /api/albums/{id}/art` — Upload album art for an album (multipart/form-data)

### Playlists

- `GET /api/playlists` — List all playlists (with tracks and album art info)
- `GET /api/playlists/{id}` — Get a playlist by ID (with tracks and album art info)
- `POST /api/playlists` — Create a new playlist (JSON body: name, trackIds)

### Ingestion

- `POST /api/ingestion/scan` — Scan the music library for new/removed tracks

## Customization

You can change the music library path and database connection via command-line arguments or environment variables.

## License

MIT
