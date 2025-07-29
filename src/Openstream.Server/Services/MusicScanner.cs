using Openstream.Core.Models;

namespace Openstream.Server.Services;

public class MusicScanner
{
    public Track? ProcessFile(string filePath, int? albumId = null)
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

        var albumArtDir = Path.Combine(AppContext.BaseDirectory, "albumart");
        if (!Directory.Exists(albumArtDir))
            Directory.CreateDirectory(albumArtDir);

        string artFileName = albumId.HasValue
            ? $"{albumId.Value}.jpg"
            : $"{Math.Abs(((album.Title ?? "Unknown Album") + (album.Artist?.Name ?? "Unknown Artist")).GetHashCode())}.jpg";

        var artPath = Path.Combine(albumArtDir, artFileName);
        // Only write if file doesn't exist
        if (!File.Exists(artPath))
            File.WriteAllBytes(artPath, pic.Data.Data);

        album.AlbumArtPath = artFileName;
    }
}
