import 'package:flutter_test/flutter_test.dart';
import 'package:openstream_flutter/src/models.dart';

void main() {
  test('Track parsing handles nested album/artist data', () {
    final track = Track.fromJson({
      'id': 'abc123',
      'title': 'Song',
      'path': '/music/song.mp3',
      'duration': 180000,
      'trackNumber': 1,
      'album': {
        'id': 10,
        'title': 'Album',
        'albumArtPath': 'cover.jpg',
        'artist': {'id': 99, 'name': 'Artist'},
        'artists': [
          {'id': 99, 'name': 'Artist'},
          {'id': 100, 'name': 'Guest Artist'},
        ],
      },
      'artists': [
        {'id': 99, 'name': 'Artist'},
        {'id': 100, 'name': 'Guest Artist'},
      ],
    });

    expect(track.id, 'abc123');
    expect(track.album.title, 'Album');
    expect(track.artistName, 'Artist, Guest Artist');
    expect(track.album.displayArtistNames, 'Artist, Guest Artist');
  });
}
