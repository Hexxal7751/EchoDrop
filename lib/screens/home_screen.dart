import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../widgets/action_card.dart';
import 'receive_screen.dart';
import 'send_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Center(child: Image.asset('assets/logo.png', height: 180)),
            const SizedBox(height: 8),
            Center(
              child: GradientText(
                'EchoDrop',
                style: t.displaySmall!.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send links, text and tiny files through sound.\n'
              'No internet. No Bluetooth. No pairing.',
              textAlign: TextAlign.center,
              style: t.bodyLarge?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 32),
            ActionCard(
              icon: Icons.volume_up_rounded,
              title: 'Send',
              subtitle: 'Play your message as sound',
              colors: const [Brand.blue, Brand.purple],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SendScreen()),
              ),
            ),
            const SizedBox(height: 16),
            ActionCard(
              icon: Icons.mic_rounded,
              title: 'Receive',
              subtitle: 'Listen and decode a nearby sound',
              colors: const [Brand.magenta, Brand.orange],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReceiveScreen()),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Tip: hold the phones 20 to 30 cm apart, turn the volume up '
              'and stay in a quiet place.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}