import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/track.dart';

class ApiService {
  Future<List<Track>> getTracks() async {
    final response = await http.get(Uri.parse('$baseUrl/api/tracks'));

    if (response.statusCode == 200) {
      List<dynamic> jsonResponse = json.decode(response.body);
      return jsonResponse.map((track) => Track.fromJson(track)).toList();
    } else {
      throw Exception('Failed to load tracks');
    }
  }
}
