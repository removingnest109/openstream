using Xunit;
using Moq;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Openstream.Server.Controllers;
using Openstream.Server.Services;
using Openstream.Core.Data;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.EntityFrameworkCore.InMemory;

public class AlbumsControllerTests
{
    private readonly MusicDbContext _db;
    private readonly AlbumArtService _albumArtService;
    private readonly AlbumsController _controller;

    public AlbumsControllerTests()
    {
        var options = new DbContextOptionsBuilder<MusicDbContext>()
            .UseInMemoryDatabase(databaseName: "TestDb")
            .Options;
        _db = new MusicDbContext(options);
        var config = new ConfigurationBuilder().AddInMemoryCollection().Build();
        _albumArtService = new AlbumArtService(_db, config);
        _controller = new AlbumsController(_db, _albumArtService);
    }

    [Fact]
    public async Task UploadAlbumArt_ReturnsBadRequest_WhenNoFile()
    {
        var result = await _controller.UploadAlbumArt(1, null);
        Assert.IsType<BadRequestObjectResult>(result);
    }
    // Note: To fully test AlbumArtService, integration tests with real files are needed.
}
