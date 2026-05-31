import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'openstream_api.dart';

const _serversKey = 'openstream.servers';
const _activeServerIndexKey = 'openstream.activeServerIndex';
const _webServerKey = 'openstream.webServer';
const _seedColorKey = 'openstream.seedColor';
const _darkModeKey = 'openstream.darkMode';
const _volumeKey = 'openstream.volume';
const _legacyWebServerUrl = 'http://localhost:9090';

String _defaultWebServerUrl() {
  final origin = Uri.base.origin.trim();
  if (origin.isEmpty || origin == 'null') {
    return _legacyWebServerUrl;
  }
  return origin;
}

class OpenStreamController extends ChangeNotifier {
  OpenStreamController() {
    _bootstrap();
  }

  final AudioPlayer audioPlayer = AudioPlayer();

  bool isBooting = true;
  bool isLoading = false;
  String? error;

  List<ServerConfig> servers = <ServerConfig>[];
  int activeServerIndex = 0;

  String webServerUrl = _defaultWebServerUrl();

  List<Track> tracks = <Track>[];
  List<Playlist> playlists = <Playlist>[];
  List<Artist> primaryArtists = <Artist>[];
  List<Artist> appearsOnArtists = <Artist>[];

  List<Track> queue = <Track>[];
  int queueIndex = -1;

  bool shuffleEnabled = false;
  bool loopEnabled = false;
  double volume = 1.0;

  int seedColorValue = 0xFF6D4AFF;
  bool darkMode = true;

  OpenStreamApi? _api;

  bool get hasServerConfigured {
    if (kIsWeb) {
      return webServerUrl.trim().isNotEmpty;
    }
    return servers.isNotEmpty;
  }

  ServerConfig? get activeServer {
    if (kIsWeb || servers.isEmpty) {
      return null;
    }
    final index = activeServerIndex.clamp(0, servers.length - 1);
    return servers[index];
  }

  String get activeBaseUrl {
    if (kIsWeb) {
      return webServerUrl.trim();
    }
    return activeServer?.baseUrl.trim() ?? '';
  }

  List<Album> get albums {
    final map = <int, Album>{};
    for (final track in tracks) {
      map[track.album.id] = track.album;
    }
    final result = map.values.toList();
    result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return result;
  }

  List<Artist> get artists {
    final map = <int, Artist>{};
    for (final artist in primaryArtists) {
      map[artist.id] = artist;
    }
    for (final artist in appearsOnArtists) {
      map[artist.id] = artist;
    }
    final result = map.values.toList();
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    seedColorValue = prefs.getInt(_seedColorKey) ?? 0xFF6D4AFF;
    darkMode = prefs.getBool(_darkModeKey) ?? true;
    volume = (prefs.getDouble(_volumeKey) ?? 1.0).clamp(0.0, 1.0);

    if (kIsWeb) {
      final savedWebServerUrl = prefs.getString(_webServerKey)?.trim();
      if (savedWebServerUrl == null ||
          savedWebServerUrl.isEmpty ||
          savedWebServerUrl == _legacyWebServerUrl) {
        webServerUrl = _defaultWebServerUrl();
      } else {
        webServerUrl = savedWebServerUrl;
      }
    } else {
      final rawServers = prefs.getString(_serversKey);
      if (rawServers != null && rawServers.isNotEmpty) {
        final decoded = jsonDecode(rawServers) as List<dynamic>;
        servers = decoded
            .whereType<Map<String, dynamic>>()
            .map(ServerConfig.fromJson)
            .toList();
      }
      activeServerIndex = prefs.getInt(_activeServerIndexKey) ?? 0;
    }

    _wireAudioListeners();
    await audioPlayer.setVolume(volume);
    isBooting = false;
    notifyListeners();
    await refreshAll();
  }

  void _wireAudioListeners() {
    audioPlayer.playerStateStream.listen((_) {
      notifyListeners();
    });

    audioPlayer.currentIndexStream.listen((index) {
      if (index != null) {
        queueIndex = index;
        notifyListeners();
      }
    });
  }

