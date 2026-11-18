import 'dart:math';
import 'dart:typed_data';

import 'package:echodrop/core/modem_decoder.dart';
import 'package:echodrop/core/modem_encoder.dart';
import 'package:echodrop/core/packet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('text survives encode → noisy audio → decode', () {
    final msg = EchoMessage.text('Hello EchoDrop! https://github.com/flutter/flutter');
    final frames = PacketCodec.split(msg.encode(), 42);
    final pcm = ModemEncoder.buildPcm(frames);

    final rnd = Random(1);
    const offset = 7777; // arbitrary start delay
    final noisy = Int16List(pcm.length + 20000);
    for (var i = 0; i < noisy.length; i++) {
      final s = (i >= offset && i - offset < pcm.length) ? pcm[i - offset] : 0;
      final v = s * 0.3 + (rnd.nextDouble() - 0.5) * 1500;
      noisy[i] = v.round().clamp(-32768, 32767).toInt();
    }

    final asm = Reassembler();
    ModemDecoder(onFrame: asm.add).addSamples(noisy);

    expect(asm.isComplete, isTrue);
    expect(EchoMessage.decode(asm.assemble()!)!.text, msg.text);
  });
}