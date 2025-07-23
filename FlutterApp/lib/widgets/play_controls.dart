import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import '../models/track.dart';
import '../main.dart';

class PlayControls extends StatelessWidget {
  final AudioPlayer player;
  final Track currentTrack;
  final Stream<PositionData> positionDataStream;
  final VoidCallback onPause;
  final VoidCallback onPlay;
  final Function(Duration) onSeek;

  const PlayControls({
    Key? key,
    required this.player,
    required this.currentTrack,
    required this.positionDataStream,
    required this.onPause,
    required this.onPlay,
    required this.onSeek,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          StreamBuilder<PositionData>(
            stream: positionDataStream,
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
                      onSeek(Duration(milliseconds: value.round()));
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
                            final text = "${currentTrack.title} - ${currentTrack.album?.artist?.name ?? 'Unknown Artist'} - ${currentTrack.album?.title ?? 'Unknown Album'}";
                            const style = TextStyle(fontWeight: FontWeight.bold);
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
                stream: player.playingStream,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    iconSize: 64.0,
                    onPressed: () {
                      if (isPlaying) {
                        onPause();
                      } else {
                        onPlay();
                      }
                    },
                  );
                },
              ),
            ],
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
