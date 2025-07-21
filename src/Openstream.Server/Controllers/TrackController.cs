using Openstream.Core.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Openstream.Server.Controllers;

[ApiController]
[Route("api/tracks")]
public class TracksController : ControllerBase
{
    private readonly MusicDbContext _db;

    public TracksController(MusicDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> GetTracks([FromQuery] string? search)
    {
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
        }

        return Ok(await query.ToListAsync());
    }

    [HttpGet("{id}/stream")]
    public async Task<IActionResult> StreamTrack(Guid id)
    {
        var track = await _db.Tracks.FindAsync(id);
        if (track == null || !System.IO.File.Exists(track.Path))
            return NotFound();

        return PhysicalFile(track.Path, "audio/mpeg", enableRangeProcessing: true);
    }
}
