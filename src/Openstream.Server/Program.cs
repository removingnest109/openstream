using Openstream.Server;
using Openstream.Server.Services;
using Openstream.Core.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using System.Text.Json.Serialization;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Options;

var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.ReferenceHandler = ReferenceHandler.IgnoreCycles;
    });

builder.Services.AddEndpointsApiExplorer();

// Add SPA static files and proxy
builder.Services.AddSpaStaticFiles(configuration => {
    configuration.RootPath = "wwwroot/dist";
});

// Configure database
builder.Services.AddDbContext<MusicDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        sqlOptions => sqlOptions.EnableRetryOnFailure()
    )
);


// Register ingestion background service
// Pass the configured music library path to MusicScanner
var musicLibraryPath = builder.Configuration.GetSection("Ingestion").Get<IngestionConfig>()?.MusicLibraryPath
    ?? Path.Combine(AppContext.BaseDirectory, "music");
builder.Services.AddSingleton(new MusicScanner(musicLibraryPath));
builder.Services.Configure<IngestionConfig>(builder.Configuration.GetSection("Ingestion"));
builder.Services.AddSingleton<MusicIngestionService>();
builder.Services.AddHostedService<Worker>();


// Configure authentication
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = builder.Configuration["Auth:Authority"];
        options.Audience = builder.Configuration["Auth:Audience"];
    });

builder.WebHost.UseUrls("http://0.0.0.0:9090");
var app = builder.Build();


// Initialize database with retry logic
var maxRetries = 30;
var delaySeconds = 2;
var initialized = false;
for (var attempt = 1; attempt <= maxRetries && !initialized; attempt++)
{
    try
    {
        using var scope = app.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<MusicDbContext>();
        db.Database.Migrate();
        initialized = true;
    }
    catch (Exception ex)
    {
        // If the error is "already exists", log and continue
        if (ex.Message.Contains("already exists", StringComparison.OrdinalIgnoreCase))
        {
            Console.WriteLine($"[Startup] Database already exists, continuing. ({ex.Message})");
            initialized = true;
            break;
        }
        Console.WriteLine($"[Startup] Database connection failed (attempt {attempt}/{maxRetries}): {ex.Message}");
        if (attempt == maxRetries) throw;
        Thread.Sleep(delaySeconds * 1000);
    }
}

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();

app.UseStaticFiles();         // Serve static assets from wwwroot
app.UseSpaStaticFiles();      // Serve static assets from wwwroot/dist

app.MapControllers();         // Map your API controllers
app.MapGet("/health", () => "Healthy");

// ⬇️ Fallback to index.html for SPA
app.UseSpa(spa =>
{
    spa.Options.SourcePath = "wwwroot";
    spa.Options.DefaultPageStaticFileOptions = new StaticFileOptions
    {
        FileProvider = new PhysicalFileProvider(
            Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "dist")),
        RequestPath = ""
    };
});

app.Run();