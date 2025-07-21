using Microsoft.EntityFrameworkCore;
using Openstream.Core.Data;
using Openstream.Ingestion;
using Openstream.Ingestion.Services;

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddDbContext<MusicDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddSingleton<MusicScanner>();
builder.Services.Configure<IngestionConfig>(builder.Configuration.GetSection("Ingestion"));

builder.Services.AddHostedService<Worker>();

var host = builder.Build();
host.Run();
