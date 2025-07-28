#!/bin/bash
set -e

# Default values (same as start-server.sh)
PASSWORD="YourStrong!Passw0rd"
USERNAME="sa"
SERVER="172.17.0.1"  # Default Docker bridge IP
MUSIC_LIBRARY_PATH="$(pwd)/music"
NO_FRONTEND=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -p)
      PASSWORD="$2"; shift 2;;
    -u)
      USERNAME="$2"; shift 2;;
    -s)
      SERVER="$2"; shift 2;;
    -m)
      MUSIC_LIBRARY_PATH="$2"; shift 2;;
    --no-frontend)
      NO_FRONTEND=true; shift;;
    *)
      echo "Usage: $0 [-p password] [-u username] [-s server] [-m music_library_path] [--no-frontend]" >&2
      exit 1;;
  esac
done

# Start the application with parsed arguments
echo "Starting application..."
DOTNET_ARGS=(
  --ConnectionStrings:DefaultConnection="Server=$SERVER;Database=Openstream;User Id=$USERNAME;Password=$PASSWORD;TrustServerCertificate=True;"
  --Ingestion:MusicLibraryPath="$MUSIC_LIBRARY_PATH"
)
exec dotnet Openstream.Server.dll "${DOTNET_ARGS[@]}"
