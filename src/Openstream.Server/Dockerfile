# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Install Node.js (LTS version)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    node --version && npm --version

# Copy solution and project files
COPY ["Openstream.sln", "."]
COPY ["src/Openstream.Core/*.csproj", "src/Openstream.Core/"]
COPY ["src/Openstream.Server/*.csproj", "src/Openstream.Server/"]

# Restore dependencies
RUN dotnet restore "Openstream.sln"

# Copy all source files
COPY . .

# Build React frontend and copy to wwwroot/dist
WORKDIR /src/web
RUN npm install && npm run build
WORKDIR /src
RUN rm -rf src/Openstream.Server/wwwroot/dist && \
    mkdir -p src/Openstream.Server/wwwroot/dist && \
    cp -r web/build/* src/Openstream.Server/wwwroot/dist/

# Build and publish the API
WORKDIR "/src/src/Openstream.Server"
RUN dotnet publish -c Release -o /app/publish \
    -p:AssemblyVersion=$(date +%Y.%m.%d.%H%M)

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Install dependencies
RUN apt-get update && \
    apt-get install -y libtag1-dev curl gnupg ffmpeg yt-dlp && \
    # Download and install Microsoft GPG key
    curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg && \
    # Add repository with proper signed-by
    echo "deb [signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql18 netcat-traditional && \
    # Cleanup
    apt-get purge -y --auto-remove curl gnupg && \
    rm -rf /var/lib/apt/lists/*


# Copy wait script
COPY wait-for-sql.sh /app/

# Create music directory and set permissions
RUN mkdir -p /app/music && chmod 777 /app/music

# Copy published files
COPY --from=build /app/publish .


# Set non-root user with configurable UID/GID for volume compatibility
ARG APP_UID=1000
ARG APP_GID=1000
RUN groupadd -g $APP_GID appuser && \
    useradd -u $APP_UID -g $APP_GID --create-home --shell /bin/bash appuser && \
    chown -R appuser:appuser /app
USER appuser

# Set entrypoint to use wait script
ENTRYPOINT ["./wait-for-sql.sh"]
