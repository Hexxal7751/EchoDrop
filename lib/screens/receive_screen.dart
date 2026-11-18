import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/packet.dart';
import '../services/receive_service.dart';
import '../widgets/wave_bars.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final _svc = ReceiveService();

  @override
  void initState() {
    super.initState();
    _svc.start();
  }

  @override
  void dispose() {
    _svc.dispose();
    super.dispose();
  }

  Uri? _asUri(String s) {
    final t = s.trim();
    if (t.contains(RegExp(r'\s'))) return null;
    final u = Uri.tryParse(t);
    if (u == null || u.host.isEmpty) return null;
    return (u.scheme == 'http' || u.scheme == 'https') ? u : null;
  }

  Future<void> _saveFile(EchoMessage m) async {
    final dir = await getTemporaryDirectory();
    var name = m.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (name.isEmpty) name = 'echodrop_file';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(m.data);
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive')),
      body: ListenableBuilder(
        listenable: _svc,
        builder: (context, _) {
          if (_svc.permissionDenied) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'EchoDrop needs the microphone to hear the sound.\n'
                      'Please allow it and try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _svc.start, child: const Text('Try again')),
                  ],
                ),
              ),
            );
          }
          final r = _svc.result;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: r == null ? _listening() : _resultView(r),
          );
        },
      ),
    );
  }

  List<Widget> _listening() {
    final t = Theme.of(context).textTheme;
    return [
      const SizedBox(height: 12),
      WaveBars(level: _svc.level, active: _svc.listening),
      const SizedBox(height: 20),
      Text(
        _svc.received == 0
            ? 'Listening… ask the sender to start.'
            : 'Receiving frame ${_svc.received} of ${_svc.total}',
        textAlign: TextAlign.center,
        style: t.titleMedium,
      ),
      const SizedBox(height: 16),
      LinearProgressIndicator(
        value: _svc.total == 0 ? null : _svc.received / _svc.total,
        minHeight: 8,
        borderRadius: BorderRadius.circular(8),
      ),
      if (_svc.error != null) ...[
        const SizedBox(height: 16),
        Text(_svc.error!, style: const TextStyle(color: Colors.red)),
      ],
      const SizedBox(height: 28),
      Text(
        'Hold the phones 20 to 30 cm apart. Frames can arrive in any order '
        'and repeat, so you can start listening at any time.',
        textAlign: TextAlign.center,
        style: t.bodySmall?.copyWith(color: Colors.black45),
      ),
    ];
  }

  List<Widget> _resultView(EchoMessage m) {
    final isText = m.kind == PayloadKind.text;
    final uri = isText ? _asUri(m.text) : null;
    return [
      const SizedBox(height: 8),
      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
      const SizedBox(height: 8),
      Text(
        'Received!',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      Card(
        elevation: 0,
        color: const Color(0xFFF5F2FF),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isText
              ? SelectableText(m.text)
              : Row(
                  children: [
                    const Icon(Icons.insert_drive_file_rounded),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${m.name}\n${m.data.length} B')),
                  ],
                ),
        ),
      ),
      const SizedBox(height: 16),
      if (isText) ...[
        if (uri != null)
          FilledButton.icon(
            onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open link'),
          ),
        if (uri != null) const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: m.text));
            if (!mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Copied')));
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy'),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: () => Share.share(m.text),
          icon: const Icon(Icons.share_rounded),
          label: const Text('Share'),
        ),
      ] else
        FilledButton.icon(
          onPressed: () => _saveFile(m),
          icon: const Icon(Icons.save_alt_rounded),
          label: const Text('Save / Share file'),
        ),
      const SizedBox(height: 10),
      TextButton(onPressed: _svc.start, child: const Text('Receive another')),
    ];
  }
}