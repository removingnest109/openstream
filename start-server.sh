#!/bin/bash
set -e

# Default values
PASSWORD="YourStrong!Passw0rd"
USERNAME="sa"
SERVER="localhost"
MUSIC_LIBRARY_PATH="$(pwd)/music"
NOBUILD=false
DOCKER=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -p)
      PASSWORD="$2"; shift 2;;
    -u)
      USERNAME="$2"; shift 2;;
    -s)
      SERVER_OVERRIDE=true; SERVER="$2"; shift 2;;
    -m)
      MUSIC_LIBRARY_PATH="$2"; shift 2;;
    --nobuild)
      NOBUILD=true; shift;;
    --docker)
      DOCKER=true; NOBUILD=true; SERVER="172.17.0.1"; shift;;
    *)
      echo "Usage: $0 [-p password] [-u username] [-s server] [-m music_library_path] [--nobuild] [--docker]"
      exit 1;;
  esac
done

# If both --docker and -s are provided, -s should take precedence
if [ "$DOCKER" = true ] && [ "$SERVER_OVERRIDE" = true ]; then
  echo "[INFO] Docker mode: using custom server IP $SERVER (overrides default 172.17.0.1)"
fi

if [ "$NOBUILD" != true ]; then
  # Build React frontend and copy to server wwwroot/dist
  echo "[INFO] Building React frontend..."
  cd web
  npm install
  npm run build
  cd ..

  rm -rf src/Openstream.Server/wwwroot/dist
  mkdir -p src/Openstream.Server/wwwroot/dist
  cp -r web/build/* src/Openstream.Server/wwwroot/dist/

  # Publish the server
  dotnet publish src/Openstream.Server/Openstream.Server.csproj -c Release

  # After publish, copy frontend build to top-level wwwroot
  echo "[INFO] Copying published frontend to top-level wwwroot..."
  if [ ! -d "wwwroot/" ]; then
    mkdir wwwroot/
  fi
  cp -r src/Openstream.Server/wwwroot/* wwwroot/
else
  echo "[INFO] --nobuild specified: Skipping frontend build, dotnet publish, and wwwroot copy. Using existing DLL and wwwroot."
fi

# Find the output DLL
if [ "$DOCKER" = true ]; then
  PUBLISH_DIR="/app"
else
  PUBLISH_DIR="src/Openstream.Server/bin/Release/net8.0/publish"
fi

# Run the published server
dotnet "$PUBLISH_DIR/Openstream.Server.dll" \
  --ConnectionStrings:DefaultConnection="Server=$SERVER;Database=Openstream;User Id=$USERNAME;Password=$PASSWORD;TrustServerCertificate=True;" \
  --Ingestion:MusicLibraryPath="$MUSIC_LIBRARY_PATH"
