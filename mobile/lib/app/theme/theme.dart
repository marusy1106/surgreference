import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

export 'tokens.dart';
export 'typography.dart';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? SrColors.dark : SrColors.light;
  final text = srTextTheme(c.text, c.textMuted);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.accent,
    onSecondary: c.onAccent,
    error: c.error,
    onError: c.bg,
    surface: c.surface,
    onSurface: c.text,
    onSurfaceVariant: c.textMuted,
    surfaceContainerHighest: c.surface2,
    outline: c.line,
    outlineVariant: c.line,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    fontFamily: kFontFamily,
    textTheme: text,
    dividerColor: c.line,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleMedium,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.accent,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelSmall!.copyWith(color: states.contains(WidgetState.selected) ? c.text : c.textMuted),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? c.onAccent : c.textMuted),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface2,
      hintStyle: text.bodyMedium!.copyWith(color: c.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: SrSpace.l, vertical: SrSpace.l),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(SrRadius.tile), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SrRadius.tile),
        borderSide: BorderSide(color: c.accent, width: 2),
      ),
    ),
  );
}
