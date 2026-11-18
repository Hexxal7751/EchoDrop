import 'dart:isolate';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

import '../core/constants.dart';
import '../core/modem_encoder.dart';
import '../core/packet.dart';

class SendInfo {
  const SendInfo(this.frames, this.pass);
  final int frames;
  final Duration pass;
}

class SendService {
  final AudioPlayer _player = AudioPlayer();

  static int framesFor(int wireBytes) =>
      (wireBytes + Sonic.payloadBytes - 1) ~/ Sonic.payloadBytes;

  /// Encodes the message and loops it through the speaker until [stop].
  Future<SendInfo> start(EchoMessage msg) async {
    final wire = msg.encode();
    if (wire.length > Sonic.maxMessageBytes) {
      throw FormatException(
        'Too large (${wire.length} B). Sound mode supports about ${Sonic.maxMessageBytes} B.',
      );
    }
    final frames = PacketCodec.split(wire, Random.secure().nextInt(256));
    final wav = await Isolate.run(() => ModemEncoder.buildWav(frames));
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(1.0);
    await _player.play(BytesSource(wav));
    return SendInfo(frames.length, ModemEncoder.passDuration(frames.length));
  }

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}