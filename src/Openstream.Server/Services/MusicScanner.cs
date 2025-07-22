using Openstream.Core.Models;

namespace Openstream.Server.Services;

public class MusicScanner
{
    public Track? ProcessFile(string filePath)
    {
        if (!System.IO.File.Exists(filePath)) return null;
        
        try
        {
            using var file = TagLib.File.Create(filePath);
            
            return new Track
            {
                Title = file.Tag.Title ?? Path.GetFileNameWithoutExtension(filePath),
                Path = filePath,
                Duration = file.Properties.Duration,
                TrackNumber = (int)file.Tag.Track,
                Album = new Album
                {
                    Title = file.Tag.Album ?? "Unknown Album",
                    Year = (int?)file.Tag.Year,
                    Artist = new Artist
                    {
                        Name = file.Tag.FirstPerformer ?? "Unknown Artist"
                    }
                }
            };
        }
        catch
        {
            return null;
        }
    }
}
