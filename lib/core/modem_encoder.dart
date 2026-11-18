import 'dart:math';
import 'dart:typed_data';

import 'constants.dart';

class ModemEncoder {
  ModemEncoder._();

  static const double _amp = 0.9;
  static const int _ramp = 220; // 5 ms fade in/out per tone, avoids clicks

  static Duration passDuration(int frames) => Duration(
        milliseconds: frames * (Sonic.frameSymbols * Sonic.symbolMs + Sonic.gapMs),
      );

  /// All frames back to back: [head][body][gap] x N
  static Int16List buildPcm(List<Uint8List> bodies) {
    final gap = Sonic.sampleRate * Sonic.gapMs ~/ 1000;
    final perFrame = Sonic.frameSymbols * Sonic.symbolSamples + gap;
    final out = Int16List(perFrame * bodies.length);
    var pos = 0;
    for (final body in bodies) {
      for (final s in Sonic.head) {
        _symbol(out, pos, s);
        pos += Sonic.symbolSamples;
      }
      for (final b in body) {
        _symbol(out, pos, b >> 4);
        pos += Sonic.symbolSamples;
        _symbol(out, pos, b & 0x0F);
        pos += Sonic.symbolSamples;
      }
      pos += gap;
    }
    return out;
  }

  static Uint8List buildWav(List<Uint8List> bodies) => toWav(buildPcm(bodies));

  static void _symbol(Int16List out, int offset, int tone) {
    final w = 2 * pi * Sonic.toneFreq(tone) / Sonic.sampleRate;
    const n = Sonic.symbolSamples;
    for (var i = 0; i < n; i++) {
      var env = 1.0;
      if (i < _ramp) {
        env = 0.5 * (1 - cos(pi * i / _ramp));
      } else if (i >= n - _ramp) {
        env = 0.5 * (1 - cos(pi * (n - 1 - i) / _ramp));
      }
      out[offset + i] = (sin(w * i) * env * _amp * 32767).round();
    }
  }

  static Uint8List toWav(Int16List pcm) {
    final dataLen = pcm.length * 2;
    final bytes = Uint8List(44 + dataLen);
    final bd = ByteData.view(bytes.buffer);
    void str(int off, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes[off + i] = s.codeUnitAt(i);
      }
    }

    str(0, 'RIFF');
    bd.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, 1, Endian.little); // mono
    bd.setUint32(24, Sonic.sampleRate, Endian.little);
    bd.setUint32(28, Sonic.sampleRate * 2, Endian.little);
    bd.setUint16(32, 2, Endian.little);
    bd.setUint16(34, 16, Endian.little);
    str(36, 'data');
    bd.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < pcm.length; i++) {
      bd.setInt16(44 + i * 2, pcm[i], Endian.little);
    }
    return bytes;
  }
}