using Openstream.Core.Data;
using Openstream.Server.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Openstream.Core.Models;

namespace Openstream.Server;

public class Worker(
    ILogger<Worker> logger,
    IOptions<IngestionConfig> config,
    IServiceScopeFactory scopeFactory,
    MusicScanner scanner) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("Starting music ingestion service");
        
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<MusicDbContext>();
                
                await ScanDirectory(config.Value.MusicLibraryPath, db, scanner, stoppingToken);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Ingestion failed");
            }
            
            await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
        }
    }

    private async Task ScanDirectory(string path, MusicDbContext db, MusicScanner scanner, CancellationToken cancellationToken)
    {
        var allTracks = await db.Tracks.ToListAsync(cancellationToken);
        var tracksToRemove = allTracks.Where(t => !System.IO.File.Exists(t.Path)).ToList();

        if (tracksToRemove.Count > 0)
        {
            logger.LogInformation("Removing {Count} tracks with missing files...", tracksToRemove.Count);
            db.Tracks.RemoveRange(tracksToRemove);
            await db.SaveChangesAsync(cancellationToken);
        }

        var supported = new[] { ".mp3", ".flac", ".m4a", ".wav", ".ogg" };
        var files = Directory.EnumerateFiles(path, "*.*", SearchOption.AllDirectories)
            .Where(f => supported.Contains(Path.GetExtension(f).ToLower()));

        var existingTrackPaths = new HashSet<string>(allTracks.Select(t => t.Path), StringComparer.OrdinalIgnoreCase);
        var existingArtists = await db.Artists.ToListAsync(cancellationToken);
        var artistCache = new Dictionary<string, Artist>(StringComparer.OrdinalIgnoreCase);
        foreach (var artist in existingArtists)
        {
            artistCache[artist.Name ?? "Unknown Artist"] = artist;
        }

        var existingAlbums = await db.Albums.Include(a => a.Artist).ToListAsync(cancellationToken);
        var albumCache = new Dictionary<string, Album>(StringComparer.OrdinalIgnoreCase);
        foreach (var album in existingAlbums.Where(a => a.Artist != null))
        {
            var artistName = album.Artist?.Name ?? "Unknown Artist";
            var albumTitle = album.Title ?? "Unknown Album";
            var key = $"{albumTitle}|{artistName}";
            albumCache[key] = album;
        }

        var newTracks = new List<Track>();

        foreach (var file in files)
        {
            if (cancellationToken.IsCancellationRequested) break;

            if (existingTrackPaths.Contains(file)) continue;

            var trackData = scanner.ProcessFile(file);
            if (trackData == null || trackData.Album?.Artist == null) continue;

            var artistName = trackData.Album.Artist.Name ?? "Unknown Artist";
            if (!artistCache.TryGetValue(artistName, out var artist))
            {
                artist = new Artist { Name = artistName };
                artistCache[artistName] = artist;
            }

            var albumTitle = trackData.Album.Title ?? "Unknown Album";
            var albumKey = $"{albumTitle}|{artistName}";
            if (!albumCache.TryGetValue(albumKey, out var album))
            {
                album = new Album
                {
                    Title = albumTitle,
                    Artist = artist,
                    Year = trackData.Album.Year
                };
                albumCache[albumKey] = album;
            }

            var track = new Track
            {
                Title = trackData.Title,
                Path = trackData.Path,
                Duration = trackData.Duration,
                TrackNumber = trackData.TrackNumber,
                Album = album
            };

            newTracks.Add(track);
        }

        if (newTracks.Count > 0)
        {
            logger.LogInformation("Found {Count} new tracks. Saving to database...", newTracks.Count);
            foreach (var artist in artistCache.Values)
            {
                if (artist.Id == 0)
                    db.Artists.Add(artist);
            }
            foreach (var album in albumCache.Values)
            {
                if (album.Id == 0)
                    db.Albums.Add(album);
            }
            db.Tracks.AddRange(newTracks);
            await db.SaveChangesAsync(cancellationToken);
            logger.LogInformation("Successfully saved {Count} new tracks.", newTracks.Count);
        }
        else
        {
            logger.LogInformation("No new tracks found.");
        }
    }
}

public class IngestionConfig
{
    public string MusicLibraryPath { get; set; } = "/music";
}
