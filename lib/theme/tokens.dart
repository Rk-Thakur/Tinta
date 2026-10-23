import 'package:flutter/widgets.dart';

/// The fixed Tinta inks and papers. Artwork uses these: pages, covers, the
/// logo, exports, and the studio chrome around the canvas, which is dark in
/// every theme.
abstract final class TintaInk {
  // Inks
  static const risoBlue = Color(0xFF2F4BFF);
  static const risoBlueDeep = Color(0xFF1A2FB8);
  static const fluoroOrange = Color(0xFFFF5A1F);
  static const sun = Color(0xFFFFD23F);
  static const overprintViolet = Color(0xFF3B2A8F);

  // Neutrals
  static const studioInk = Color(0xFF17171C);
  static const ink2 = Color(0xFF4B4B55);
  static const newsprint = Color(0xFFF4F2ED);
  static const line = Color(0xFFDAD7CF);
  static const segmentTrack = Color(0xFFE6E3DC);
  static const surface = Color(0xFFFFFFFF);
}

/// App appearance (Settings → Theme).
enum ThemeChoice { light, dark, system }

/// Two inks that tint the app (Settings → Ink pair).
enum InkPair {
  riso(
    'Blue & orange',
    Color(0xFF2F4BFF),
    Color(0xFFFF5A1F),
    Color(0xFF6B80FF),
  ),
  mono('Ink & sun', Color(0xFF17171C), Color(0xFFFFD23F), Color(0xFFF4F2ED)),
  garden(
    'Green & pink',
    Color(0xFF1F9D63),
    Color(0xFFE8467C),
    Color(0xFF3FBF7F),
  ),
  lagoon(
    'Teal & orange',
    Color(0xFF0E7C86),
    Color(0xFFF7931E),
    Color(0xFF2BB0BB),
  );

  const InkPair(this.label, this.primary, this.secondary, this.primaryOnDark);

  final String label;
  final Color primary;
  final Color secondary;

  /// [primary] as it reads on the dark ground.
  final Color primaryOnDark;
}

/// The UI colors: the light screens follow the theme and ink pair; the
/// studio chrome (dock, rails, the canvas) stays put.
///
/// Names are the light-theme roles: [newsprint] is the ground, [surface] the
/// cards, [studioInk] text and dark fills. In the dark theme they swap.
abstract final class TintaColors {
  static bool _dark = false;
  static InkPair _pair = InkPair.riso;

  static bool get isDark => _dark;
  static InkPair get inkPair => _pair;

  /// Switch the palette. The app rebuilds itself afterwards.
  static void apply({required bool dark, required InkPair pair}) {
    _dark = dark;
    _pair = pair;
  }

  // Accents: the ink pair.
  static Color get risoBlue => _dark ? _pair.primaryOnDark : _pair.primary;
  static Color get risoBlueDeep => _pair == InkPair.riso
      ? (_dark ? TintaInk.risoBlue : TintaInk.risoBlueDeep)
      : Color.lerp(
          risoBlue,
          _dark ? TintaInk.newsprint : TintaInk.studioInk,
          0.25,
        )!;
  static Color get fluoroOrange => _pair.secondary;

  /// Text and icons on a [risoBlue] fill.
  static Color get onAccent => risoBlue.computeLuminance() > 0.4
      ? TintaInk.studioInk
      : const Color(0xFFFFFFFF);

  // Neutrals.
  static Color get studioInk =>
      _dark ? const Color(0xFFF4F2ED) : TintaInk.studioInk;
  static Color get ink2 => _dark ? const Color(0xFFB9B5AB) : TintaInk.ink2;
  static Color get newsprint =>
      _dark ? const Color(0xFF131317) : TintaInk.newsprint;
  static Color get line => _dark ? const Color(0xFF3A3A42) : TintaInk.line;
  static Color get segmentTrack =>
      _dark ? const Color(0xFF2A2A31) : TintaInk.segmentTrack;
  static Color get surface =>
      _dark ? const Color(0xFF1F1F25) : TintaInk.surface;

  /// Dividers inside cards.
  static Color get hairline =>
      _dark ? const Color(0xFF2E2E35) : const Color(0xFFECEAE4);

  /// Text and icons on a [studioInk] fill.
  static Color get onInk =>
      _dark ? TintaInk.studioInk : const Color(0xFFFFFFFF);

  // The same in every theme.
  static const sun = TintaInk.sun;
  static const overprintViolet = TintaInk.overprintViolet;

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
