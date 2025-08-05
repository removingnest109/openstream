using System.Threading.Tasks;
using Xunit;
using Microsoft.EntityFrameworkCore;
using Openstream.Core.Data;
using Openstream.Core.Models;
using System;
using System.Linq;

public class MusicDbContextTests
{
    [Fact]
    public async Task Artist_Name_IsUnique()
    {
        var options = new DbContextOptionsBuilder<MusicDbContext>()
            .UseSqlite("Filename=:memory:")
            .Options;
        using var db = new MusicDbContext(options);
        db.Database.OpenConnection();
        db.Database.EnsureCreated();
        db.Artists.Add(new Artist { Name = "A" });
        db.SaveChanges();
        db.Artists.Add(new Artist { Name = "A" });
        await Assert.ThrowsAsync<DbUpdateException>(async () => await db.SaveChangesAsync());
        var count = await db.Artists.CountAsync(a => a.Name == "A");
        Assert.Equal(1, count); // Only one unique name allowed
    }

    [Fact]
    public async Task Album_Title_ArtistId_IsUnique()
    {
        var options = new DbContextOptionsBuilder<MusicDbContext>()
            .UseSqlite("Filename=:memory:")
            .Options;
        using var db = new MusicDbContext(options);
        db.Database.OpenConnection();
        db.Database.EnsureCreated();
        var artist = new Artist { Name = "A" };
        db.Artists.Add(artist);
        db.SaveChanges();
        db.Albums.Add(new Album { Title = "T", ArtistId = artist.Id });
        db.SaveChanges();
        db.Albums.Add(new Album { Title = "T", ArtistId = artist.Id });
        await Assert.ThrowsAsync<DbUpdateException>(async () => await db.SaveChangesAsync());
        var count = await db.Albums.CountAsync(a => a.Title == "T" && a.ArtistId == artist.Id);
        Assert.Equal(1, count); // Only one unique title per artist
    }

    [Fact]
    public void Track_Duration_Conversion_Works()
    {
        var options = new DbContextOptionsBuilder<MusicDbContext>()
            .UseInMemoryDatabase(databaseName: "TrackDurationTestDb")
            .Options;
        using var db = new MusicDbContext(options);
        var album = new Album { Title = "T", Artist = new Artist { Name = "A" } };
        db.Albums.Add(album);
        db.SaveChanges();
        var track = new Track { Title = "Song", Path = "/music/song.mp3", Duration = TimeSpan.FromSeconds(123), TrackNumber = 1, AlbumId = album.Id };
        db.Tracks.Add(track);
        db.SaveChanges();
        var loaded = db.Tracks.First();
        Assert.Equal(TimeSpan.FromSeconds(123), loaded.Duration);
    }
}
