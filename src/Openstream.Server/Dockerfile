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

# Build and publish the API
WORKDIR "/src/src/Openstream.Server"
RUN dotnet publish -c Release -o /app/publish \
    -p:AssemblyVersion=$(date +%Y.%m.%d.%H%M)

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Install dependencies
RUN apt-get update && \
    apt-get install -y libtag1-dev curl gnupg && \
    # Download and install Microsoft GPG key
    curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg && \
    # Add repository with proper signed-by
    echo "deb [signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql18 mssql-tools18 && \
    # Add SQLCMD to PATH
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc && \
    # Cleanup
    apt-get purge -y --auto-remove curl gnupg && \
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

# Set entrypoint to use wait script
ENTRYPOINT ["./wait-for-sql.sh"]
