using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Openstream.Core.Data;
using Openstream.Core.Models;
using System.Threading.Tasks;
using System.Collections.Generic;

namespace Openstream.Server.Controllers;

[ApiController]
[Route("api/playlists")]
public class PlaylistsController : ControllerBase
{
    private readonly MusicDbContext _db;
    public PlaylistsController(MusicDbContext db)
    {
        _db = db;
    }

    // GET: api/playlists
    [HttpGet]
    public async Task<ActionResult<IEnumerable<Playlist>>> GetPlaylists()
    {
        var playlists = await _db.Playlists.Include(p => p.Tracks).ToListAsync();
        return Ok(playlists);
    }

    // GET: api/playlists/{id}
    [HttpGet("{id}")]
    public async Task<ActionResult<Playlist>> GetPlaylist(int id)
    {
        var playlist = await _db.Playlists.Include(p => p.Tracks).FirstOrDefaultAsync(p => p.Id == id);
        if (playlist == null)
            return NotFound();
        return Ok(playlist);
    }

    // POST: api/playlists
    [HttpPost]
    public async Task<ActionResult<Playlist>> CreatePlaylist([FromBody] PlaylistCreateDto dto)
    {
        var tracks = await _db.Tracks.Where(t => dto.TrackIds.Contains(t.Id)).ToListAsync();
        var playlist = new Playlist
        {
            Name = dto.Name,
            Tracks = tracks
        };
        _db.Playlists.Add(playlist);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetPlaylist), new { id = playlist.Id }, playlist);
    }
}

public class PlaylistCreateDto
{
    public string Name { get; set; } = string.Empty;
    public List<Guid> TrackIds { get; set; } = new();
}
