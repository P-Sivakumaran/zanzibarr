import 'package:flutter/material.dart';

/// One visual contract for the application and rendered review fixtures.
abstract final class AppTheme {
  static const accent = Color(0xFFFF453A);
  static const contentWidth = 1320.0;

  static ThemeData build(Brightness brightness, {String? fontFamily}) {
    final dark = brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF111518) : const Color(0xFFFAFAF8);
    final panel = dark ? const Color(0xFF1B2126) : Colors.white;
    final ink = dark ? const Color(0xFFF0F2F4) : const Color(0xFF20272C);
    final secondary = dark ? const Color(0xFFB6C0C8) : const Color(0xFF52616B);
    final outline = dark ? const Color(0xFF84939E) : const Color(0xFF6D7B85);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: secondary,
          surfaceContainerLowest: surface,
          surfaceContainerLow: panel,
          surfaceContainer: panel,
          surfaceContainerHigh: dark
              ? const Color(0xFF252D34)
              : const Color(0xFFEDF0F2),
          surfaceContainerHighest: dark
              ? const Color(0xFF303B44)
              : const Color(0xFFE3E8EC),
          outline: outline,
          outlineVariant: dark
              ? const Color(0xFF36434D)
              : const Color(0xFFD4DBDF),
          // Amber distinguishes recovery/error messages from the red brand.
          error: dark ? const Color(0xFFFFBE66) : const Color(0xFF8C4A00),
          onError: dark ? const Color(0xFF442C00) : Colors.white,
          errorContainer: dark
              ? const Color(0xFF4A3100)
              : const Color(0xFFFFE0B2),
          onErrorContainer: dark
              ? const Color(0xFFFFDDA6)
              : const Color(0xFF5C3A00),
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: scheme,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    ButtonStyle focus(ButtonStyle style) => style.copyWith(
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? scheme.primary.withValues(alpha: .18)
            : null,
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? BorderSide(color: scheme.primary, width: 2)
            : null,
      ),
    );
    final control = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      shape: WidgetStatePropertyAll(shape),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: outline),
    );
    return base.copyWith(
      scaffoldBackgroundColor: surface,
      canvasColor: panel,
      dividerColor: scheme.outlineVariant,
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -.6,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: secondary,
          height: 1.4,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: secondary),
        helperStyle: TextStyle(color: secondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: focus(
          FilledButton.styleFrom(
            backgroundColor: ink,
            foregroundColor: surface,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: shape,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(style: focus(control)),
      textButtonTheme: TextButtonThemeData(style: focus(control)),
      iconButtonTheme: IconButtonThemeData(style: focus(control)),
      segmentedButtonTheme: SegmentedButtonThemeData(style: focus(control)),
      listTileTheme: ListTileThemeData(
        iconColor: secondary,
        textColor: ink,
        shape: shape,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: ink, fontSize: 14),
        shape: shape,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: ink),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(panel),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(panel),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: surface, fontSize: 13),
        padding: const EdgeInsets.all(12),
        waitDuration: const Duration(milliseconds: 450),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: TextStyle(color: surface),
        shape: shape,
      ),
      focusColor: scheme.primary.withValues(alpha: .18),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
