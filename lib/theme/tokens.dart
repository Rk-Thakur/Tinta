import 'package:flutter/widgets.dart';

/// Tinta palette: two riso inks plus paper, and the studio greys.
abstract final class TintaColors {
  // Inks
  static const risoBlue = Color(0xFF2F4BFF);
  static const risoBlueDeep = Color(0xFF1A2FB8);
  static const fluoroOrange = Color(0xFFFF5A1F);
  static const sun = Color(0xFFFFD23F);
  static const overprintViolet = Color(0xFF3B2A8F);

  // Neutrals (light)
  static const studioInk = Color(0xFF17171C);
  static const ink2 = Color(0xFF4B4B55);
  static const newsprint = Color(0xFFF4F2ED);
  static const line = Color(0xFFDAD7CF);
  static const segmentTrack = Color(0xFFE6E3DC);
  static const surface = Color(0xFFFFFFFF);

  // Studio chrome (dark)
  static const dock = Color(0xFF26262D);
  static const dockRaised = Color(0xFF3A3A40);
  static const studioMuted = Color(0xFFB9B5AB);
  static const studioSubtle = Color(0xFFD8D6D0);
  static const studioDisabled = Color(0xFF8E8A80);

  // Papers
  static const paperSmooth = Color(0xFFFDFCF9);
  static const paperToned = Color(0xFFEDE6D8);
  static const paperKraft = Color(0xFFC9A877);
}

abstract final class TintaRadii {
  static const xs = 8.0;
  static const sm = 14.0;
  static const md = 18.0;
  static const lg = 22.0;
  static const dock = 26.0;
  static const sheet = 30.0;
  static const pill = 999.0;
}

abstract final class TintaSpace {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const gutter = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
}
