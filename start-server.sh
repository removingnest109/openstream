#!/bin/bash
set -e


# Default values
PASSWORD="YourStrong!Passw0rd"
USERNAME="sa"
SERVER="localhost"
MUSIC_LIBRARY_PATH="$HOME/Music"


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

dotnet run --project src/Openstream.Server/Openstream.Server.csproj \
  --ConnectionStrings:DefaultConnection="Server=$SERVER;Database=Openstream;User Id=$USERNAME;Password=$PASSWORD;TrustServerCertificate=True;" \
  --Ingestion:MusicLibraryPath="$MUSIC_LIBRARY_PATH"
