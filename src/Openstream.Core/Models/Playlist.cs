using System;
using System.Collections.Generic;

namespace Openstream.Core.Models;

public class Playlist
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public List<Track> Tracks { get; set; } = new();
}
