using Openstream.Core.Data;
using Openstream.Core.Models;
using Microsoft.EntityFrameworkCore;
using TagLib;

namespace Openstream.Server.Services;



public class TrackMetadataService
{
    private readonly MusicDbContext _db;
    public TrackMetadataService(MusicDbContext db)
    {
        _db = db;
    }

    public async Task<(bool Success, string? ErrorMessage)> UpdateTrackMetadataAsync(Guid trackId, Openstream.Server.Controllers.TrackEditDto dto)
    {
        var track = await _db.Tracks.Include(t => t.Album).ThenInclude(a => a.Artist).FirstOrDefaultAsync(t => t.Id == trackId);
        if (track == null) return (false, "Track not found.");
        // Find or create artist
        var artist = await _db.Artists.FirstOrDefaultAsync(a => a.Name == dto.ArtistName);
        if (artist == null)
        {
            artist = new Artist { Name = dto.ArtistName };
            _db.Artists.Add(artist);
            await _db.SaveChangesAsync();
        }
        // Find or create album
        var album = await _db.Albums.FirstOrDefaultAsync(a => a.Title == dto.AlbumTitle && a.ArtistId == artist.Id);
        if (album == null)
        {
            album = new Album { Title = dto.AlbumTitle, Artist = artist };
            _db.Albums.Add(album);
            await _db.SaveChangesAsync();
        }
        // Update track
        track.Title = dto.Title;
        track.Album = album;
        await _db.SaveChangesAsync();
        // Update file metadata
        try
        {
            using var file = TagLib.File.Create(track.Path);
            file.Tag.Title = dto.Title;
            file.Tag.Album = dto.AlbumTitle;
            file.Tag.Performers = new[] { dto.ArtistName };
            file.Save();
        }
        catch (Exception ex)
        {
            return (false, $"Metadata updated in DB, but failed to update file: {ex.Message}");
        }
        return (true, null);
    }
}
