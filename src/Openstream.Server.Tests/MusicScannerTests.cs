using Xunit;
using Moq;
using System.IO;
using System;
using System.Linq;
using Openstream.Server.Services;
using Openstream.Core.Models;
using TagLib;

public class MusicScannerTests
{
    private readonly string _testMusicPath;
    private readonly string _albumArtDir;

    public MusicScannerTests()
    {
        _testMusicPath = Path.Combine(Path.GetTempPath(), "music_scanner_test");
        _albumArtDir = Path.Combine(_testMusicPath, "albumart");
        if (!Directory.Exists(_testMusicPath))
            Directory.CreateDirectory(_testMusicPath);
        if (Directory.Exists(_albumArtDir))
            Directory.Delete(_albumArtDir, true);
    }

    [Fact]
    public void ProcessFile_ReturnsNull_WhenFileMissing()
    {
        var scanner = new MusicScanner(_testMusicPath);
        var result = scanner.ProcessFile(System.IO.Path.Combine(_testMusicPath, "missing.mp3"));
        Assert.Null(result);
    }

    [Fact]
    public void ProcessFile_ReturnsNull_WhenFileCorrupt()
    {
        var filePath = System.IO.Path.Combine(_testMusicPath, "corrupt.mp3");
        System.IO.File.WriteAllText(filePath, "not an mp3");
        var scanner = new MusicScanner(_testMusicPath);
        var result = scanner.ProcessFile(filePath);
        Assert.Null(result);
    }

    [Fact]
    public void ProcessFile_ExtractsAlbumArt_WhenPresent()
    {
        var filePath = System.IO.Path.Combine(_testMusicPath, "test_with_art.mp3");
        CreateTestMp3(filePath, withArt: true);
        var scanner = new MusicScanner(_testMusicPath);
        var track = scanner.ProcessFile(filePath, 42);
        Assert.NotNull(track);
        Assert.NotNull(track.Album);
        Assert.Equal("Test Album", track.Album.Title);
        Assert.Equal("Test Artist", track.Album.Artist.Name);
        Assert.Equal("42.jpg", track.Album.AlbumArtPath);
        Assert.True(System.IO.File.Exists(System.IO.Path.Combine(_albumArtDir, "42.jpg")));
    }

    [Fact]
    public void ProcessFile_HandlesNoAlbumArt()
    {
        var filePath = System.IO.Path.Combine(_testMusicPath, "test_no_art.mp3");
        CreateTestMp3(filePath, withArt: false);
        var scanner = new MusicScanner(_testMusicPath);
        var track = scanner.ProcessFile(filePath);
        Assert.NotNull(track);
        Assert.NotNull(track.Album);
        Assert.Null(track.Album.AlbumArtPath);
    }

    [Fact]
    public void ExtractAndAssignAlbumArt_PrefersCoverDescription()
    {
        var filePath = System.IO.Path.Combine(_testMusicPath, "test_cover.mp3");
        CreateTestMp3(filePath, withArt: true, coverDescription: "Cover");
        var scanner = new MusicScanner(_testMusicPath);
        var track = scanner.ProcessFile(filePath, 99);
        Assert.NotNull(track);
        Assert.Equal("99.jpg", track.Album.AlbumArtPath);
        Assert.True(System.IO.File.Exists(System.IO.Path.Combine(_albumArtDir, "99.jpg")));
    }

    [Fact]
    public void ExtractAndAssignAlbumArt_FallbacksToFirstPicture()
    {
        var filePath = System.IO.Path.Combine(_testMusicPath, "test_fallback.mp3");
        CreateTestMp3(filePath, withArt: true, coverDescription: "Other");
        var scanner = new MusicScanner(_testMusicPath);
        var track = scanner.ProcessFile(filePath, 77);
        Assert.NotNull(track);
        Assert.Equal("77.jpg", track.Album.AlbumArtPath);
        Assert.True(System.IO.File.Exists(System.IO.Path.Combine(_albumArtDir, "77.jpg")));
    }

    private void CreateTestMp3(string filePath, bool withArt, string coverDescription = "Cover")
    {
        // Copy the real test MP3 file from resources
        var resourcePath = System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Resources", "test.mp3");
        if (!System.IO.File.Exists(resourcePath))
            throw new FileNotFoundException($"Test MP3 resource not found: {resourcePath}");
        System.IO.File.Copy(resourcePath, filePath, true);

        var tagFile = TagLib.File.Create(filePath);
        tagFile.Tag.Title = "Test Track";
        tagFile.Tag.Album = "Test Album";
        tagFile.Tag.Year = 2025;
        tagFile.Tag.Performers = new[] { "Test Artist" };
        tagFile.Tag.Track = 1;
        if (withArt)
        {
            var pic = new TagLib.Picture
            {
                Type = TagLib.PictureType.FrontCover,
                Description = coverDescription,
                MimeType = "image/jpeg",
                Data = new TagLib.ByteVector(new byte[] { 1, 2, 3, 4 })
            };
            tagFile.Tag.Pictures = new[] { pic };
        }
        tagFile.Save();
    }
}
