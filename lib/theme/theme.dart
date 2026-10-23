import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

abstract final class TintaTheme {
  /// The app's screens, in the current theme and ink pair ([TintaColors]).
  static ThemeData app() {
    final dark = TintaColors.isDark;
    final scheme = ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: TintaColors.risoBlue,
      onPrimary: TintaColors.onAccent,
      secondary: TintaColors.fluoroOrange,
      onSecondary: TintaInk.studioInk,
      tertiary: TintaColors.sun,
      onTertiary: TintaInk.studioInk,
      error: dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828),
      onError: dark ? TintaInk.studioInk : Colors.white,
      surface: TintaColors.newsprint,
      onSurface: TintaColors.studioInk,
      onSurfaceVariant: TintaColors.ink2,
      outline: TintaColors.line,
      surfaceContainerHighest: TintaColors.segmentTrack,
      surfaceContainer: TintaColors.surface,
      inverseSurface: TintaColors.studioInk,
      onInverseSurface: TintaColors.newsprint,
    );
    return _base(scheme, TintaColors.newsprint);
  }

  /// Studio mode: dark chrome around the page.
  static ThemeData studio() {
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: TintaInk.newsprint,
      onPrimary: TintaInk.studioInk,
      secondary: TintaInk.fluoroOrange,
      onSecondary: TintaInk.studioInk,
      tertiary: TintaColors.sun,
      onTertiary: TintaInk.studioInk,
      error: Color(0xFFFF8A80),
      onError: TintaInk.studioInk,
      surface: TintaInk.studioInk,
      onSurface: TintaInk.newsprint,
      onSurfaceVariant: TintaColors.studioMuted,
      outline: TintaInk.ink2,
      surfaceContainer: TintaColors.dock,
      surfaceContainerHighest: TintaColors.dockRaised,
      inverseSurface: TintaInk.newsprint,
      onInverseSurface: TintaInk.studioInk,
    );
    return _base(scheme, TintaInk.studioInk);
  }

  static ThemeData _base(ColorScheme scheme, Color ground) {
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: ground,
      fontFamily: TintaType.bodyFamily,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: ground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // Material pickers and toasts in Tinta's colors and shapes.
      timePickerTheme: TimePickerThemeData(
        backgroundColor: TintaColors.newsprint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TintaRadii.sheet),
        ),
        hourMinuteColor: TintaColors.surface,
        hourMinuteTextColor: TintaColors.studioInk,
        dialBackgroundColor: TintaColors.segmentTrack,
        dialHandColor: TintaColors.risoBlue,
        dayPeriodColor: TintaColors.sun,
        dayPeriodTextColor: TintaInk.studioInk,
        entryModeIconColor: TintaColors.ink2,
        helpTextStyle: TintaType.label(),
        hourMinuteTextStyle: TintaType.display(44),
        dayPeriodTextStyle: TintaType.body(14, weight: FontWeight.w700),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: TintaColors.ink2,
          textStyle: TintaType.body(15),
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: TintaColors.risoBlue,
          textStyle: TintaType.body(15, weight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: TintaColors.isDark
            ? TintaColors.dock
            : TintaInk.studioInk,
        contentTextStyle: TintaType.body(14, color: TintaInk.newsprint),
        actionTextColor: TintaColors.sun,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TintaRadii.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: TintaColors.newsprint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TintaRadii.sheet),
        ),
        titleTextStyle: TintaType.display(24, color: TintaColors.studioInk),
        contentTextStyle: TintaType.body(15, color: TintaColors.ink2),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.brightness == Brightness.dark
            ? TintaColors.dock
            : TintaColors.newsprint,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TintaRadii.sheet),
          ),
        ),
        showDragHandle: false,
      ),
    );
  }
}
