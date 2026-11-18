import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import '../core/constants.dart';
import '../core/modem_decoder.dart';
import '../core/packet.dart';

class ReceiveService extends ChangeNotifier {
  final AudioRecorder _rec = AudioRecorder();
  final Reassembler _asm = Reassembler();
  final ValueNotifier<double> level = ValueNotifier(0);

  StreamSubscription<Uint8List>? _sub;
  ModemDecoder? _decoder;

  bool listening = false;
  bool permissionDenied = false;
  int received = 0;
  int total = 0;
  EchoMessage? result;
  String? error;

  Future<void> start() async {
    result = null;
    error = null;
    received = 0;
    total = 0;
    permissionDenied = false;
    _asm.reset();

    if (!await _rec.hasPermission()) {
      permissionDenied = true;
      notifyListeners();
      return;
    }

    _decoder = ModemDecoder(
      onFrame: _onFrame,
      onLevel: (rms) => level.value = min(1.0, rms * 10),
    );
    final stream = await _rec.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: Sonic.sampleRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
    );
    _sub = stream.listen(_decoder!.addPcm16Bytes);
    listening = true;
    notifyListeners();
  }

  void _onFrame(Frame f) {
    if (result != null) return;
    _asm.add(f);
    received = _asm.received;
    total = _asm.total;
    HapticFeedback.selectionClick();

    if (_asm.isComplete) {
      final wire = _asm.assemble();
      final msg = wire == null ? null : EchoMessage.decode(wire);
      if (msg != null) {
        result = msg;
        HapticFeedback.heavyImpact();
        stop();
      } else {
        error = 'The data arrived damaged. Please try again.';
        _asm.reset();
        received = 0;
        total = 0;
      }
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (await _rec.isRecording()) await _rec.stop();
    listening = false;
    level.value = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _rec.dispose();
    level.dispose();
    super.dispose();
  }
}