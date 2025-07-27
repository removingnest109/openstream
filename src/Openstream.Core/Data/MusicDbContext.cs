using Microsoft.EntityFrameworkCore;
using Openstream.Core.Models;

namespace Openstream.Core.Data;

public class MusicDbContext : DbContext
{
    public MusicDbContext(DbContextOptions<MusicDbContext> options) : base(options) { }

    public DbSet<Track> Tracks => Set<Track>();
    public DbSet<Album> Albums => Set<Album>();
    public DbSet<Artist> Artists => Set<Artist>();
    public DbSet<Playlist> Playlists => Set<Playlist>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Artist>()
            .HasIndex(a => a.Name)
            .IsUnique();

        modelBuilder.Entity<Album>()
            .HasIndex(a => new { a.Title, a.ArtistId })
            .IsUnique();

        modelBuilder.Entity<Track>()
            .Property(t => t.Duration)
            .HasConversion(
                v => v.Ticks,
                v => TimeSpan.FromTicks(v));

        // Playlist-Track many-to-many
        modelBuilder.Entity<Playlist>()
            .HasMany(p => p.Tracks)
            .WithMany();
    }
}
