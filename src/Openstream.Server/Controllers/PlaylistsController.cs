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
        // Project playlists to include AlbumArtPath for each track's album
        var result = playlists.Select(p => new {
            p.Id,
            p.Name,
            p.CreatedAt,
            Tracks = p.Tracks.Select(t => new {
                t.Id,
                t.Title,
                t.Path,
                t.Duration,
                t.TrackNumber,
                t.AlbumId,
                Album = t.Album == null ? null : new {
                    t.Album.Id,
                    t.Album.Title,
                    t.Album.ArtistId,
                    t.Album.Year,
                    t.Album.AlbumArtPath
                },
                t.DateAdded
            })
        });
        return Ok(result);
    }

    // GET: api/playlists/{id}
    [HttpGet("{id}")]
    public async Task<ActionResult<Playlist>> GetPlaylist(int id)
    {
        var playlist = await _db.Playlists.Include(p => p.Tracks).FirstOrDefaultAsync(p => p.Id == id);
        if (playlist == null)
            return NotFound();
        // Project playlist to include AlbumArtPath for each track's album
        var result = new {
            playlist.Id,
            playlist.Name,
            playlist.CreatedAt,
            Tracks = playlist.Tracks.Select(t => new {
                t.Id,
                t.Title,
                t.Path,
                t.Duration,
                t.TrackNumber,
                t.AlbumId,
                Album = t.Album == null ? null : new {
                    t.Album.Id,
                    t.Album.Title,
                    t.Album.ArtistId,
                    t.Album.Year,
                    t.Album.AlbumArtPath
                },
                t.DateAdded
            })
        };
        return Ok(result);
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
