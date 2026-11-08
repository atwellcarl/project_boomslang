import 'package:audioplayers/audioplayers.dart';

/// Hit/miss sounds, each on its own preloaded player.
///
/// Swapping one player between the two files rebuilds the audio element on
/// web before it can play, and iOS Safari only allows playback close to the
/// tap that triggered it. With a fixed source per player, a play is just a
/// rewind and start, which is also lower latency on native.
class SoundFx {
  final _hit = AudioPlayer();
  final _miss = AudioPlayer();

  SoundFx() {
    _hit
      ..setReleaseMode(ReleaseMode.stop)
      ..setSource(AssetSource('sounds/hit.wav'));
    _miss
      ..setReleaseMode(ReleaseMode.stop)
      ..setSource(AssetSource('sounds/miss.wav'));
  }

  void play(bool isHit) {
    final player = isHit ? _hit : _miss;
    player.seek(Duration.zero);
    player.resume();
  }

  void dispose() {
    _hit.dispose();
    _miss.dispose();
  }
}
