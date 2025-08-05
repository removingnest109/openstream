using System.IO;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Openstream.Core.Data;
using Openstream.Core.Models;
using Openstream.Server.Services;
using Openstream.Server;
using Xunit;
using Moq;

public class AlbumArtServiceTests
{
    private readonly AlbumArtService _service;
    private readonly MusicDbContext _db;
    private readonly string _testMusicPath = Path.Combine(Path.GetTempPath(), "music");

    public AlbumArtServiceTests()
    {
        var options = new DbContextOptionsBuilder<MusicDbContext>()
            .UseInMemoryDatabase(databaseName: "AlbumArtServiceTests")
            .Options;
        _db = new MusicDbContext(options);
        var configDict = new Dictionary<string, string>
        {
            { "Ingestion:MusicLibraryPath", _testMusicPath }
        };
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(configDict)
            .Build();
        _service = new AlbumArtService(_db, configuration);
}

    [Fact]
    public async Task UploadAlbumArtAsync_ReturnsError_WhenAlbumNotFound()
    {
        var fileMock = new Mock<IFormFile>();
        var result = await _service.UploadAlbumArtAsync(1, fileMock.Object);
        Assert.False(result.Success);
        Assert.Equal("Album not found.", result.ErrorMessage);
    }

    [Theory]
    [InlineData("image/png", "cover.png", 101)]
    [InlineData("image/gif", "cover.gif", 102)]
    [InlineData("application/octet-stream", "cover.txt", 103)]
    public async Task UploadAlbumArtAsync_ReturnsError_WhenFileTypeNotJpeg(string contentType, string fileName, int albumId)
    {
        var album = new Album { Id = albumId };
        _db.Albums.Add(album);
        await _db.SaveChangesAsync();
        var fileMock = new Mock<IFormFile>();
        fileMock.Setup(f => f.ContentType).Returns(contentType);
        fileMock.Setup(f => f.FileName).Returns(fileName);
        var result = await _service.UploadAlbumArtAsync(albumId, fileMock.Object);
        Assert.False(result.Success);
        Assert.Equal("Only JPG images are supported.", result.ErrorMessage);
    }

    [Fact]
    public async Task UploadAlbumArtAsync_SavesFileAndUpdatesAlbum_WhenValidJpeg()
    {
        var album = new Album { Id = 2 };
        _db.Albums.Add(album);
        await _db.SaveChangesAsync();
        var fileMock = new Mock<IFormFile>();
        fileMock.Setup(f => f.ContentType).Returns("image/jpeg");
        fileMock.Setup(f => f.FileName).Returns("cover.jpg");
        var ms = new MemoryStream(new byte[] { 1, 2, 3 });
        fileMock.Setup(f => f.CopyToAsync(It.IsAny<Stream>(), default)).Returns((Stream s, System.Threading.CancellationToken t) => ms.CopyToAsync(s));
        var result = await _service.UploadAlbumArtAsync(2, fileMock.Object);
        Assert.True(result.Success);
        Assert.Null(result.ErrorMessage);
        Assert.Equal("2.jpg", album.AlbumArtPath);
        // Clean up
        var artPath = Path.Combine(_testMusicPath, "albumart", "2.jpg");
        if (File.Exists(artPath)) File.Delete(artPath);
    }
}