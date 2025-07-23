import 'artist.dart';

class Album {
  final int id;
  final String title;
  final int? year;
  final Artist? artist;

  Album({
    required this.id,
    required this.title,
    this.year,
    this.artist,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as int,
      title: json['title'] as String,
      year: json['year'] as int?,
      artist:
          json['artist'] != null ? Artist.fromJson(json['artist']) : null,
    );
  }
}
