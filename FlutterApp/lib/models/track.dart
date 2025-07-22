import 'album.dart';

class Track {
  static const className = "Track";

  String id = "";
  String title = "Unknown Track";
  String path = "";
  Duration? duration;
  int? trackNumber;
  int? albumId;
  DateTime? dateAdded;
  Album? album;

  void initFromJson(Map<String, dynamic>? src) {
    if (src == null) return;
    id = src['id'];
    title = src['title'];
    path = src['path'];
    duration = src['duration'];
    trackNumber = src['trackNumber'];
    albumId = src['albumId'];
    dateAdded = src['dateAdded'];
    album = Album.fromJson(src['album']);
  }

  static Track? fromJson(Map<String, dynamic>? src) {
    if (src == null) return null;
    var entity = Track();
    entity.initFromJson(src);
    return entity;
  }

}
