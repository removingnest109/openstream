using Xunit;
using Microsoft.EntityFrameworkCore;
using Openstream.Server.Services;
using Openstream.Core.Data;
using Openstream.Core.Models;
using Openstream.Server.Controllers;
using System.Threading.Tasks;
using System;
using System.Linq;

public class TrackMetadataServiceTests
{
    private MusicDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<MusicDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        return new MusicDbContext(options);
    }


    [Fact]
    public async Task UpdateTrackMetadataAsync_ReturnsFalse_WhenTrackMissing()
    {
        using var db = CreateDbContext();
        var service = new TrackMetadataService(db);
        var dto = new TrackEditDto { Title = "Title", AlbumTitle = "Album", ArtistName = "Artist" };
        var result = await service.UpdateTrackMetadataAsync(System.Guid.NewGuid(), dto);
        Assert.False(result.Success);
        Assert.Equal("Track not found.", result.ErrorMessage);
    }

    [Fact]
    public async Task UpdateTrackMetadataAsync_CreatesArtistAndAlbum_AndUpdatesTrack()
    {
        using var db = CreateDbContext();
        var service = new TrackMetadataService(db);
        var artist = new Artist { Name = "DummyArtist" };
        db.Artists.Add(artist);
        await db.SaveChangesAsync();
        var album = new Album { Title = "DummyAlbum", ArtistId = artist.Id, Artist = artist };
        db.Albums.Add(album);
        await db.SaveChangesAsync();
        var track = new Track { Id = Guid.NewGuid(), Title = "OldTitle", Path = GetTestMp3Path(), TrackNumber = 1, AlbumId = album.Id, Album = album };
        db.Tracks.Add(track);
        await db.SaveChangesAsync();
        var dto = new TrackEditDto { Title = "NewTitle", AlbumTitle = "NewAlbum", ArtistName = "NewArtist" };
        var result = await service.UpdateTrackMetadataAsync(track.Id, dto);
        Assert.True(result.Success);
        var updated = await db.Tracks.Include(t => t.Album).ThenInclude(a => a.Artist).FirstOrDefaultAsync(t => t.Id == track.Id);
        Assert.Equal("NewTitle", updated.Title);
        Assert.Equal("NewAlbum", updated.Album.Title);
        Assert.Equal("NewArtist", updated.Album.Artist.Name);
    }

    [Fact]
    public async Task UpdateTrackMetadataAsync_UsesExistingArtistAndAlbum()
    {
        using var db = CreateDbContext();
        var service = new TrackMetadataService(db);
        var artist = new Artist { Name = "ArtistA" };
        db.Artists.Add(artist);
        await db.SaveChangesAsync();
        var album = new Album { Title = "AlbumA", Artist = artist };
        db.Albums.Add(album);
        await db.SaveChangesAsync();
        var track = new Track { Id = Guid.NewGuid(), Title = "OldTitle", Path = GetTestMp3Path(), TrackNumber = 1, Album = album };
        db.Tracks.Add(track);
        await db.SaveChangesAsync();
        var dto = new TrackEditDto { Title = "NewTitle", AlbumTitle = "AlbumA", ArtistName = "ArtistA" };
        var result = await service.UpdateTrackMetadataAsync(track.Id, dto);
        Assert.True(result.Success);
        var updated = await db.Tracks.Include(t => t.Album).ThenInclude(a => a.Artist).FirstOrDefaultAsync(t => t.Id == track.Id);
        Assert.Equal("NewTitle", updated.Title);
        Assert.Equal(album.Id, updated.Album.Id);
        Assert.Equal(artist.Id, updated.Album.Artist.Id);
    }

    [Fact]
    public async Task UpdateTrackMetadataAsync_UpdatesFileMetadata()
    {
        using var db = CreateDbContext();
        var service = new TrackMetadataService(db);
        var artist = new Artist { Name = "DummyArtist" };
        db.Artists.Add(artist);
        await db.SaveChangesAsync();
        var album = new Album { Title = "DummyAlbum", ArtistId = artist.Id, Artist = artist };
        db.Albums.Add(album);
        await db.SaveChangesAsync();
        var track = new Track { Id = Guid.NewGuid(), Title = "OldTitle", Path = GetTestMp3Path(), TrackNumber = 1, AlbumId = album.Id, Album = album };
        db.Tracks.Add(track);
        await db.SaveChangesAsync();
        var dto = new TrackEditDto { Title = "MetaTitle", AlbumTitle = "MetaAlbum", ArtistName = "MetaArtist" };
        var result = await service.UpdateTrackMetadataAsync(track.Id, dto);
        Assert.True(result.Success);
        // Check file metadata
        var file = TagLib.File.Create(track.Path);
        Assert.Equal("MetaTitle", file.Tag.Title);
        Assert.Equal("MetaAlbum", file.Tag.Album);
        Assert.Equal("MetaArtist", file.Tag.Performers.FirstOrDefault());
    }

    [Fact]
    public async Task UpdateTrackMetadataAsync_ReturnsError_WhenFileUpdateFails()
    {
        using var db = CreateDbContext();
        var service = new TrackMetadataService(db);
        var filePath = GetTestMp3Path();
        System.IO.File.Delete(filePath); // Remove file to cause TagLib# to fail
        var artist = new Artist { Name = "DummyArtist" };
        db.Artists.Add(artist);
        await db.SaveChangesAsync();
        var album = new Album { Title = "DummyAlbum", ArtistId = artist.Id, Artist = artist };
        db.Albums.Add(album);
        await db.SaveChangesAsync();
        var track = new Track { Id = Guid.NewGuid(), Title = "OldTitle", Path = filePath, TrackNumber = 1, AlbumId = album.Id, Album = album };
        db.Tracks.Add(track);
        await db.SaveChangesAsync();
        var dto = new TrackEditDto { Title = "Title", AlbumTitle = "Album", ArtistName = "Artist" };
        var result = await service.UpdateTrackMetadataAsync(track.Id, dto);
        Assert.False(result.Success);
        Assert.Contains("Metadata updated in DB, but failed to update file", result.ErrorMessage);
    }

    private string GetTestMp3Path()
    {
        // Copy the test MP3 resource to a temp file for each test
        var resourcePath = System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Resources", "test.mp3");
        var tempPath = System.IO.Path.Combine(System.IO.Path.GetTempPath(), $"trackmeta_{Guid.NewGuid()}.mp3");
        System.IO.File.Copy(resourcePath, tempPath, true);
        // Ensure the file is writable
        var fileInfo = new System.IO.FileInfo(tempPath);
        fileInfo.IsReadOnly = false;
        return tempPath;
    }
}
