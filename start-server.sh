#!/bin/bash
set -e


# Default values
PASSWORD="YourStrong!Passw0rd"
USERNAME="sa"
SERVER="localhost"
MUSIC_LIBRARY_PATH="$(pwd)/music"


# Parse arguments
while getopts "p:u:s:m:" opt; do
  case $opt in
    p)
      PASSWORD="$OPTARG"
      ;;
    u)
      USERNAME="$OPTARG"
      ;;
    s)
      SERVER="$OPTARG"
      ;;
    m)
      MUSIC_LIBRARY_PATH="$OPTARG"
      ;;
    *)
      echo "Usage: $0 [-p password] [-u username] [-s server] [-m music_library_path]"
      exit 1
      ;;
  esac
done


# Publish the server
dotnet publish src/Openstream.Server/Openstream.Server.csproj -c Release

# Find the output DLL
PUBLISH_DIR="src/Openstream.Server/bin/Release/net8.0/publish"

# Run the published server
dotnet "$PUBLISH_DIR/Openstream.Server.dll" \
  --ConnectionStrings:DefaultConnection="Server=$SERVER;Database=Openstream;User Id=$USERNAME;Password=$PASSWORD;TrustServerCertificate=True;" \
  --Ingestion:MusicLibraryPath="$MUSIC_LIBRARY_PATH"