  Future<void> refreshAll() async {
    if (!hasServerConfigured) {
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      _api = OpenStreamApi(baseUrl: activeBaseUrl);
      await _api!.healthCheck();
      tracks = await _api!.getTracks();
      playlists = await _api!.getPlaylists();
      final artistSections = await _api!.getArtists();
      primaryArtists = artistSections.primary;
      appearsOnArtists = artistSections.appearsOn;

      if (primaryArtists.isEmpty && appearsOnArtists.isEmpty) {
        _deriveArtistsFromTracks();
      }

      await _enrichTracksWithArtistSearch();

      if (queue.isEmpty && tracks.isNotEmpty) {
        queue = List<Track>.from(tracks);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    if (_api == null) {
      return;
    }

    if (query.trim().isEmpty) {
      await refreshAll();
      return;
    }

    isLoading = true;
    notifyListeners();

    try {
      tracks = await _api!.getTracks(search: query.trim());
      final artistSections = await _api!.getArtists(search: query.trim());
      primaryArtists = artistSections.primary;
      appearsOnArtists = artistSections.appearsOn;
      if (primaryArtists.isEmpty && appearsOnArtists.isEmpty) {
        _deriveArtistsFromTracks();
      }
      await _enrichTracksWithArtistSearch();
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _deriveArtistsFromTracks() {
    final map = <int, Artist>{};
    for (final track in tracks) {
      if (track.artists.isNotEmpty) {
        for (final artist in track.artists) {
          map[artist.id] = artist;
        }
        continue;
      }
      if (track.album.artists.isNotEmpty) {
        for (final artist in track.album.artists) {
          map[artist.id] = artist;
        }
        continue;
      }
      map[track.album.artist.id] = track.album.artist;
    }

    primaryArtists = map.values
        .map(
          (artist) => Artist(
            id: artist.id,
            name: artist.name,
            primaryAlbumCount: 0,
            trackAppearanceCount: 0,
          ),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    appearsOnArtists = <Artist>[];
  }

  Future<void> _enrichTracksWithArtistSearch() async {
    if (_api == null || tracks.isEmpty || appearsOnArtists.isEmpty) {
      return;
    }

    final artistNames = appearsOnArtists
        .where((artist) => artist.trackAppearanceCount > 0)
        .map((artist) => artist.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    if (artistNames.isEmpty) {
      return;
    }

    final artistsByTrackId = <String, List<Artist>>{};
    for (final artistName in artistNames) {
      final matches = await _api!.getTracks(search: artistName);
      for (final track in matches) {
        if (track.artists.isNotEmpty) {
          artistsByTrackId[track.id] = track.artists;
        }
      }
    }

    if (artistsByTrackId.isEmpty) {
      return;
    }

    tracks = tracks.map((track) {
      final overrideArtists = artistsByTrackId[track.id];
      if (overrideArtists == null || overrideArtists.isEmpty) {
        return track;
      }
      return Track(
        id: track.id,
        title: track.title,
        path: track.path,
        duration: track.duration,
        trackNumber: track.trackNumber,
        album: track.album,
        artists: overrideArtists,
      );
    }).toList();
  }

  Future<void> setSeedColor(int color) async {
    seedColorValue = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedColorKey, color);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
    notifyListeners();
  }

  Future<void> setWebServer(String url) async {
    webServerUrl = url.isEmpty ? _defaultWebServerUrl() : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_webServerKey, webServerUrl);
    await refreshAll();
  }

  Future<void> addServer(ServerConfig server) async {
    servers = <ServerConfig>[...servers, server];
    activeServerIndex = servers.length - 1;
    await _saveServers();
    await refreshAll();
  }

  Future<void> removeServer(int index) async {
    if (index < 0 || index >= servers.length) {
      return;
    }

    servers.removeAt(index);
    if (servers.isEmpty) {
      activeServerIndex = 0;
    } else {
      activeServerIndex = activeServerIndex.clamp(0, servers.length - 1);
    }

    await _saveServers();
    await refreshAll();
  }

  Future<void> switchServer(int index) async {
    if (index < 0 || index >= servers.length) {
      return;
    }
    activeServerIndex = index;
    await _saveServers();
    await refreshAll();
  }

  Future<void> _saveServers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _serversKey,
      jsonEncode(servers.map((server) => server.toJson()).toList()),
    );
    await prefs.setInt(_activeServerIndexKey, activeServerIndex);
    notifyListeners();
  }

  Future<void> playTracks(List<Track> tracksToPlay, {int startIndex = 0}) async {
    if (_api == null || tracksToPlay.isEmpty) {
      return;
    }

    await _runAudioAction(() async {
      queue = List<Track>.from(tracksToPlay);
      final sources = queue
          .map((track) => AudioSource.uri(Uri.parse(_api!.streamUrl(track.id))))
          .toList();
      await audioPlayer.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: startIndex.clamp(0, queue.length - 1),
        initialPosition: Duration.zero,
      );
      queueIndex = startIndex;
      await audioPlayer.play();
      notifyListeners();
    });
  }

  Future<void> togglePlayPause() async {
    await _runAudioAction(() async {
      if (audioPlayer.playing) {
        await audioPlayer.pause();
      } else {
        await audioPlayer.play();
      }
    });
  }

  Future<void> nextTrack() async {
    await _runAudioAction(() async {
      if (shuffleEnabled) {
        if (queue.isEmpty) {
          return;
        }
        final next = DateTime.now().millisecondsSinceEpoch % queue.length;
        await audioPlayer.seek(Duration.zero, index: next);
        return;
      }
      await audioPlayer.seekToNext();
    });
  }

  Future<void> previousTrack() async {
    await _runAudioAction(() => audioPlayer.seekToPrevious());
  }

  Future<void> seek(Duration position) async {
    await _runAudioAction(() => audioPlayer.seek(position));
  }

  Future<void> setVolume(double value) async {
    final next = value.clamp(0.0, 1.0);
    volume = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, next);
    await _runAudioAction(() => audioPlayer.setVolume(next));
    notifyListeners();
  }

