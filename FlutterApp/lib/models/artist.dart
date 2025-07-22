import 'album.dart';

class Artist {
  static const className = "Artist";

  String id = "";
  String name = "Unknown Artist";
  List<Album>? albums;

  void initFromJson(Map<String, dynamic>? src) {
    if (src == null) return;
    id = src['id'];
    name = src['name'];
    albums = src['albums']?.map((e) => Album.fromJson(e)).toList();
  }

  static Artist? fromJson(Map<String, dynamic>? src) {
    if (src == null) return null;
    var entity = Artist();
    entity.initFromJson(src);
    return entity;
  }

}
