using Xunit;
using Microsoft.EntityFrameworkCore;
using Openstream.Server.Services;
using Openstream.Core.Data;
using Openstream.Core.Models;
using Openstream.Server.Controllers;
using System.Threading.Tasks;

public class TrackMetadataServiceTests
{
    private readonly MusicDbContext _db;
    private readonly TrackMetadataService _service;

    public TrackMetadataServiceTests()
    {
        var options = new DbContextOptionsBuilder<MusicDbContext>()
            .UseInMemoryDatabase(databaseName: "TrackMetadataTestDb")
            .Options;
        _db = new MusicDbContext(options);
        _service = new TrackMetadataService(_db);
    }


    [Fact]
    public async Task UpdateTrackMetadataAsync_ReturnsFalse_WhenTrackMissing()
    {
        var dto = new TrackEditDto { Title = "Title", AlbumTitle = "Album", ArtistName = "Artist" };
        var result = await _service.UpdateTrackMetadataAsync(System.Guid.NewGuid(), dto);
        Assert.False(result.Success);
        Assert.Equal("Track not found.", result.ErrorMessage);
    }
}
