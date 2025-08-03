using Xunit;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Openstream.Server.Controllers;
using Openstream.Server.Services;
using Openstream.Core.Data;
using System.Threading;
using System.Threading.Tasks;
using Openstream.Server;

public class IngestionControllerTests
{
    private readonly MusicDbContext _db;
    private readonly MusicIngestionService _ingestion;
    private readonly MusicScanner _scanner;
    private readonly IngestionController _controller;

    public IngestionControllerTests()
    {
        var options = new DbContextOptionsBuilder<MusicDbContext>()
            .UseInMemoryDatabase(databaseName: "IngestionTestDb")
            .Options;
        _db = new MusicDbContext(options);
        _ingestion = new MusicIngestionService(new Microsoft.Extensions.Logging.Abstractions.NullLogger<MusicIngestionService>());
        var musicPath = System.IO.Path.GetFullPath("./music");
        _scanner = new MusicScanner(musicPath);
        var config = Options.Create(new IngestionConfig { MusicLibraryPath = musicPath });
        _controller = new IngestionController(config, _ingestion, _scanner, _db);
    }

    [Fact]
    public async Task ScanLibrary_ReturnsOk()
    {
        // Ensure music directory exists
        var musicPath = System.IO.Path.GetFullPath("./music");
        if (!System.IO.Directory.Exists(musicPath))
            System.IO.Directory.CreateDirectory(musicPath);
        // Optionally add a dummy file
        var dummyFile = System.IO.Path.Combine(musicPath, "dummy.mp3");
        if (!System.IO.File.Exists(dummyFile))
            System.IO.File.WriteAllText(dummyFile, "test");

        var result = await _controller.ScanLibrary(CancellationToken.None);
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Contains("Scan complete", okResult.Value.ToString());
    }
    // Removed Scan_ReturnsOk test because Scan method does not exist in IngestionController
}
