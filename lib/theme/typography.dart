import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Display: Bricolage Grotesque. Body: DM Sans. Values & labels: JetBrains Mono.
///
/// All three ship in the app as variable fonts (assets/fonts), so weight is
/// set on the 'wght' axis and display/body sizes also drive 'opsz' (optical
/// size), like the CSS in the design.
abstract final class TintaType {
  static const displayFamily = 'BricolageGrotesque';
  static const bodyFamily = 'DMSans';
  static const monoFamily = 'JetBrainsMono';

  static List<FontVariation> _axes(FontWeight weight, {double? opsz}) => [
    FontVariation('wght', weight.value.toDouble()),
    if (opsz != null) FontVariation('opsz', opsz),
  ];

  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w800,
    Color? color,
  }) => TextStyle(
    fontFamily: displayFamily,
    fontSize: size,
    fontWeight: weight,
    fontVariations: _axes(weight, opsz: size.clamp(12, 96).toDouble()),
    height: 1.05,
    letterSpacing: weight == FontWeight.w800 ? -size * 0.032 : -0.3,
    color: color,
  );

  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.45,
  }) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: size,
    fontWeight: weight,
    fontVariations: _axes(weight, opsz: size.clamp(9, 40).toDouble()),
    height: height,
    color: color,
  );

  static TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => TextStyle(
    fontFamily: monoFamily,
    fontSize: size,
    fontWeight: weight,
    fontVariations: _axes(weight),
    color: color,
  );

  /// Uppercase section label, e.g. "PAPER", "FORMAT".
  static TextStyle label({Color? color}) =>
      mono(12, color: color ?? TintaColors.ink2).copyWith(letterSpacing: 1);

  // Scale from the foundations board.
  static TextStyle get display34 => display(34);
  static TextStyle get display28 => display(28);
  static TextStyle get title22 => display(22, weight: FontWeight.w600);
  static TextStyle get body17 => body(17);
  static TextStyle get body15 => body(15);
  static TextStyle get body13 => body(13, color: TintaColors.ink2);
}
