# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy solution and project files
COPY ["Openstream.sln", "."]
COPY ["src/Openstream.Core/*.csproj", "src/Openstream.Core/"]
COPY ["src/Openstream.Server/*.csproj", "src/Openstream.Server/"]
COPY ["src/Openstream.Ingestion/*.csproj", "src/Openstream.Ingestion/"]

# Restore dependencies
RUN dotnet restore "Openstream.sln"

# Copy all source files
COPY . .

# Build and publish the Ingestion service
WORKDIR "/src/src/Openstream.Ingestion"
RUN dotnet publish -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Install dependencies
RUN apt-get update && \
    apt-get install -y libtag1-dev netcat-traditional && \
    rm -rf /var/lib/apt/lists/*

# Copy wait script
COPY wait-for-sql.sh /app/

# Create music directory and set permissions
RUN mkdir -p /music && chmod 777 /music

# Copy published files
COPY --from=build /app/publish .

# Set non-root user
RUN adduser --disabled-password --gecos '' appuser && chown -R appuser /app
USER appuser

ENTRYPOINT ["./wait-for-sql.sh", "ingestion"]
