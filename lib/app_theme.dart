import 'package:flutter/material.dart';

class Brand {
  Brand._();
  static const blue = Color(0xFF2B4BFF);
  static const purple = Color(0xFF8E2BFF);
  static const magenta = Color(0xFFFF2BD6);
  static const orange = Color(0xFFFF9A1F);
  static const gradient = LinearGradient(colors: [blue, purple, magenta, orange]);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.purple,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => Brand.gradient.createShader(rect),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style),
    );
  }
}