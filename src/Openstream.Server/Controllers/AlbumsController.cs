using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using Openstream.Core.Data;
using Openstream.Server.Services;
using System.Threading.Tasks;

namespace Openstream.Server.Controllers;

[ApiController]
[Route("api/albums")]
public class AlbumsController : ControllerBase
{
    private readonly MusicDbContext _db;
    private readonly AlbumArtService _albumArtService;

    public AlbumsController(MusicDbContext db, AlbumArtService albumArtService)
    {
        _db = db;
        _albumArtService = albumArtService;
    }

    [HttpPost("{id}/art")]
    public async Task<IActionResult> UploadAlbumArt(int id, [FromForm] IFormFile file)
    {
        if (file == null || file.Length == 0)
            return BadRequest("No file uploaded.");
        var result = await _albumArtService.UploadAlbumArtAsync(id, file);
        if (!result.Success)
            return BadRequest(result.ErrorMessage);
        return Ok(new { status = "Album art uploaded successfully." });
    }
}
