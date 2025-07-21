#!/bin/bash
set -e

# Function to wait for SQL Server
wait_for_sql() {
    echo "Waiting for SQL Server at $1:$2..."
    until nc -z $1 $2; do
        echo "SQL Server unavailable, retrying in 5 seconds..."
        sleep 5
    done
    echo "SQL Server is ready!"
}

# Wait for SQL Server
wait_for_sql sql-server 1433

# Start the application
echo "Starting application..."
if [ "$1" == "server" ]; then
    exec dotnet Openstream.Server.dll
elif [ "$1" == "ingestion" ]; then
    exec dotnet Openstream.Ingestion.dll
else
    echo "Invalid argument. Please use 'server' or 'ingestion'."
    exit 1
fi
