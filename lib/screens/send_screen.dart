import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/modem_encoder.dart';
import '../core/packet.dart';
import '../services/send_service.dart';
import '../widgets/wave_bars.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _service = SendService();
  final _text = TextEditingController();
  PayloadKind _kind = PayloadKind.text;
  String? _fileName;
  Uint8List? _fileBytes;
  bool _sending = false;
  bool _busy = false;
  SendInfo? _info;

  @override
  void dispose() {
    _text.dispose();
    _service.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  EchoMessage? _buildMessage() {
    if (_kind == PayloadKind.text) {
      final t = _text.text.trim();
      return t.isEmpty ? null : EchoMessage.text(t);
    }
    if (_fileBytes == null) return null;
    return EchoMessage.file(_fileName ?? 'file', _fileBytes!);
  }

  String? _estimate() {
    final m = _buildMessage();
    if (m == null) return null;
    final n = m.encode().length;
    if (n > Sonic.maxMessageBytes) {
      return 'Too large: $n B (limit ${Sonic.maxMessageBytes} B).';
    }
    final f = SendService.framesFor(n);
    final s = ModemEncoder.passDuration(f).inSeconds;
    return '$n B  ·  $f frames  ·  about ${s}s per pass';
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles();
    final f = res?.files.single;
    if (f == null || f.path == null) return;
    if (f.size > Sonic.maxMessageBytes) {
      _toast('That file is ${f.size} B. Sound mode supports about 1 KB.');
      return;
    }
    final bytes = await File(f.path!).readAsBytes();
    setState(() {
      _fileName = f.name;
      _fileBytes = bytes;
    });
  }

  Future<void> _start() async {
    final msg = _buildMessage();
    if (msg == null) {
      _toast('Nothing to send yet.');
      return;
    }
    setState(() => _busy = true);
    try {
      final info = await _service.start(msg);
      if (!mounted) return;
      setState(() {
        _sending = true;
        _info = info;
      });
    } on FormatException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('Could not start: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    await _service.stop();
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final est = _estimate();
    return Scaffold(
      appBar: AppBar(title: const Text('Send')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<PayloadKind>(
            segments: const [
              ButtonSegment(
                value: PayloadKind.text,
                icon: Icon(Icons.link_rounded),
                label: Text('Text / Link'),
              ),
              ButtonSegment(
                value: PayloadKind.file,
                icon: Icon(Icons.attach_file_rounded),
                label: Text('Small file'),
              ),
            ],
            selected: {_kind},
            onSelectionChanged:
                _sending ? null : (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 20),
          if (_kind == PayloadKind.text)
            TextField(
              controller: _text,
              enabled: !_sending,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Paste a link or type a message',
              ),
            )
          else ...[
            OutlinedButton.icon(
              onPressed: _sending ? null : _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Choose a file (up to about 1 KB)'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            ),
            if (_fileName != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('$_fileName  ·  ${_fileBytes!.length} B'),
              ),
          ],
          const SizedBox(height: 12),
          if (est != null) Text(est, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 28),
          if (_sending) ...[
            const WaveBars(),
            const SizedBox(height: 12),
            Text(
              'Playing on loop (${_info?.frames} frames, about '
              '${_info?.pass.inSeconds}s per pass).\n'
              'Keep the volume up and the other phone close until it finishes.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(onPressed: _stop, child: const Text('Stop')),
          ] else
            FilledButton.icon(
              onPressed: _busy ? null : _start,
              icon: const Icon(Icons.volume_up_rounded),
              label: Text(_busy ? 'Preparing…' : 'Start sending'),
            ),
        ],
      ),
    );
  }
}