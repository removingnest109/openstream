namespace Openstream.Core.Models;

public class Artist
{
    public int Id { get; set; }
    public string Name { get; set; } = "Unknown Artist";
    public List<Album> Albums { get; } = new();
}

public class Album
{
    public int Id { get; set; }
    public string Title { get; set; } = "Unknown Album";
    public int ArtistId { get; set; }
    public Artist? Artist { get; set; }
    public int? Year { get; set; }
    public List<Track> Tracks { get; } = new();
    public string? AlbumArtPath { get; set; } // Relative path to album art image
}

public class Track
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Title { get; set; } = string.Empty;
    public string Path { get; set; } = string.Empty;
    public TimeSpan Duration { get; set; }
    public int TrackNumber { get; set; }
    public int AlbumId { get; set; }
    public Album? Album { get; set; }
    public DateTime DateAdded { get; set; } = DateTime.UtcNow;
}
