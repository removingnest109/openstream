using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Openstream.Server.Services;
using Openstream.Core.Data;

namespace Openstream.Server.Controllers;

[ApiController]
[Route("api/download")]
public class DownloadController : ControllerBase
{
    private readonly ExternalDownloaderService _downloader;
    private readonly MusicIngestionService _ingestion;
    private readonly MusicScanner _scanner;
    private readonly MusicDbContext _db;
    private readonly IngestionConfig _config;

    public DownloadController(
        ExternalDownloaderService downloader,
        MusicIngestionService ingestion,
        MusicScanner scanner,
        MusicDbContext db,
        IOptions<IngestionConfig> config)
    {
        _downloader = downloader;
        _ingestion = ingestion;
        _scanner = scanner;
        _db = db;
        _config = config.Value;
    }

    public class DownloadRequest { public string Url { get; set; } = string.Empty; }

    [HttpPost]
    public async Task<IActionResult> Download([FromBody] DownloadRequest req, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(req.Url))
            return BadRequest(new { error = "Missing URL" });
        var (success, error) = await _downloader.DownloadAsync(req.Url, cancellationToken);
        if (!success)
            return StatusCode(500, new { error });
        // Optionally trigger ingestion after download
        await _ingestion.ScanDirectoryAsync(_config.MusicLibraryPath, _db, _scanner, cancellationToken);
        return Ok(new { status = "Download and ingestion complete" });
    }
}
