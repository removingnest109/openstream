class Artist {
  Artist({
    required this.id,
    required this.name,
    this.primaryAlbumCount = 0,
    this.trackAppearanceCount = 0,
  });

  final int id;
  final String name;
  final int primaryAlbumCount;
  final int trackAppearanceCount;

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Unknown Artist',
      primaryAlbumCount: (json['primaryAlbumCount'] as num?)?.toInt() ?? 0,
      trackAppearanceCount:
          (json['trackAppearanceCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ArtistSections {
  ArtistSections({required this.primary, required this.appearsOn});

  final List<Artist> primary;
  final List<Artist> appearsOn;

  factory ArtistSections.fromJson(Map<String, dynamic> json) {
    final primary = (json['primary'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Artist.fromJson)
        .toList();
    final appearsOn = (json['appearsOn'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Artist.fromJson)
        .toList();

    return ArtistSections(primary: primary, appearsOn: appearsOn);
  }
}

class Album {
  Album({
    required this.id,
    required this.title,
    required this.artist,
    this.artists = const <Artist>[],
    this.year,
    this.albumArtPath,
  });

  final int id;
  final String title;
  final Artist artist;
  final List<Artist> artists;
  final int? year;
  final String? albumArtPath;

  String get displayArtistNames {
    if (artists.isNotEmpty) {
      return artists.map((artist) => artist.name).join(', ');
    }
    return artist.name;
  }

  factory Album.fromJson(Map<String, dynamic> json) {
    final parsedArtists = (json['artists'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Artist.fromJson)
        .toList();

    final fallbackArtist = json['artist'] is Map<String, dynamic>
        ? Artist.fromJson(json['artist'] as Map<String, dynamic>)
        : (parsedArtists.isNotEmpty
              ? parsedArtists.first
              : Artist(id: 0, name: 'Unknown Artist'));

    return Album(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : 'Unknown Album',
      artist: fallbackArtist,
      artists: parsedArtists,
      year: (json['year'] as num?)?.toInt(),
      albumArtPath: json['albumArtPath'] as String?,
    );
  }
}

class Track {
  Track({
    required this.id,
    required this.title,
    required this.path,
    required this.duration,
    required this.trackNumber,
    required this.album,
    this.artists = const <Artist>[],
  });

  final String id;
  final String title;
  final String path;
  final Duration duration;
  final int trackNumber;
  final Album album;
  final List<Artist> artists;

  String get artistName {
    if (artists.isNotEmpty) {
      return artists.map((artist) => artist.name).join(', ');
    }
    if (album.artists.isNotEmpty) {
      return album.artists.map((artist) => artist.name).join(', ');
    }
    return album.artist.name;
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    final dynamic rawDuration = json['duration'];
    final Duration duration;
    if (rawDuration is num) {
      duration = Duration(milliseconds: rawDuration.toInt());
    } else if (rawDuration is String) {
      final parsed = int.tryParse(rawDuration);
      duration = Duration(milliseconds: parsed ?? 0);
    } else {
      duration = Duration.zero;
    }

    final parsedArtists = (json['artists'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Artist.fromJson)
        .toList();

    return Track(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : 'Untitled',
      path: (json['path'] ?? '').toString(),
      duration: duration,
      trackNumber: (json['trackNumber'] as num?)?.toInt() ?? 0,
      album: json['album'] is Map<String, dynamic>
          ? Album.fromJson(json['album'] as Map<String, dynamic>)
          : Album(
              id: 0,
              title: 'Unknown Album',
              artist: Artist(id: 0, name: 'Unknown Artist'),
            ),
      artists: parsedArtists,
    );
  }
}

class Playlist {
  Playlist({required this.id, required this.name, required this.tracks});

  final int id;
  final String name;
  final List<Track> tracks;

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final rawTracks = (json['tracks'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Track.fromJson)
        .toList();

    return Playlist(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Untitled Playlist',
      tracks: rawTracks,
    );
  }
}

class ServerConfig {
  ServerConfig({required this.name, required this.baseUrl});

  final String name;
  final String baseUrl;

  Map<String, String> toJson() => <String, String>{
    'name': name,
    'baseUrl': baseUrl,
  };

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      name: (json['name'] ?? 'Server').toString(),
      baseUrl: (json['baseUrl'] ?? '').toString(),
    );
  }
}
