import 'dart:math';
import 'dart:typed_data';

import 'constants.dart';
import 'packet.dart';

enum _State { idle, refining, collecting }

/// Streaming decoder: feed it microphone PCM, get verified frames back.
///
/// Every 10 ms it measures the 16 tone energies over the last 40 ms
/// (Goertzel). A known head pattern (preamble + sync) marks the frame start,
/// then the body is read one symbol every 4 hops.
class ModemDecoder {
  ModemDecoder({required this.onFrame, this.onLevel}) {
    for (var t = 0; t < Sonic.toneCount; t++) {
      final k = Sonic.toneFreq(t) * _n / Sonic.sampleRate;
      _coeff[t] = 2 * cos(2 * pi * k / _n);
    }
  }

  final void Function(Frame frame) onFrame;
  final void Function(double rms)? onLevel;

  static const int _n = Sonic.symbolSamples;
  static const int _hps = Sonic.hopsPerSymbol;
  static const double _minHeadConf = 0.35;
  static const double _minPeakPower = 1.0;

  final Float64List _ring = Float64List(_n);
  final Float64List _coeff = Float64List(Sonic.toneCount);
  final Float64List _s1 = Float64List(Sonic.toneCount);
  final Float64List _s2 = Float64List(Sonic.toneCount);
  int _w = 0;
  int _filled = 0;
  int _sinceHop = 0;
  int? _carry;

  final List<int> _sym = [];
  final List<double> _conf = [];
  int _base = 0; // global hop index of _sym[0]

  _State _state = _State.idle;
  int _scanFrom = 0;
  int _refineFrom = 0;
  int _bestN = 0;
  int _frameEnd = 0;

  /// Raw little-endian PCM16 bytes (what the mic stream delivers).
  void addPcm16Bytes(Uint8List bytes) {
    var i = 0;
    if (_carry != null && bytes.isNotEmpty) {
      _push(_int16(_carry!, bytes[0]));
      _carry = null;
      i = 1;
    }
    for (; i + 1 < bytes.length; i += 2) {
      _push(_int16(bytes[i], bytes[i + 1]));
    }
    if (i < bytes.length) _carry = bytes[i];
  }

  void addSamples(Int16List samples) {
    for (final s in samples) {
      _push(s);
    }
  }

  int _int16(int lo, int hi) {
    final v = (hi << 8) | lo;
    return v >= 0x8000 ? v - 0x10000 : v;
  }

  void _push(int s) {
    _ring[_w] = s / 32768.0;
    _w = (_w + 1) % _n;
    if (_filled < _n) _filled++;
    if (++_sinceHop == Sonic.hopSamples) {
      _sinceHop = 0;
      if (_filled >= _n) _processHop();
    }
  }

  void _processHop() {
    const tc = Sonic.toneCount;
    for (var t = 0; t < tc; t++) {
      _s1[t] = 0;
      _s2[t] = 0;
    }
    var idx = _w; // oldest sample
    var energy = 0.0;
    for (var i = 0; i < _n; i++) {
      final x = _ring[idx];
      energy += x * x;
      if (++idx == _n) idx = 0;
      for (var t = 0; t < tc; t++) {
        final s0 = x + _coeff[t] * _s1[t] - _s2[t];
        _s2[t] = _s1[t];
        _s1[t] = s0;
      }
    }
    var best = 0;
    var bestP = -1.0;
    var sum = 0.0;
    for (var t = 0; t < tc; t++) {
      final p = _s1[t] * _s1[t] + _s2[t] * _s2[t] - _coeff[t] * _s1[t] * _s2[t];
      sum += p;
      if (p > bestP) {
        bestP = p;
        best = t;
      }
    }
    final conf = (bestP >= _minPeakPower && sum > 0) ? bestP / sum : 0.0;
    _sym.add(best);
    _conf.add(conf);
    onLevel?.call(sqrt(energy / _n));
    _scan();
    if (_sym.length > 2000) {
      _sym.removeRange(0, 1000);
      _conf.removeRange(0, 1000);
      _base += 1000;
    }
  }

  int get _latest => _base + _sym.length - 1;

  /// Score if the head pattern ends exactly at hop [n], otherwise -1.
  double _headScore(int n) {
    var score = 0.0;
    for (var i = 0; i < Sonic.head.length; i++) {
      final h = n - _hps * (Sonic.head.length - 1 - i) - _base;
      if (h < 0 || h >= _sym.length) return -1;
      if (_sym[h] != Sonic.head[i] || _conf[h] < _minHeadConf) return -1;
      score += _conf[h];
    }
    return score;
  }

  void _scan() {
    final latest = _latest;

    if (_state == _State.idle) {
      final firstHop = latest - _hps * (Sonic.head.length - 1);
      if (firstHop >= _scanFrom && _headScore(latest) > 0) {
        _state = _State.refining;
        _refineFrom = latest;
      }
    } else if (_state == _State.refining) {
      if (latest >= _refineFrom + _hps - 1) {
        var bestScore = -1.0;
        var bestN = -1;
        for (var n = _refineFrom - (_hps - 1); n <= _refineFrom + _hps - 1; n++) {
          final s = _headScore(n);
          if (s > bestScore) {
            bestScore = s;
            bestN = n;
          }
        }
        if (bestN < 0) {
          _state = _State.idle;
          return;
        }
        _bestN = bestN;
        _frameEnd = bestN + _hps * Sonic.bodySymbols;
        _state = _State.collecting;
      }
    } else if (latest >= _frameEnd) {
      final body = Uint8List(Sonic.bodyBytes);
      for (var k = 0; k < Sonic.bodySymbols; k++) {
        final h = _bestN + _hps * (k + 1) - _base;
        final nib = (h >= 0 && h < _sym.length) ? _sym[h] : 0;
        if (k.isEven) {
          body[k ~/ 2] = nib << 4;
        } else {
          body[k ~/ 2] |= nib;
        }
      }
      _scanFrom = _frameEnd + 1;
      _state = _State.idle;
      final frame = PacketCodec.parse(body);
      if (frame != null) onFrame(frame);
    }
  }
}