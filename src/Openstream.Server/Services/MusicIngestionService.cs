using Openstream.Core.Data;
using Microsoft.EntityFrameworkCore;
using Openstream.Core.Models;

namespace Openstream.Server.Services;

public class MusicIngestionService
{
    private readonly ILogger<MusicIngestionService> _logger;

    public MusicIngestionService(ILogger<MusicIngestionService> logger)
    {
        _logger = logger;
    }

    public async Task ScanDirectoryAsync(string path, MusicDbContext db, MusicScanner scanner, CancellationToken cancellationToken = default)
    {
        var allTracks = await db.Tracks.ToListAsync(cancellationToken);
        var tracksToRemove = allTracks.Where(t => !System.IO.File.Exists(t.Path)).ToList();

        if (tracksToRemove.Count > 0)
        {
            _logger.LogInformation("Removing {Count} tracks with missing files...", tracksToRemove.Count);
            db.Tracks.RemoveRange(tracksToRemove);
            await db.SaveChangesAsync(cancellationToken);
        }

        var supported = new[] { ".mp3", ".flac", ".m4a", ".wav", ".ogg" };
        var files = Directory.EnumerateFiles(path, "*.*", SearchOption.AllDirectories)
            .Where(f => supported.Contains(Path.GetExtension(f).ToLower()));

        var existingTrackPaths = new HashSet<string>(allTracks.Select(t => t.Path), StringComparer.OrdinalIgnoreCase);
        var existingArtists = await db.Artists.ToListAsync(cancellationToken);
        var artistCache = existingArtists.ToDictionary(a => a.Name ?? "Unknown Artist", StringComparer.OrdinalIgnoreCase);

        var existingAlbums = await db.Albums.Include(a => a.Artist).ToListAsync(cancellationToken);
#pragma warning disable CS8602 // Dereference of a possibly null reference.
        var albumCache = existingAlbums
            .Where(a => a.Artist != null)
            .ToDictionary(a => $"{a.Title ?? "Unknown Album"}|{a.Artist.Name ?? "Unknown Artist"}", StringComparer.OrdinalIgnoreCase);
#pragma warning restore CS8602 // Dereference of a possibly null reference.

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

            // Always update AlbumArtPath if we have new art and it's not set or has changed
            if (!string.IsNullOrEmpty(trackData.Album.AlbumArtPath) &&
                (string.IsNullOrEmpty(album.AlbumArtPath) || album.AlbumArtPath != trackData.Album.AlbumArtPath))
            {
                album.AlbumArtPath = trackData.Album.AlbumArtPath;
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
            _logger.LogInformation("Found {Count} new tracks. Saving to database...", newTracks.Count);
            foreach (var artist in artistCache.Values.Where(a => a.Id == 0))
                db.Artists.Add(artist);

            foreach (var album in albumCache.Values.Where(a => a.Id == 0))
                db.Albums.Add(album);

            db.Tracks.AddRange(newTracks);
            await db.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Successfully saved {Count} new tracks.", newTracks.Count);
        }
        else
        {
            _logger.LogInformation("No new tracks found.");
        }
    }
}
