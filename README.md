# Openstream

[![Build Status](https://github.com/removingnest109/openstream/actions/workflows/docker-image.yml/badge.svg)](https://hub.docker.com/r/removingnest109/openstream)
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
- REST API for tracks, albums, and artists
- Streaming support for common audio formats (mp3, flac, wav, ogg, m4a)
- Web UI for managing and accessing the server - included with server
- Mobile app for iOS and Android (WIP) - [openstream_player](https://github.com/removingnest109/openstream_player)
- Album art support

## Planned Features

- qBittorrent integration

## Requirements

- .NET 8 SDK - REQUIRED
- SQL Server (local or Docker) - REQUIRED
- Bash (for scripts) - REQUIRED

OR

- Docker
- SQL Server (local or Docker)

OR

- Docker Compose (Includes all dependencies by default)

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

Edit `start-server.sh` or use environment variables to set your SQL Server connection string if needed.

```bash
./start-server.sh
```

Options:

- `-p` SQL password (default: YourStrong!Passw0rd)
- `-u` SQL username (default: sa)
- `-s` SQL server address (default: localhost)
- `-m` Music library path (default: ./music)

To run with .NET, you will need a separate instance of mssql-server running and accessible on the host machine port 1433.

#### Using Docker Compose (Easiest)

Edit `docker-compose.yml` to set your SQL Server connection string if needed.

```bash
docker-compose up -d --pull
```

This will start both the SQL Server and the Openstream server.

-d runs the containers in detached mode, and --pull ensures the latest image is always pulled.

The Docker Compose file will automatically setup mssql-server with the user "sa" and the password in the docker-compose.yml.

#### Using Prebuilt Docker Image

You can also pull and run the latest image from Docker Hub:

```bash
docker pull removingnest109/openstream:latest
docker run -p 9090:9090 -v $(pwd)/music:/music removingnest109/openstream:latest
```

With the prebuilt Docker Image, you will need a separate instance of mssql-server running and accessible on the host machine port 1433.

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
