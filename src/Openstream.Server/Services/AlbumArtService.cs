using Microsoft.AspNetCore.Http;
using Openstream.Core.Data;
using Openstream.Core.Models;
using Microsoft.EntityFrameworkCore;

namespace Openstream.Server.Services;

public class AlbumArtService
{
    private readonly MusicDbContext _db;
    private readonly string _musicLibraryPath;
    public AlbumArtService(MusicDbContext db, IConfiguration config)
    {
        _db = db;
        _musicLibraryPath = config.GetSection("Ingestion").Get<IngestionConfig>()?.MusicLibraryPath
            ?? Path.Combine(AppContext.BaseDirectory, "music");
    }

    public async Task<(bool Success, string? ErrorMessage)> UploadAlbumArtAsync(int albumId, IFormFile file)
    {
        var album = await _db.Albums.FindAsync(albumId);
        if (album == null) return (false, "Album not found.");
        if (!file.ContentType.Contains("jpeg") && !file.FileName.EndsWith(".jpg", StringComparison.OrdinalIgnoreCase))
            return (false, "Only JPG images are supported.");
        var albumArtDir = Path.Combine(_musicLibraryPath, "albumart");
        Directory.CreateDirectory(albumArtDir);
        var artFileName = $"{albumId}.jpg";
        var artPath = Path.Combine(albumArtDir, artFileName);
        using (var stream = new FileStream(artPath, FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }
        album.AlbumArtPath = artFileName;
        await _db.SaveChangesAsync();
        return (true, null);
    }
}
