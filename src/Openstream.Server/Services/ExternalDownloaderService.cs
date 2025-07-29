using System.Diagnostics;
using Microsoft.Extensions.Logging;

namespace Openstream.Server.Services;

public class ExternalDownloaderService
{
    private readonly ILogger<ExternalDownloaderService> _logger;
    private readonly string _musicLibraryPath;

    public ExternalDownloaderService(ILogger<ExternalDownloaderService> logger, string musicLibraryPath)
    {
        _logger = logger;
        _musicLibraryPath = musicLibraryPath;
    }


    public async Task<(bool Success, string? Error)> DownloadAsync(string url, CancellationToken cancellationToken = default)
    {
        var tool = "yt-dlp";
        var args = $"-x --audio-format mp3 --yes-playlist -o {_musicLibraryPath}/%(title)s.%(ext)s {EscapeArg(url)}";

        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = tool,
                Arguments = args,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            using var process = Process.Start(psi);
            if (process == null)
                return (false, $"Failed to start {tool}");
            await process.WaitForExitAsync(cancellationToken);
            if (process.ExitCode != 0)
            {
                var error = await process.StandardError.ReadToEndAsync();
                _logger.LogError("{Tool} failed: {Error}", tool, error);
                return (false, error);
            }
            return (true, null);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Exception running {Tool}", tool);
            return (false, ex.Message);
        }
    }

    private static string EscapeArg(string arg) => arg.Replace("\"", "\\\"");
}
