import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Openstream Player',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Openstream Player'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  double _volume = 1.0;
  final String _testUrl = "http://10.0.2.2:5000/api/tracks/fa1703a9-702d-43a1-b9aa-61f378ae8d68/stream";

  void _play() async {
    try {
      await _player.setUrl(_testUrl);
      _player.play();
      setState(() {
        _isPlaying = true;
      });
    } catch (e) {
      print("Error loading audio source: $e, url: $_testUrl");
    }
  }

  void _pause() {
    _player.pause();
    setState(() {
      _isPlaying = false;
    });
  }

  void _setVolume(double volume) {
    _player.setVolume(volume);
    setState(() {
      _volume = volume;
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              iconSize: 64.0,
              onPressed: _isPlaying ? _pause : _play,
            ),
            Slider(
              value: _volume,
              onChanged: _setVolume,
            ),
          ],
        ),
      ),
    );
  }
}
