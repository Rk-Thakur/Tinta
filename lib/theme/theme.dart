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
