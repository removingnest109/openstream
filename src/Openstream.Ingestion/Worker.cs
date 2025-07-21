using Openstream.Core.Data;
using Openstream.Ingestion.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Openstream.Core.Models;

namespace Openstream.Ingestion;

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
        var supported = new[] { ".mp3", ".flac", ".m4a", ".wav", ".ogg" };
        var files = Directory.EnumerateFiles(path, "*.*", SearchOption.AllDirectories)
            .Where(f => supported.Contains(Path.GetExtension(f).ToLower()));

        var newTracks = new List<Track>();

        foreach (var file in files)
        {
            if (cancellationToken.IsCancellationRequested) break;

            if (await db.Tracks.AnyAsync(t => t.Path == file, cancellationToken)) continue;

            var trackData = scanner.ProcessFile(file);
            if (trackData == null) continue;

            var artistName = trackData.Album.Artist.Name;
            var artist = await db.Artists.FirstOrDefaultAsync(a => a.Name == artistName, cancellationToken)
                         ?? new Artist { Name = artistName };

            var albumTitle = trackData.Album.Title;
            var album = await db.Albums.FirstOrDefaultAsync(a => a.Title == albumTitle && a.Artist.Name == artistName, cancellationToken)
                        ?? new Album { Title = albumTitle, Artist = artist, Year = trackData.Album.Year };

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