using Openstream.Core.Data;
using Openstream.Server.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Openstream.Core.Models;

namespace Openstream.Server;

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

                var ingestionService = scope.ServiceProvider.GetRequiredService<MusicIngestionService>();
                await ingestionService.ScanDirectoryAsync(config.Value.MusicLibraryPath, db, scanner, stoppingToken);

            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Ingestion failed");
            }
            
            await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
        }
    }
}

public class IngestionConfig
{
    public string MusicLibraryPath { get; set; } = "/music";
}
