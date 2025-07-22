
# Openstream

Openstream is a .NET-based music library ingestion and streaming server. It scans your music directory, ingests metadata into a SQL database, and provides a REST API for browsing and streaming your music collection.

## Features
- Automatic music library scanning and ingestion
- REST API for tracks, albums, and artists
- Streaming support for common audio formats (mp3, flac, wav, ogg, m4a)
- Runs as a background service

## Requirements
- .NET 8 SDK or newer
- SQL Server (local or Docker)
- Bash (for running scripts)

## Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/openstream.git
cd openstream
```

### 2. Prepare Your Music Library
Place your music files in a directory (default: `./music`). Supported formats: mp3, flac, wav, ogg, m4a.

### 3. Configure the Database
Edit `src/Openstream.Server/appsettings.json` or use environment variables to set your SQL Server connection string if needed.

### 4. Run the Server

#### Using .NET (Recommended for Development)
```bash
./start-server.sh
```
Options:
- `-p` SQL password (default: YourStrong!Passw0rd)
- `-u` SQL username (default: sa)
- `-s` SQL server address (default: localhost)
- `-m` Music library path (default: ./music)

#### Using Docker
```bash
docker-compose up
```
This will start both the SQL Server and the Openstream server.

## API Endpoints
- `GET /api/tracks` — List all tracks (supports search)
- `GET /api/tracks/{id}/stream` — Stream a track by ID
- `GET /health` — Health check

## Customization
You can change the music library path and database connection via command-line arguments or environment variables.

## License
MIT
