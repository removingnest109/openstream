import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'services/api_service.dart';
import 'models/track.dart';
import 'config.dart';
import 'widgets/play_controls.dart';

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
  final AudioPlayer _player = AudioPlayer(
    handleInterruptions: true,
    androidApplyAudioAttributes: true,
    handleAudioSessionActivation: true,
  );
  final ApiService _apiService = ApiService();
  late Future<List<Track>> _tracksFuture;
  late Stream<PositionData> _positionDataStream;
  late Track _currentTrack = Track(id: '', title: '', duration: Duration.zero);
  final double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _tracksFuture = _apiService.getTracks();
    _positionDataStream = Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
      _player.positionStream,
      _player.bufferedPositionStream,
      _player.durationStream,
      (position, bufferedPosition, duration) => PositionData(
        position,
        bufferedPosition,
        duration ?? Duration.zero,
      ),
    );
  }

  void _play(Track track) async {
    debugPrint("Playing track: ${track.title}");
    try {
      await _player.stop();
      final url = "$baseUrl/api/tracks/${track.id}/stream";
      _currentTrack = track;

      await _player.setAudioSource(
        LockCachingAudioSource(
          Uri.parse(url),
          headers: {"User-Agent": "Openstream Player"},
        ),
      );

      setState(() {});
      _player.play();
    } catch (e) {
      debugPrint("Error loading audio source: $e");
      _player.setAudioSource(AudioSource.uri(Uri.parse("")));
    }
  }

  void _refetch() {
    setState(() {
      _tracksFuture = _apiService.getTracks();
    });
  }

  void _pause() {
    _player.pause();
  }

  void _seek(Duration position) {
    _player.seek(position);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refetch,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Track>>(
              future: _tracksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No tracks found.'));
                }

                final tracks = snapshot.data!;
                return ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    return ListTile(
                      title: Text(track.title),
                      subtitle: Text(track.album?.artist?.name ?? 'Unknown Artist'),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => _play(track),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_currentTrack.title.isNotEmpty)
            PlayControls(
              player: _player,
              currentTrack: _currentTrack,
              positionDataStream: _positionDataStream,
              onPause: _pause,
              onPlay: () => _player.play(),
              onSeek: _seek,
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}
