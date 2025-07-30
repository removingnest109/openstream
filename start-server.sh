#!/bin/bash
set -e



# Default values
PASSWORD="YourStrong!Passw0rd"
USERNAME="sa"
SERVER="localhost"
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
      echo "Usage: $0 [-p password] [-u username] [-s server] [-m music_library_path] [--no-frontend]"
      exit 1;;
  esac
done



# Publish the server
if [ "$NO_FRONTEND" = true ]; then
  dotnet publish src/Openstream.Server/Openstream.Server.csproj -c Release /p:NoFrontend=true
else
  dotnet publish src/Openstream.Server/Openstream.Server.csproj -c Release
fi

# After publish, copy frontend build to top-level wwwroot if needed
if [ "$NO_FRONTEND" != true ]; then
  echo "[INFO] Copying published frontend to top-level wwwroot..."
  if [ ! -d "wwwroot/" ]; then
    mkdir wwwroot/
  fi
  cp -r src/Openstream.Server/wwwroot/* wwwroot/
fi

# Find the output DLL
PUBLISH_DIR="src/Openstream.Server/bin/Release/net8.0/publish"

# Run the published server
dotnet "$PUBLISH_DIR/Openstream.Server.dll" \
  --ConnectionStrings:DefaultConnection="Server=$SERVER;Database=Openstream;User Id=$USERNAME;Password=$PASSWORD;TrustServerCertificate=True;" \
  --Ingestion:MusicLibraryPath="$MUSIC_LIBRARY_PATH"
