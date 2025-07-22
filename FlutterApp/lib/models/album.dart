import 'track.dart';
import 'artist.dart';

class Album {
  static const className = "Album";

  String id = "";
  String title = "Unknown Album";
  int? artistId;
  int? year;
  Artist? artist;
  List<Track>? tracks;

  void initFromJson(Map<String, dynamic>? src) {
    if (src == null) return;
    id = src['id'];
    title = src['title'];
    artistId = src['artistId'];
    year = src['year'];
    tracks = src['tracks']?.map((e) => Track.fromJson(e)).toList();
    artist = Artist.fromJson(src['artist']);
  }

  static Album? fromJson(Map<String, dynamic>? src) {
    if (src == null) return null;
    var entity = Album();
    entity.initFromJson(src);
    return entity;
  }

}
