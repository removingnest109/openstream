using Xunit;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Openstream.Server.Controllers;
using Openstream.Core.Data;
using Openstream.Core.Models;
using System;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Linq;

public class TracksControllerTests
{
    private MusicDbContext CreateDb(string dbName)
    {
        var options = new DbContextOptionsBuilder<MusicDbContext>()
            .UseInMemoryDatabase(databaseName: dbName)
            .Options;
        return new MusicDbContext(options);
    }

    private TracksController CreateController(MusicDbContext db, string musicPath)
    {
        var config = Microsoft.Extensions.Options.Options.Create(new Openstream.Server.IngestionConfig { MusicLibraryPath = musicPath });
        var ingestion = new Openstream.Server.Services.MusicIngestionService(new Microsoft.Extensions.Logging.Abstractions.NullLogger<Openstream.Server.Services.MusicIngestionService>());
        var scanner = new Openstream.Server.Services.MusicScanner(musicPath);
        return new TracksController(db, config, ingestion, scanner);
    }

    [Fact]
    public async Task GetTracks_ReturnsEmpty_WhenNoTracks()
    {
        var db = CreateDb(Guid.NewGuid().ToString());
        var controller = CreateController(db, "/tmp/music");
        var result = await controller.GetTracks(null);
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.NotNull(okResult.Value);
        var tracks = okResult.Value as System.Collections.IEnumerable;
        Assert.NotNull(tracks);
        Assert.False(tracks.GetEnumerator().MoveNext());
    }

    [Fact]
    public async Task GetTracks_ReturnsTracks_WhenPresent()
    {
        var db = CreateDb(Guid.NewGuid().ToString());
        var controller = CreateController(db, "/tmp/music");
        var album = new Album { Title = "Test Album", Artist = new Artist { Name = "Test Artist" } };
        db.Albums.Add(album);
        var track = new Track { Title = "Song", Album = album, AlbumId = album.Id, Path = "/tmp/music/song.mp3" };
        db.Tracks.Add(track);
        db.SaveChanges();
        var result = await controller.GetTracks(null);
        var okResult = Assert.IsType<OkObjectResult>(result);
        var tracks = okResult.Value as IEnumerable<object>;
        Assert.NotNull(tracks);
        Assert.Single(tracks);
    }

    [Fact]
    public async Task GetTracks_SearchFiltersResults()
    {
        var db = CreateDb(Guid.NewGuid().ToString());
        var controller = CreateController(db, "/tmp/music");
        var album = new Album { Title = "Test Album", Artist = new Artist { Name = "Test Artist" } };
        db.Albums.Add(album);
        var track1 = new Track { Title = "Song1", Album = album, AlbumId = album.Id, Path = "/tmp/music/song1.mp3" };
        var track2 = new Track { Title = "Other", Album = album, AlbumId = album.Id, Path = "/tmp/music/other.mp3" };
        db.Tracks.AddRange(track1, track2);
        db.SaveChanges();
        var result = await controller.GetTracks("Song1");
        var okResult = Assert.IsType<OkObjectResult>(result);
        var tracks = okResult.Value as IEnumerable<object>;
        Assert.NotNull(tracks);
        Assert.Single(tracks);
    }

    [Fact]
    public async Task StreamTrack_ReturnsNotFound_WhenTrackMissing()
    {
        var db = CreateDb(Guid.NewGuid().ToString());
        var controller = CreateController(db, "/tmp/music");
        var result = await controller.StreamTrack(Guid.NewGuid());
        Assert.IsType<NotFoundResult>(result);
    }

    [Fact]
    public async Task StreamTrack_ReturnsNotFound_WhenFileMissing()
    {
        var db = CreateDb(Guid.NewGuid().ToString());
        var controller = CreateController(db, "/tmp/music");
        var album = new Album { Title = "Test Album" };
        db.Albums.Add(album);
        var track = new Track { Title = "Song", Album = album, AlbumId = album.Id, Path = "/tmp/music/missing.mp3" };
        db.Tracks.Add(track);
        db.SaveChanges();
        var result = await controller.StreamTrack(track.Id);
        Assert.IsType<NotFoundResult>(result);
    }

    [Fact]
    public async Task StreamTrack_ReturnsPhysicalFile_WhenFileExists()
    {
        var db = CreateDb(Guid.NewGuid().ToString());
        var controller = CreateController(db, "/tmp/music");
        var album = new Album { Title = "Test Album" };
        db.Albums.Add(album);
        var track = new Track { Title = "Song", Album = album, AlbumId = album.Id, Path = "/tmp/music/test_song.mp3" };
        db.Tracks.Add(track);
        db.SaveChanges();
        // Create a dummy file
        System.IO.Directory.CreateDirectory("/tmp/music");
        System.IO.File.WriteAllText(track.Path, "dummy");
        try
        {
            var result = await controller.StreamTrack(track.Id);
            var fileResult = Assert.IsType<PhysicalFileResult>(result);
            Assert.Equal("audio/mpeg", fileResult.ContentType);
        }
        finally
        {
            System.IO.File.Delete(track.Path);
        }
    }

    [Fact]
    public void GetAlbumArt_ReturnsNotFound_WhenFileMissing()
    {
        var db = CreateDb(Guid.NewGuid().ToString());
        var controller = CreateController(db, "/tmp/music");
        var result = controller.GetAlbumArt("missing.jpg");
        Assert.IsType<NotFoundResult>(result);
    }


    [Fact]
    public async Task UploadTrack_ReturnsBadRequest_WhenNoFile()
    {
        var db = CreateDb(Guid.NewGuid().ToString());
        var controller = CreateController(db, "/tmp/music");
        var result = await controller.UploadTrack(null, default);
        var badRequest = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal("No file uploaded.", badRequest.Value);
    }

    [Fact]
    public async Task UploadTrack_ReturnsBadRequest_WhenUnsupportedFormat()
    {
        var db = CreateDb(Guid.NewGuid().ToString());
        var controller = CreateController(db, "/tmp/music");
        var fileMock = new Microsoft.AspNetCore.Http.FormFile(new System.IO.MemoryStream(new byte[1]), 0, 1, "file", "track.txt");
        var result = await controller.UploadTrack(fileMock, default);
        var badRequest = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal("Unsupported file format.", badRequest.Value);
    }

    [Fact]
    public async Task UploadTrack_ReturnsOk_WhenValidFile()
    {
        var db = CreateDb(Guid.NewGuid().ToString());
        var controller = CreateController(db, "/tmp/music");
        var fileName = "track.mp3";
        var filePath = System.IO.Path.Combine("/tmp/music", fileName);
        System.IO.Directory.CreateDirectory("/tmp/music");
        var fileMock = new Microsoft.AspNetCore.Http.FormFile(new System.IO.MemoryStream(new byte[] { 1, 2, 3 }), 0, 3, "file", fileName);
        var result = await controller.UploadTrack(fileMock, default);
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Contains("Uploaded and scanned successfully.", okResult.Value.ToString());
    }

    [Fact]
    public async Task EditTrackMetadata_ReturnsBadRequest_WhenFailure()
    {
        var db = CreateDb(Guid.NewGuid().ToString());
        var controller = CreateController(db, "/tmp/music");
        var metadataService = new Openstream.Server.Services.TrackMetadataService(db);
        var dto = new Openstream.Server.Controllers.TrackEditDto { Title = "Title", AlbumTitle = "Album", ArtistName = "Artist" };
        var result = await controller.EditTrackMetadata(Guid.NewGuid(), dto, metadataService);
        var badRequest = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal("Track not found.", badRequest.Value);
    }

}
