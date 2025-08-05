using Xunit;
using Microsoft.EntityFrameworkCore;
using Moq;
using Openstream.Server.Services;
using Openstream.Core.Data;
using Openstream.Core.Models;
using System.Threading;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Microsoft.Extensions.Logging;

public class TestMusicScanner : MusicScanner
{
    private readonly Dictionary<string, Track> _trackMap = new();
    public TestMusicScanner(string musicLibraryPath) : base(musicLibraryPath) { }
    public void SetTrack(string filePath, Track track) => _trackMap[filePath] = track;
    public override Track ProcessFile(string filePath, int? albumId = null)
    {
        return _trackMap.TryGetValue(filePath, out var track) ? track : null;
    }
}

public class MusicIngestionServiceTests
{
    private readonly MusicDbContext _db;
    private readonly Mock<ILogger<MusicIngestionService>> _loggerMock;
    private readonly MusicIngestionService _service;
    private readonly TestMusicScanner _scanner;
    private readonly string _testMusicPath;

    public MusicIngestionServiceTests()
    {
        var dbName = $"MusicIngestionTestDb_{System.Guid.NewGuid()}";
        var options = new DbContextOptionsBuilder<MusicDbContext>()
            .UseInMemoryDatabase(databaseName: dbName)
            .Options;
        _db = new MusicDbContext(options);
        _loggerMock = new Mock<ILogger<MusicIngestionService>>();
        _service = new MusicIngestionService(_loggerMock.Object);
        _testMusicPath = Path.Combine(Path.GetTempPath(), "music_ingestion_test");
        if (!Directory.Exists(_testMusicPath))
            Directory.CreateDirectory(_testMusicPath);
        _scanner = new TestMusicScanner(_testMusicPath);
    }

    [Fact]
    public async Task ScanDirectoryAsync_RemovesTracksWithMissingFiles()
    {
        var track = new Track { Title = "Test", Path = Path.Combine(_testMusicPath, "missing.mp3") };
        _db.Tracks.Add(track);
        await _db.SaveChangesAsync();
        await _service.ScanDirectoryAsync(_testMusicPath, _db, _scanner, CancellationToken.None);
        Assert.Empty(_db.Tracks);
    }

    [Fact]
    public async Task ScanDirectoryAsync_AddsNewTracksArtistsAlbums()
    {
        var filePath = Path.Combine(_testMusicPath, "new.mp3");
        File.WriteAllText(filePath, "dummy");
        var artist = new Artist { Name = "Artist1" };
        var album = new Album { Title = "Album1", Artist = artist, Year = 2020 };
        var trackData = new Track {
            Title = "Track1",
            Path = filePath,
            Duration = System.TimeSpan.FromSeconds(123),
            TrackNumber = 1,
            Album = album
        };
        _scanner.SetTrack(filePath, trackData);
        await _service.ScanDirectoryAsync(_testMusicPath, _db, _scanner, CancellationToken.None);
        var dbTrack = _db.Tracks.Include(t => t.Album).ThenInclude(a => a.Artist).FirstOrDefault();
        Assert.NotNull(dbTrack);
        Assert.Equal("Track1", dbTrack.Title);
        Assert.Equal("Album1", dbTrack.Album.Title);
        Assert.Equal("Artist1", dbTrack.Album.Artist.Name);
    }

    [Fact]
    public async Task ScanDirectoryAsync_UpdatesAlbumArtPath()
    {
        var filePath = Path.Combine(_testMusicPath, "art.mp3");
        File.WriteAllText(filePath, "dummy");
        var artist = new Artist { Name = "Artist2" };
        var album = new Album { Title = "Album2", Artist = artist, Year = 2021, AlbumArtPath = null };
        var trackData = new Track {
            Title = "Track2",
            Path = filePath,
            Duration = System.TimeSpan.FromSeconds(200),
            TrackNumber = 2,
            Album = new Album {
                Title = "Album2",
                Artist = artist,
                Year = 2021,
                AlbumArtPath = "new/path/to/art.jpg"
            }
        };
        _scanner.SetTrack(filePath, trackData);
        await _service.ScanDirectoryAsync(_testMusicPath, _db, _scanner, CancellationToken.None);
        var dbAlbum = _db.Albums.Include(a => a.Artist).FirstOrDefault(a => a.Title == "Album2");
        Assert.NotNull(dbAlbum);
        Assert.Equal("new/path/to/art.jpg", dbAlbum.AlbumArtPath);
    }

    [Fact]
    public async Task ScanDirectoryAsync_NoNewTracksFound()
    {
        var filePath = Path.Combine(_testMusicPath, "existing.mp3");
        File.WriteAllText(filePath, "dummy");
        var artist = new Artist { Name = "Artist3" };
        var album = new Album { Title = "Album3", Artist = artist, Year = 2022 };
        var track = new Track {
            Title = "Track3",
            Path = filePath,
            Duration = System.TimeSpan.FromSeconds(300),
            TrackNumber = 3,
            Album = album
        };
        _db.Tracks.Add(track);
        await _db.SaveChangesAsync();
        _scanner.SetTrack(filePath, null);
        await _service.ScanDirectoryAsync(_testMusicPath, _db, _scanner, CancellationToken.None);
        Assert.Single(_db.Tracks);
    }
}
