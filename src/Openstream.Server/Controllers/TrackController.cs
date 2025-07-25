using Openstream.Core.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Openstream.Server.Services;

namespace Openstream.Server.Controllers;

[ApiController]
[Route("api/tracks")]
public class TracksController : ControllerBase
{
    private readonly MusicDbContext _db;
    private readonly IngestionConfig _config;
    private readonly MusicIngestionService _ingestion;
    private readonly MusicScanner _scanner;
    
    public TracksController(
        MusicDbContext db,
        IOptions<IngestionConfig> config,
        MusicIngestionService ingestion,
        MusicScanner scanner)
    {
        _db = db;
        _config = config.Value;
        _ingestion = ingestion;
        _scanner = scanner;
    }

    [HttpGet]
    public async Task<IActionResult> GetTracks([FromQuery] string? search)
    {
#pragma warning disable CS8602 // Dereference of a possibly null reference.
        var query = _db.Tracks
            .Include(t => t.Album)
            .ThenInclude(a => a.Artist)
            .AsQueryable();
        if (!string.IsNullOrEmpty(search))
        {
            query = query.Where(t =>
                t.Title.Contains(search) ||
                t.Album.Title.Contains(search) ||
                t.Album.Artist.Name.Contains(search));
#pragma warning restore CS8602 // Dereference of a possibly null reference.
        }

        return Ok(await query.ToListAsync());
    }

    [HttpGet("{id}/stream")]
    public async Task<IActionResult> StreamTrack(Guid id)
    {
        var track = await _db.Tracks.FindAsync(id);
        if (track == null || !System.IO.File.Exists(track.Path))
            return NotFound();

        var ext = Path.GetExtension(track.Path).ToLowerInvariant();
        var mime = ext switch
        {
            ".mp3" => "audio/mpeg",
            ".flac" => "audio/flac",
            ".wav" => "audio/wav",
            ".ogg" => "audio/ogg",
            ".m4a" => "audio/mp4",
            _ => "application/octet-stream"
        };

        return PhysicalFile(track.Path, mime, enableRangeProcessing: true);
    }

    [HttpPost("upload")]
    [RequestSizeLimit(1_000_000_000)] // Limit ~1GB
    public async Task<IActionResult> UploadTrack([FromForm] IFormFile file, CancellationToken cancellationToken)
    {
        if (file == null || file.Length == 0)
            return BadRequest("No file uploaded.");

        var musicLibraryPath = _config.MusicLibraryPath;

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        var supported = new[] { ".mp3", ".flac", ".m4a", ".wav", ".ogg" };
        if (!supported.Contains(ext))
            return BadRequest("Unsupported file format.");

        var safeFileName = Path.GetFileNameWithoutExtension(file.FileName);
        var uniqueFileName = $"{Guid.NewGuid()}_{safeFileName}{ext}";
        var filePath = Path.Combine(musicLibraryPath, uniqueFileName);

        Directory.CreateDirectory(musicLibraryPath); // Make sure folder exists

        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await file.CopyToAsync(stream, cancellationToken);
        }

        // Scan for new tracks including this one
        await _ingestion.ScanDirectoryAsync(musicLibraryPath, _db, _scanner, cancellationToken);

        return Ok(new { path = filePath, status = "Uploaded and scanned successfully." });
    }

}
