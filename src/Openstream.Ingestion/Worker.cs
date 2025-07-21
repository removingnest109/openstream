using Openstream.Core.Data;
using Openstream.Ingestion.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Openstream.Ingestion;

public class Worker(
    ILogger<Worker> logger,
    IOptions<IngestionConfig> config,
    IServiceScopeFactory scopeFactory,
    MusicScanner scanner) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("Starting music ingestion service");
        
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<MusicDbContext>();
                
                await ScanDirectory(config.Value.MusicLibraryPath, db, scanner);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Ingestion failed");
            }
            
            await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
        }
    }

    private async Task ScanDirectory(string path, MusicDbContext db, MusicScanner scanner)
    {
        var supported = new[] { ".mp3", ".flac", ".m4a", ".wav", ".ogg" };
        var files = Directory.EnumerateFiles(path, "*.*", SearchOption.AllDirectories)
            .Where(f => supported.Contains(Path.GetExtension(f).ToLower()));
        
        foreach (var file in files)
        {
            var track = scanner.ProcessFile(file);
            if (track == null) continue;
            
            if (!await db.Tracks.AnyAsync(t => t.Path == file))
            {
                db.Tracks.Add(track);
                await db.SaveChangesAsync();
            }
        }
    }
}

public class IngestionConfig
{
    public string MusicLibraryPath { get; set; } = "/music";
}
