import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:rxdart/rxdart.dart';
import 'services/api_service.dart';
import 'models/track.dart';
import 'config.dart';

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
  final ApiService _apiService = ApiService();
  late Future<List<Track>> _tracksFuture;
  late Stream<PositionData> _positionDataStream;
  late Track _currentTrack = Track(id: '', title: '', duration: Duration.zero);
  double _volume = 1.0;

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
    try {
      final url = "$baseUrl/api/tracks/${track.id}/stream";
      _currentTrack = track;
      await _player.setUrl(url);
      _player.play();
      setState(() {});
    } catch (e) {
      debugPrint("Error loading audio source: $e");
    }
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
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  StreamBuilder<PositionData>(
                    stream: _positionDataStream,
                    builder: (context, snapshot) {
                      final positionData = snapshot.data;
                      final position = positionData?.position ?? Duration.zero;
                      final duration = positionData?.duration ?? Duration.zero;
                      return Column(
                        children: [
                          Slider(
                            value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                            max: duration.inMilliseconds.toDouble(),
                            onChanged: (value) {
                              _seek(Duration(milliseconds: value.round()));
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(position)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final text = "${_currentTrack.title} - ${_currentTrack.album?.artist?.name ?? 'Unknown Artist'} - ${_currentTrack.album?.title ?? 'Unknown Album'}";
                                    final style = const TextStyle(fontWeight: FontWeight.bold);
                                    final span = TextSpan(text: text, style: style);
                                    final painter = TextPainter(text: span, maxLines: 1, textDirection: TextDirection.ltr);
                                    painter.layout();

                                    if (painter.width > constraints.maxWidth) {
                                      return SizedBox(
                                        height: 20.0,
                                        child: Marquee(
                                          text: text,
                                          style: style,
                                          scrollAxis: Axis.horizontal,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          blankSpace: 40.0,
                                          velocity: 10.0,
                                        ),
                                      );
                                    } else {
                                      return Text(text, style: style, textAlign: TextAlign.center,);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(_formatDuration(duration)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StreamBuilder<bool>(
                        stream: _player.playingStream,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data ?? false;
                          return IconButton(
                            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                            iconSize: 64.0,
                            onPressed: () {
                              if (isPlaying) {
                                _pause();
                              } else {
                                _player.play();
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
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
