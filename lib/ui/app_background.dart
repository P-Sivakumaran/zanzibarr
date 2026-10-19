import 'package:flutter/material.dart';

/// Shared dark/light radial-gradient backdrop (logo navy family in dark
/// mode, its light counterpart in light mode) so every top-level screen
/// reads as one surface instead of Home having its own look.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 1.15,
          colors: isDark
              ? const [Color(0xFF1C2421), Color(0xFF101313)]
              : const [Color(0xFFFAFAF8), Color(0xFFECEEE8)],
        ),
      ),
      child: child,
    );
  }
}
