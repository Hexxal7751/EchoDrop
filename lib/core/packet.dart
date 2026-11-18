import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'constants.dart';
import 'crc16.dart';

enum PayloadKind { text, file }

/// What the user sends: text/link or a small file.
class EchoMessage {
  const EchoMessage({required this.kind, required this.data, this.name = ''});

  factory EchoMessage.text(String text) => EchoMessage(
        kind: PayloadKind.text,
        data: Uint8List.fromList(utf8.encode(text)),
      );

  factory EchoMessage.file(String name, Uint8List bytes) =>
      EchoMessage(kind: PayloadKind.file, name: name, data: bytes);

  final PayloadKind kind;
  final String name;
  final Uint8List data;

  String get text => utf8.decode(data, allowMalformed: true);

  /// Wire format: [flags][nameLen][name][data], deflated when that is smaller.
  /// flags: bit0 = file, bit7 = compressed.
  Uint8List encode() {
    var nameBytes = utf8.encode(name);
    if (nameBytes.length > 48) nameBytes = nameBytes.sublist(0, 48);

    final inner = BytesBuilder()
      ..addByte(nameBytes.length)
      ..add(nameBytes)
      ..add(data);
    var body = inner.toBytes();
    var flags = kind == PayloadKind.file ? 1 : 0;

    final z = ZLibCodec(raw: true, level: 9).encode(body);
    if (z.length < body.length) {
      body = Uint8List.fromList(z);
      flags |= 0x80;
    }
    return (BytesBuilder()
          ..addByte(flags)
          ..add(body))
        .toBytes();
  }

  static EchoMessage? decode(Uint8List wire) {
    if (wire.isEmpty) return null;
    try {
      final flags = wire[0];
      var body = wire.sublist(1);
      if (flags & 0x80 != 0) {
        body = Uint8List.fromList(ZLibCodec(raw: true).decode(body));
      }
      final nameLen = body[0];
      final name = utf8.decode(body.sublist(1, 1 + nameLen), allowMalformed: true);
      final data = Uint8List.fromList(body.sublist(1 + nameLen));
      return EchoMessage(
        kind: (flags & 1) == 1 ? PayloadKind.file : PayloadKind.text,
        name: name,
        data: data,
      );
    } catch (_) {
      return null;
    }
  }
}

class Frame {
  const Frame({
    required this.msgId,
    required this.index,
    required this.total,
    required this.payload,
  });
  final int msgId;
  final int index;
  final int total;
  final Uint8List payload;
}

class PacketCodec {
  PacketCodec._();

  /// Splits wire bytes into fixed-size frame bodies (with CRC).
  static List<Uint8List> split(Uint8List wire, int msgId) {
    final total = (wire.length + Sonic.payloadBytes - 1) ~/ Sonic.payloadBytes;
    final frames = <Uint8List>[];
    for (var i = 0; i < total; i++) {
      final start = i * Sonic.payloadBytes;
      final end = min(start + Sonic.payloadBytes, wire.length);
      final chunk = wire.sublist(start, end);

      final body = Uint8List(Sonic.bodyBytes);
      body[0] = msgId & 0xFF;
      body[1] = i;
      body[2] = total;
      body[3] = chunk.length;
      body.setRange(4, 4 + chunk.length, chunk);
      final crc = crc16(body.sublist(0, Sonic.bodyBytes - 2));
      body[Sonic.bodyBytes - 2] = crc >> 8;
      body[Sonic.bodyBytes - 1] = crc & 0xFF;
      frames.add(body);
    }
    return frames;
  }

  static Frame? parse(Uint8List body) {
    if (body.length != Sonic.bodyBytes) return null;
    final rx = (body[Sonic.bodyBytes - 2] << 8) | body[Sonic.bodyBytes - 1];
    if (crc16(body.sublist(0, Sonic.bodyBytes - 2)) != rx) return null;
    final index = body[1];
    final total = body[2];
    final len = body[3];
    if (total == 0 || index >= total || len > Sonic.payloadBytes) return null;
    return Frame(
      msgId: body[0],
      index: index,
      total: total,
      payload: Uint8List.fromList(body.sublist(4, 4 + len)),
    );
  }
}

/// Collects frames (in any order, with repeats) until the message is complete.
class Reassembler {
  int? _msgId;
  int _total = 0;
  final Map<int, Uint8List> _chunks = {};

  int get received => _chunks.length;
  int get total => _total;
  bool get isComplete => _total > 0 && _chunks.length == _total;

  /// Returns true if the frame was new.
  bool add(Frame f) {
    if (_msgId != f.msgId || _total != f.total) {
      _msgId = f.msgId;
      _total = f.total;
      _chunks.clear();
    }
    if (_chunks.containsKey(f.index)) return false;
    _chunks[f.index] = f.payload;
    return true;
  }

  Uint8List? assemble() {
    if (!isComplete) return null;
    final out = BytesBuilder();
    for (var i = 0; i < _total; i++) {
      out.add(_chunks[i]!);
    }
    return out.toBytes();
  }

  void reset() {
    _msgId = null;
    _total = 0;
    _chunks.clear();
  }
}