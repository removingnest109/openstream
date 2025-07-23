
class Artist {
  final int id;
  final String name;

  Artist({required this.id, required this.name});

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}
