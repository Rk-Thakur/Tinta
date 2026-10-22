import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

abstract final class TintaTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: TintaColors.risoBlue,
      onPrimary: Colors.white,
      secondary: TintaColors.fluoroOrange,
      onSecondary: TintaColors.studioInk,
      tertiary: TintaColors.sun,
      onTertiary: TintaColors.studioInk,
      error: Color(0xFFC62828),
      onError: Colors.white,
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
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: TintaColors.newsprint,
      onPrimary: TintaColors.studioInk,
      secondary: TintaColors.fluoroOrange,
      onSecondary: TintaColors.studioInk,
      tertiary: TintaColors.sun,
      onTertiary: TintaColors.studioInk,
      error: Color(0xFFFF8A80),
      onError: TintaColors.studioInk,
      surface: TintaColors.studioInk,
      onSurface: TintaColors.newsprint,
      onSurfaceVariant: TintaColors.studioMuted,
      outline: TintaColors.ink2,
      surfaceContainer: TintaColors.dock,
      surfaceContainerHighest: TintaColors.dockRaised,
      inverseSurface: TintaColors.newsprint,
      onInverseSurface: TintaColors.studioInk,
    );
    return _base(scheme, TintaColors.studioInk);
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
        dayPeriodTextColor: TintaColors.studioInk,
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
        backgroundColor: TintaColors.studioInk,
        contentTextStyle: TintaType.body(14, color: TintaColors.newsprint),
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
