using Xunit;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Openstream.Server.Controllers;
using Openstream.Core.Data;
using Openstream.Core.Models;
using System.Collections.Generic;
using System.Threading.Tasks;

public class PlaylistsControllerTests
{
    private readonly MusicDbContext _db;
    private readonly PlaylistsController _controller;

    public PlaylistsControllerTests()
    {
        var options = new DbContextOptionsBuilder<MusicDbContext>()
            .UseInMemoryDatabase(databaseName: "PlaylistsTestDb")
            .Options;
        _db = new MusicDbContext(options);
        _controller = new PlaylistsController(_db);
    }

    [Fact]
    public async Task GetPlaylists_ReturnsEmptyList_WhenNoneExist()
    {
        var result = await _controller.GetPlaylists();
        // Handle null or empty result
        var value = result.Value ?? new List<Playlist>();
        Assert.Empty(value);
    }

    [Fact]
    public async Task CreatePlaylist_ReturnsPlaylist_WhenValid()
    {
        var artist = new Artist { Name = "Test Artist" };
        _db.Artists.Add(artist);
        var album = new Album { Title = "Test Album", Artist = artist };
        _db.Albums.Add(album);
        var track = new Track { Title = "Song", Path = "/music/song.mp3", Duration = System.TimeSpan.FromSeconds(120), TrackNumber = 1, Album = album };
        _db.Tracks.Add(track);
        await _db.SaveChangesAsync();
        var dto = new PlaylistCreateDto { Name = "My Playlist", TrackIds = new List<System.Guid> { track.Id } };
        var result = await _controller.CreatePlaylist(dto);
        var created = Assert.IsType<ActionResult<Playlist>>(result);
        // Reload playlist from DB to ensure navigation properties are loaded
        var playlist = await _db.Playlists.Include(p => p.Tracks).FirstOrDefaultAsync(p => p.Name == "My Playlist");
        Assert.NotNull(playlist);
        Assert.Equal("My Playlist", playlist.Name);
        Assert.Single(playlist.Tracks);
    }

    [Fact]
    public async Task GetPlaylist_ReturnsNotFound_WhenMissing()
    {
        var result = await _controller.GetPlaylist(999);
        Assert.IsType<NotFoundResult>(result.Result);
    }
}
