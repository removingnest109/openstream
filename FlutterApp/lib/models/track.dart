import 'dart:convert';
import 'package:http/http.dart' as http;
import 'album.dart';

class Track {
  final String id;
  final String title;
  final Duration duration;
  final Album? album;

  Track({
    required this.id,
    required this.title,
    required this.duration,
    this.album,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      title: json['title'] as String,
      duration: _parseDuration(json['duration'] as String),
      album: json['album'] != null ? Album.fromJson(json['album']) : null,
    );
  }
}

Duration _parseDuration(String s) {
  int days = 0;
  int hours = 0;
  int minutes = 0;
  int seconds = 0;
  List<String> parts = s.split(':');
  if (parts.length == 3) {
    List<String> dayParts = parts[0].split('.');
    if (dayParts.length == 2) {
      days = int.parse(dayParts[0]);
      hours = int.parse(dayParts[1]);
    } else {
      hours = int.parse(parts[0]);
    }
    minutes = int.parse(parts[1]);
    seconds = int.parse(parts[2].split('.')[0]);
  }

  return Duration(
    days: days,
    hours: hours,
    minutes: minutes,
    seconds: seconds,
  );
}
