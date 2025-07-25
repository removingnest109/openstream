using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Openstream.Server.Services;
using Openstream.Core.Data;

namespace Openstream.Server.Controllers;

[ApiController]
[Route("api/ingestion")]
public class IngestionController : ControllerBase
{
    private readonly IngestionConfig _config;
    private readonly MusicIngestionService _ingestion;
    private readonly MusicScanner _scanner;
    private readonly MusicDbContext _db;

    public IngestionController(
        IOptions<IngestionConfig> config,
        MusicIngestionService ingestion,
        MusicScanner scanner,
        MusicDbContext db)
    {
        _config = config.Value;
        _ingestion = ingestion;
        _scanner = scanner;
        _db = db;
    }

    [HttpPost("scan")]
    public async Task<IActionResult> ScanLibrary(CancellationToken cancellationToken)
    {
        await _ingestion.ScanDirectoryAsync(_config.MusicLibraryPath, _db, _scanner, cancellationToken);
        return Ok(new { status = "Scan complete" });
    }
}