  Future<void> setShuffle(bool enabled) async {
    shuffleEnabled = enabled;
    notifyListeners();
  }

  Future<void> setLoop(bool enabled) async {
    loopEnabled = enabled;
    await _runAudioAction(
      () => audioPlayer.setLoopMode(enabled ? LoopMode.one : LoopMode.off),
    );
    notifyListeners();
  }

  Future<void> _runAudioAction(Future<void> Function() action) async {
    try {
      await action();
    } on MissingPluginException {
      error =
          'Audio playback plugin is unavailable on this platform/build. Do a full restart after `flutter pub get`, or add desktop playback support if needed.';
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> uploadTrack() async {
    if (_api == null) {
      return;
    }

    final file = await openFile();
    if (file == null) {
      return;
    }

    final bytes = await file.readAsBytes();
    await _api!.uploadTrack(bytes, file.name);

    await refreshAll();
  }

  Future<void> rescanLibrary() async {
    if (_api == null) {
      return;
    }

    await _api!.rescanLibrary();
    await refreshAll();
  }

  Future<void> updateTrack({
    required String id,
    required String title,
    required String albumTitle,
    required String artistName,
    String? albumArtistNames,
  }) async {
    if (_api == null) {
      return;
    }

    final parsedTrackArtists = artistName
        .split(RegExp(r'\s*[,;|/]\s*'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    final parsedAlbumArtists = (albumArtistNames ?? '')
        .split(RegExp(r'\s*[,;|/]\s*'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    await _api!.updateTrack(
      id: id,
      title: title,
      albumTitle: albumTitle,
      artistName: artistName,
      artistNames: parsedTrackArtists,
      albumArtistNames:
          parsedAlbumArtists.isEmpty ? parsedTrackArtists : parsedAlbumArtists,
    );
    await refreshAll();
  }

  Future<void> deleteTrack(String id, {required bool deleteFile}) async {
    if (_api == null) {
      return;
    }

    await _api!.deleteTrack(id, deleteFile: deleteFile);
    await refreshAll();
  }

  Future<void> createPlaylist({
    required String name,
    required List<String> trackIds,
  }) async {
    if (_api == null) {
      return;
    }

    await _api!.createPlaylist(name: name, trackIds: trackIds);
    await refreshAll();
  }

  Future<void> uploadAlbumArt(int albumId) async {
    if (_api == null) {
      return;
    }

    const typeGroup = XTypeGroup(
      label: 'JPEG image',
      extensions: <String>['jpg', 'jpeg'],
    );
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[typeGroup],
    );
    if (file == null) {
      return;
    }

    final bytes = await file.readAsBytes();

    await _api!.uploadAlbumArt(
      albumId: albumId,
      bytes: bytes,
      filename: file.name,
    );
    await refreshAll();
  }


  String trackStreamUrl(String trackId) => _api?.streamUrl(trackId) ?? '';

  String albumArtUrl(String? artPath) => _api?.albumArtUrl(artPath) ?? '';

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}


