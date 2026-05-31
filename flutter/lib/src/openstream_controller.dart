import 'dart:async';
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
const _shuffleEnabledKey = 'openstream.shuffleEnabled';
const _loopEnabledKey = 'openstream.loopEnabled';
const _playbackSessionKey = 'openstream.playbackSession';
const _legacyWebServerUrl = 'http://localhost:9090';

String _defaultWebServerUrl() {
  final uri = Uri.base;
  // file:// URIs don't have an origin, return default for desktop/non-web
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return _legacyWebServerUrl;
  }
  final origin = uri.origin.trim();
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

  List<String> _restoredQueueTrackIds = <String>[];
  String? _restoredSelectedTrackId;
  int _restoredPositionMs = 0;
  bool _hasPendingPlaybackRestore = false;
  bool _isRestoringPlaybackSession = false;
  int _lastSavedPositionMs = 0;

  bool get isRestoringPlaybackSession => _isRestoringPlaybackSession;

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
    result.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
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
    shuffleEnabled = prefs.getBool(_shuffleEnabledKey) ?? false;
    loopEnabled = prefs.getBool(_loopEnabledKey) ?? false;
    _loadSavedPlaybackSession(prefs);

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
    await audioPlayer.setLoopMode(loopEnabled ? LoopMode.one : LoopMode.off);
    isBooting = false;
    notifyListeners();
    await refreshAll();
  }

  void _loadSavedPlaybackSession(SharedPreferences prefs) {
    final rawSession = prefs.getString(_playbackSessionKey);
    if (rawSession == null || rawSession.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawSession);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final queueIds = decoded['queueTrackIds'];
      if (queueIds is List<dynamic>) {
        _restoredQueueTrackIds = queueIds
            .whereType<String>()
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toList();
      }

      final selectedTrackId = decoded['selectedTrackId'];
      if (selectedTrackId is String && selectedTrackId.trim().isNotEmpty) {
        _restoredSelectedTrackId = selectedTrackId.trim();
      }

      final positionMs = decoded['positionMs'];
      if (positionMs is num) {
        _restoredPositionMs = positionMs.toInt().clamp(0, 1 << 31);
      }

      _hasPendingPlaybackRestore =
          _restoredQueueTrackIds.isNotEmpty || _restoredSelectedTrackId != null;
    } catch (_) {
      _restoredQueueTrackIds = <String>[];
      _restoredSelectedTrackId = null;
      _restoredPositionMs = 0;
      _hasPendingPlaybackRestore = false;
    }
  }

  void _wireAudioListeners() {
    audioPlayer.playerStateStream.listen((_) {
      unawaited(_savePlaybackSession());
      notifyListeners();
    });

    audioPlayer.currentIndexStream.listen((index) {
      if (index != null) {
        queueIndex = index;
        unawaited(_savePlaybackSession());
        notifyListeners();
      }
    });

    audioPlayer.positionStream.listen((position) {
      final positionMs = position.inMilliseconds;
      if ((positionMs - _lastSavedPositionMs).abs() < 2000) {
        return;
      }
      _lastSavedPositionMs = positionMs;
      unawaited(_savePlaybackSession());
    });
  }

  Future<void> refreshAll() async {
    if (!hasServerConfigured) {
      return;
    }

    isLoading = true;
    _isRestoringPlaybackSession = _hasPendingPlaybackRestore;
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

      await _restorePlaybackSession();

      if (queue.isEmpty && tracks.isNotEmpty) {
        queue = List<Track>.from(tracks);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      _isRestoringPlaybackSession = false;
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

    primaryArtists =
        map.values
            .map(
              (artist) => Artist(
                id: artist.id,
                name: artist.name,
                primaryAlbumCount: 0,
                trackAppearanceCount: 0,
              ),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
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

  Future<void> playTracks(
    List<Track> tracksToPlay, {
    int startIndex = 0,
  }) async {
    if (_api == null || tracksToPlay.isEmpty) {
      return;
    }

    await _runAudioAction(() async {
      queue = List<Track>.from(tracksToPlay);
      final initialIndex = startIndex.clamp(0, queue.length - 1);
      final sources = queue
          .map((track) => AudioSource.uri(Uri.parse(_api!.streamUrl(track.id))))
          .toList();
      await audioPlayer.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: initialIndex,
        initialPosition: Duration.zero,
      );
      queueIndex = initialIndex;
      await audioPlayer.play();
      await _savePlaybackSession();
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
    await _runAudioAction(() async {
      await audioPlayer.seek(position);
      await _savePlaybackSession();
    });
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shuffleEnabledKey, enabled);
    await _savePlaybackSession();
    notifyListeners();
  }

  Future<void> setLoop(bool enabled) async {
    loopEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loopEnabledKey, enabled);
    await _runAudioAction(
      () => audioPlayer.setLoopMode(enabled ? LoopMode.one : LoopMode.off),
    );
    await _savePlaybackSession();
    notifyListeners();
  }

  Future<void> _restorePlaybackSession() async {
    if (!_hasPendingPlaybackRestore || _api == null || tracks.isEmpty) {
      return;
    }

    final tracksById = <String, Track>{
      for (final track in tracks) track.id: track,
    };

    final restoredQueue = _restoredQueueTrackIds
        .map((id) => tracksById[id])
        .whereType<Track>()
        .toList();

    if (restoredQueue.isEmpty) {
      _hasPendingPlaybackRestore = false;
      return;
    }

    var selectedIndex = 0;
    if (_restoredSelectedTrackId != null) {
      final match = restoredQueue.indexWhere(
        (track) => track.id == _restoredSelectedTrackId,
      );
      if (match >= 0) {
        selectedIndex = match;
      }
    }

    await _runAudioAction(() async {
      queue = restoredQueue;
      final sources = queue
          .map((track) => AudioSource.uri(Uri.parse(_api!.streamUrl(track.id))))
          .toList();

      await audioPlayer.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: selectedIndex,
        initialPosition: Duration(milliseconds: _restoredPositionMs),
      );
      queueIndex = selectedIndex;
      await audioPlayer.pause();
      await _savePlaybackSession();
    });

    _hasPendingPlaybackRestore = false;
    notifyListeners();
  }

  Future<void> _savePlaybackSession() async {
    final prefs = await SharedPreferences.getInstance();
    final currentIndex = audioPlayer.currentIndex;
    final selectedTrackId =
        currentIndex != null && currentIndex >= 0 && currentIndex < queue.length
        ? queue[currentIndex].id
        : (queueIndex >= 0 && queueIndex < queue.length
              ? queue[queueIndex].id
              : null);

    final payload = <String, dynamic>{
      'queueTrackIds': queue.map((track) => track.id).toList(),
      'selectedTrackId': selectedTrackId,
      'positionMs': audioPlayer.position.inMilliseconds,
    };

    await prefs.setString(_playbackSessionKey, jsonEncode(payload));
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
      albumArtistNames: parsedAlbumArtists.isEmpty
          ? parsedTrackArtists
          : parsedAlbumArtists,
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

  Future<void> addTrackToPlaylist({
    required int playlistId,
    required String trackId,
  }) async {
    if (_api == null) {
      return;
    }

    try {
      await _api!.addTrackToPlaylist(playlistId: playlistId, trackId: trackId);
      await refreshAll();
    } catch (e) {
      _setPlaylistApiError(
        e,
        compatibilityMessage:
            'This server does not support adding tracks to playlists yet. Update the server to use this feature.',
      );
    }
  }

  Future<void> updatePlaylist({
    required int playlistId,
    required String name,
  }) async {
    if (_api == null) {
      return;
    }

    try {
      await _api!.updatePlaylist(playlistId: playlistId, name: name);
      await refreshAll();
    } catch (e) {
      _setPlaylistApiError(
        e,
        compatibilityMessage:
            'This server does not support playlist editing yet. Update the server to use this feature.',
      );
    }
  }

  Future<void> deletePlaylist(int playlistId) async {
    if (_api == null) {
      return;
    }

    try {
      await _api!.deletePlaylist(playlistId);
      await refreshAll();
    } catch (e) {
      _setPlaylistApiError(
        e,
        compatibilityMessage:
            'This server does not support playlist deletion yet. Update the server to use this feature.',
      );
    }
  }

  void _setPlaylistApiError(
    Object errorValue, {
    required String compatibilityMessage,
  }) {
    final raw = errorValue.toString();
    final isCompatibilityFailure = raw.contains('(404)') || raw.contains('(405)');
    error = isCompatibilityFailure ? compatibilityMessage : raw;
    notifyListeners();
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
    unawaited(_savePlaybackSession());
    audioPlayer.dispose();
    super.dispose();
  }
}
