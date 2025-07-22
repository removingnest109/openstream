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
        // Remove tracks whose files no longer exist
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

        var newTracks = new List<Track>();
        var artistCache = new Dictionary<string, Artist>(StringComparer.OrdinalIgnoreCase);
        var albumCache = new Dictionary<(string Title, string ArtistName), Album>();

        foreach (var file in files)
        {
            if (cancellationToken.IsCancellationRequested) break;

            if (await db.Tracks.AnyAsync(t => t.Path == file, cancellationToken)) continue;

            var trackData = scanner.ProcessFile(file);
            if (trackData == null || trackData.Album == null || trackData.Album.Artist == null) continue;

            var artistName = trackData.Album.Artist.Name ?? "Unknown Artist";
            if (!artistCache.TryGetValue(artistName, out var artist))
            {
                artist = await db.Artists.FirstOrDefaultAsync(a => a.Name == artistName, cancellationToken);
                if (artist == null)
                {
                    artist = new Artist { Name = artistName };
                    artistCache[artistName] = artist;
                }
                else
                {
                    artistCache[artistName] = artist;
                }
            }

            var albumTitle = trackData.Album.Title ?? "Unknown Album";
            var albumKey = (albumTitle, artistName);
            if (!albumCache.TryGetValue(albumKey, out var album))
            {
                album = await db.Albums.Include(a => a.Artist)
                    .FirstOrDefaultAsync(a => a.Title == albumTitle && a.Artist != null && a.Artist.Name == artistName, cancellationToken);
                if (album == null)
                {
                    album = new Album { Title = albumTitle, Artist = artist, Year = trackData.Album.Year };
                    albumCache[albumKey] = album;
                }
                else
                {
                    albumCache[albumKey] = album;
                }
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
                if (artist.Id == 0 && !db.Artists.Local.Any(a => a.Name == artist.Name))
                    db.Artists.Add(artist);
            }
            foreach (var album in albumCache.Values)
            {
                if (album.Id == 0 && !db.Albums.Local.Any(a => a.Title == album.Title && a.Artist != null && a.Artist.Name == album.Artist?.Name))
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
