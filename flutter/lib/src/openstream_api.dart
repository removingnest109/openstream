import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class OpenStreamApi {
  OpenStreamApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalizedBase$path').replace(queryParameters: query);
  }

  String streamUrl(String trackId) =>
      _uri('/api/tracks/$trackId/stream').toString();

  String albumArtUrl(String? artPath) {
    if (artPath == null || artPath.isEmpty) {
      return '';
    }

    final normalized = artPath.trim();
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }
    if (normalized.startsWith('/api/albumart/')) {
      return _uri(normalized).toString();
    }
    if (normalized.startsWith('api/albumart/')) {
      return _uri('/$normalized').toString();
    }
    return _uri('/api/albumart/$normalized').toString();
  }

  Future<void> healthCheck() async {
    final response = await _client.get(_uri('/health'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Health check failed (${response.statusCode})');
    }
  }

  Future<List<Track>> getTracks({String? search}) async {
    final query = search != null && search.trim().isNotEmpty
        ? <String, String>{'search': search.trim()}
        : null;
    final response = await _client.get(_uri('/api/tracks', query));
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Track.fromJson)
        .toList();
  }

  Future<ArtistSections> getArtists({String? search}) async {
    final query = search != null && search.trim().isNotEmpty
        ? <String, String>{'search': search.trim()}
        : null;
    final response = await _client.get(_uri('/api/artists', query));
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return ArtistSections.fromJson(decoded);
    }

    // Backward compatibility if server returns a flat array.
    if (decoded is List<dynamic>) {
      final primary = decoded
          .whereType<Map<String, dynamic>>()
          .map(Artist.fromJson)
          .toList();
      return ArtistSections(primary: primary, appearsOn: const <Artist>[]);
    }

    return ArtistSections(
      primary: const <Artist>[],
      appearsOn: const <Artist>[],
    );
  }

  Future<List<Playlist>> getPlaylists() async {
    final response = await _client.get(_uri('/api/playlists'));
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body) as List<dynamic>;
    final playlists = decoded
        .whereType<Map<String, dynamic>>()
        .map(Playlist.fromJson)
        .toList();

    // Ensure each playlist has full track data by hydrating individual calls.
    final hydrated = <Playlist>[];
    for (final playlist in playlists) {
      hydrated.add(await getPlaylistById(playlist.id));
    }
    return hydrated;
  }

  Future<Playlist> getPlaylistById(int id) async {
    final response = await _client.get(_uri('/api/playlists/$id'));
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return Playlist.fromJson(decoded);
  }

  Future<void> rescanLibrary() async {
    final response = await _client.post(_uri('/api/ingestion/scan'));
    _ensureSuccess(response);
  }

  Future<void> uploadTrack(List<int> bytes, String filename) async {
    final request = http.MultipartRequest('POST', _uri('/api/tracks/upload'));
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    final streamed = await request.send();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Upload failed (${streamed.statusCode})');
    }
  }

  Future<void> updateTrack({
    required String id,
    required String title,
    required String albumTitle,
    required String artistName,
    List<String> artistNames = const <String>[],
    List<String> albumArtistNames = const <String>[],
  }) async {
    final normalizedArtistNames = artistNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    final normalizedAlbumArtistNames = albumArtistNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    final response = await _client.put(
      _uri('/api/tracks/$id'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'albumTitle': albumTitle,
        'artistName': artistName,
        'artistNames': normalizedArtistNames,
        'albumArtistNames': normalizedAlbumArtistNames,
      }),
    );
    _ensureSuccess(response);
  }

  Future<void> deleteTrack(String id, {required bool deleteFile}) async {
    final response = await _client.delete(
      _uri('/api/tracks/$id', <String, String>{
        'deleteFile': deleteFile.toString(),
      }),
    );
    _ensureSuccess(response);
  }

  Future<Playlist> createPlaylist({
    required String name,
    required List<String> trackIds,
  }) async {
    final response = await _client.post(
      _uri('/api/playlists'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{'name': name, 'trackIds': trackIds}),
    );
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final id = (decoded['id'] as num?)?.toInt() ?? 0;
    return getPlaylistById(id);
  }

  Future<void> uploadAlbumArt({
    required int albumId,
    required List<int> bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/albums/$albumId/art'),
    );
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    final streamed = await request.send();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Album art upload failed (${streamed.statusCode})');
    }
  }

  static void _ensureSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Request failed (${response.statusCode}): ${response.body}',
      );
    }
  }
}
