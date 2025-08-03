using Xunit;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Openstream.Server.Controllers;
using Openstream.Core.Data;
using Openstream.Core.Models;
using System;
using System.Threading.Tasks;

public class TracksControllerTests
{
    private readonly MusicDbContext _db;
    private readonly TracksController _controller;

    public TracksControllerTests()
    {
        var options = new DbContextOptionsBuilder<MusicDbContext>()
            .UseInMemoryDatabase(databaseName: "TracksTestDb")
            .Options;
        _db = new MusicDbContext(options);
        var config = Microsoft.Extensions.Options.Options.Create(new Openstream.Server.IngestionConfig { MusicLibraryPath = "/music" });
        var ingestion = new Openstream.Server.Services.MusicIngestionService(new Microsoft.Extensions.Logging.Abstractions.NullLogger<Openstream.Server.Services.MusicIngestionService>());
        var scanner = new Openstream.Server.Services.MusicScanner("/music");
        _controller = new TracksController(_db, config, ingestion, scanner);
    }

    [Fact]
    public async Task GetTracks_ReturnsEmpty_WhenNoTracks()
    {
        var result = await _controller.GetTracks(null);
        var okResult = Assert.IsType<OkObjectResult>(result);
        // Try to extract the tracks list from the returned value
        var value = okResult.Value;
        var tracksProp = value?.GetType().GetProperty("tracks");
        var tracks = tracksProp?.GetValue(value) as System.Collections.IEnumerable;
        Assert.True(tracks == null || !tracks.GetEnumerator().MoveNext(), "Tracks should be empty");
    }

    [Fact]
    public async Task StreamTrack_ReturnsNotFound_WhenMissing()
    {
        var result = await _controller.StreamTrack(Guid.NewGuid());
        Assert.IsType<NotFoundResult>(result);
    }
}
