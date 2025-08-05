using Openstream.Core.Models;

namespace Openstream.Server.Services;

public class MusicScanner
{
    private readonly string _musicLibraryPath;
    public MusicScanner(string musicLibraryPath)
    {
        _musicLibraryPath = musicLibraryPath;
    }

    public virtual Track? ProcessFile(string filePath, int? albumId = null)
    {
        if (!System.IO.File.Exists(filePath))
        {
            Console.WriteLine($"File not found: {filePath}");
            return null;
        }

        try
        {
            using var file = TagLib.File.Create(filePath);

            var album = new Album
            {
                Title = file.Tag.Album ?? "Unknown Album",
                Year = (int?)file.Tag.Year,
                Artist = new Artist
                {
                    Name = file.Tag.FirstPerformer ?? "Unknown Artist"
                }
            };

            ExtractAndAssignAlbumArt(file, album, albumId);

            return new Track
            {
                Title = file.Tag.Title ?? Path.GetFileNameWithoutExtension(filePath),
                Path = filePath,
                Duration = file.Properties.Duration,
                TrackNumber = (int)file.Tag.Track,
                Album = album
            };
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error processing file '{filePath}': {ex.Message}");
            return null;
        }
    }

    private void ExtractAndAssignAlbumArt(TagLib.File file, Album album, int? albumId)
    {
        var pictures = file.Tag.Pictures;
        if (pictures == null || pictures.Length == 0)
        {
            Console.WriteLine($"No album art found for album: {album.Title ?? "Unknown Album"} by {(album.Artist?.Name ?? "Unknown Artist")}");
            return;
        }

        // Debug: List all pictures and their descriptions
        Console.WriteLine($"Found {pictures.Length} picture(s) for album: {album.Title ?? "Unknown Album"} by {(album.Artist?.Name ?? "Unknown Artist")}");
        for (int i = 0; i < pictures.Length; i++)
        {
            var p = pictures[i];
            Console.WriteLine($"  Picture[{i}]: Description='{p.Description}', MimeType='{p.MimeType}', DataLength={p.Data?.Data?.Length ?? 0}");
        }

        // Prefer picture with Description == "Cover"
        var pic = pictures.FirstOrDefault(p =>
            string.Equals(p.Description, "Cover", StringComparison.OrdinalIgnoreCase))
            ?? pictures[0];

        if (pic.Data?.Data == null || pic.Data.Data.Length == 0)
        {
            Console.WriteLine($"Album art data is empty for album: {album.Title ?? "Unknown Album"} by {(album.Artist?.Name ?? "Unknown Artist")}");
            return;
        }

        // Store album art in albumart/ under the configured music library path
        var albumArtDir = Path.Combine(_musicLibraryPath, "albumart");
        Console.WriteLine($"[AlbumArt] albumArtDir: {albumArtDir}");
        try
        {
            if (!Directory.Exists(albumArtDir))
            {
                Directory.CreateDirectory(albumArtDir);
                Console.WriteLine($"[AlbumArt] Created albumArtDir: {albumArtDir}");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[AlbumArt] Failed to create albumArtDir: {albumArtDir} - {ex.Message}");
            return;
        }

        string artFileName = albumId.HasValue
            ? $"{albumId.Value}.jpg"
            : $"{Math.Abs(((album.Title ?? "Unknown Album") + (album.Artist?.Name ?? "Unknown Artist")).GetHashCode())}.jpg";

        var artPath = Path.Combine(albumArtDir, artFileName);
        Console.WriteLine($"[AlbumArt] artPath: {artPath}");
        // Only write if file doesn't exist
        if (!File.Exists(artPath))
        {
            try
            {
                File.WriteAllBytes(artPath, pic.Data.Data);
                Console.WriteLine($"[AlbumArt] Wrote album art to: {artPath}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[AlbumArt] Failed to write album art to: {artPath} - {ex.Message}");
            }
        }
        else
        {
            Console.WriteLine($"[AlbumArt] File already exists, not overwriting: {artPath}");
        }

        // Store only the filename for API compatibility (avoid double 'albumart/' in path)
        album.AlbumArtPath = artFileName;
    }
}
