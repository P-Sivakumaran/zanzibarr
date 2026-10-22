import 'package:flutter/material.dart';

/// Player controls stay readable over video, independently of the app theme.
class PlayerMenuTheme extends StatelessWidget {
  const PlayerMenuTheme({super.key, required this.child});

  static const surface = Color(0xFF202024);
  static const foreground = Color(0xFFF5F5F7);
  static const secondary = Color(0xFFCBCBD3);
  static const focus = Color(0xFF6C6C74);
  final Widget child;

  static ThemeData data(BuildContext context) {
    final base = Theme.of(context);
    final scheme = ColorScheme.fromSeed(
      seedColor: base.colorScheme.primary,
      brightness: Brightness.dark,
    ).copyWith(surface: surface, onSurface: foreground);
    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: scheme,
      textTheme: base.textTheme.apply(
        bodyColor: foreground,
        displayColor: foreground,
      ),
      iconTheme: const IconThemeData(color: foreground),
      disabledColor: secondary,
      focusColor: focus,
      hoverColor: const Color(0xFF3D3D44),
      dividerColor: const Color(0xFF777780),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        iconColor: foreground,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.disabled)
                ? secondary
                : foreground,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      Theme(data: data(context), child: child);
}

/// Programmatic menus originate above the controls' inherited theme. Scope each
/// entry as well, so its InkWell, focus highlight and text use the player palette.
class PlayerMenuEntry<T> extends PopupMenuEntry<T> {
  const PlayerMenuEntry({super.key, required this.entry});
  final PopupMenuEntry<T> entry;

  @override
  double get height => entry.height;
  @override
  bool represents(T? value) => entry.represents(value);
  @override
  State<PlayerMenuEntry<T>> createState() => _PlayerMenuEntryState<T>();
}

class _PlayerMenuEntryState<T> extends State<PlayerMenuEntry<T>> {
  @override
  Widget build(BuildContext context) => PlayerMenuTheme(child: widget.entry);
}
