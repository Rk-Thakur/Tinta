import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// The Misprint "t": two inks, one stroke, out of register on purpose.
///
/// Construction (design units): visible stroke 14 · round caps · hook r16 ·
/// dot r7 · misregister 5 / 4. Each plate is the same "t", stroked 19 wide
/// (14 + 5) and shifted half the misregister either way; where blue and
/// orange overlap they overprint into the dark core.
enum LogoStyle {
  /// Blue + orange multiplying on paper; studio-ink dot. Primary.
  paper,

  /// Blue + orange screening to pink on studio ink; sun dot. Dark mode.
  studio,

  /// Multiply on sun yellow; studio-ink dot. Alternate icon.
  sun,

  /// One ink for tiny sizes (below 48px): orange "t", sun dot, on studio ink.
  small,

  /// Single-color mark (see [TintaLogoMark.color]).
  oneColor,
}

/// Geometry shared by the mark and the icon generator.
abstract final class LogoGeometry {
  static const stroke = 14.0;
  static const misregisterX = 5.0;
  static const misregisterY = 4.0;
  static const plateStroke = stroke + misregisterX;
  static const hookRadius = 16.0;
  static const dotRadius = 7.0;

  // The registered "t" centreline: stem x = 0, crossbar y = 0.
  static const stemTop = -22.0;
  static const barLeft = -16.0;
  static const barRight = 22.0;
  static const baseline = 40.0;
  static const dot = Offset(38, 40);

  /// Bounds of everything drawn (plates incl. misregister, and the dot).
  static const bounds = Rect.fromLTRB(-28.5, -33.5, 45.5, 51.5);

  static Path centerline() => Path()
    // Stem, then the hook curving right into the baseline.
    ..moveTo(0, stemTop)
    ..lineTo(0, baseline - hookRadius)
    ..arcToPoint(
      const Offset(hookRadius, baseline),
      radius: const Radius.circular(hookRadius),
      clockwise: false,
    )
    // Crossbar.
    ..moveTo(barLeft, 0)
    ..lineTo(barRight, 0);
}

/// Paints the mark into [rect] (kept square-ish, centred, aspect preserved).
void paintLogoMark(
  Canvas canvas,
  Rect rect,
  LogoStyle style, {
  Color color = TintaColors.studioInk,
}) {
  const b = LogoGeometry.bounds;
  final scale = (rect.width / b.width) < (rect.height / b.height)
      ? rect.width / b.width
      : rect.height / b.height;
  final drawn = Size(b.width * scale, b.height * scale);
  canvas.save();
  canvas.translate(
    rect.left + (rect.width - drawn.width) / 2,
    rect.top + (rect.height - drawn.height) / 2,
  );
  canvas.scale(scale);
  canvas.translate(-b.left, -b.top);

  final t = LogoGeometry.centerline();
  Paint stroke(Color c, double width, {BlendMode blend = BlendMode.srcOver}) =>
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..blendMode = blend
        ..isAntiAlias = true;
  final dotPaint = Paint()..isAntiAlias = true;

  switch (style) {
    case LogoStyle.oneColor:
      canvas.drawPath(t, stroke(color, LogoGeometry.stroke));
      canvas.drawCircle(
        LogoGeometry.dot,
        LogoGeometry.dotRadius,
        dotPaint..color = color,
      );
    case LogoStyle.small:
      canvas.drawPath(
        t,
        stroke(TintaColors.fluoroOrange, LogoGeometry.stroke + 2),
      );
      canvas.drawCircle(
        LogoGeometry.dot,
        LogoGeometry.dotRadius + 1,
        dotPaint..color = TintaColors.sun,
      );
    case LogoStyle.paper || LogoStyle.sun || LogoStyle.studio:
      final dark = style == LogoStyle.studio;
      const half = Offset(
        LogoGeometry.misregisterX / 2,
        LogoGeometry.misregisterY / 2,
      );
      // Own layer, so the overprint mixes the two inks only.
      canvas.saveLayer(b.inflate(4), Paint());
      canvas.drawPath(
        t.shift(-half),
        stroke(TintaColors.risoBlue, LogoGeometry.plateStroke),
      );
      canvas.drawPath(
        t.shift(half),
        stroke(
          TintaColors.fluoroOrange,
          LogoGeometry.plateStroke,
          blend: dark ? BlendMode.screen : BlendMode.multiply,
        ),
      );
      canvas.restore();
      canvas.drawCircle(
        LogoGeometry.dot,
        LogoGeometry.dotRadius,
        dotPaint..color = dark ? TintaColors.sun : TintaColors.studioInk,
      );
  }
  canvas.restore();
}

/// The mark on its own.
class TintaLogoMark extends StatelessWidget {
  const TintaLogoMark({
    super.key,
    this.size = 48,
    this.style = LogoStyle.paper,
    this.color = TintaColors.studioInk,
  });

  /// Height; width follows the mark's proportions.
  final double size;
  final LogoStyle style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const b = LogoGeometry.bounds;
    return Semantics(
      label: 'Tinta',
      image: true,
      child: SizedBox(
        width: size * b.width / b.height,
        height: size,
        child: CustomPaint(painter: _MarkPainter(style, color)),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.style, this.color);

  final LogoStyle style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      paintLogoMark(canvas, Offset.zero & size, style, color: color);

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.style != style || old.color != color;
}

/// Mark + "tinta." wordmark, as on the lockup board.
class TintaLockup extends StatelessWidget {
  const TintaLockup({super.key, this.height = 32, this.dark = false});

  /// Cap-ish height of the wordmark; the mark is drawn a little taller.
  final double height;

  /// On studio ink: screened mark, newsprint wordmark, sun full stop.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'tinta',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: height * 0.35,
        children: [
          TintaLogoMark(
            size: height * 1.15,
            style: dark ? LogoStyle.studio : LogoStyle.paper,
          ),
          Text.rich(
            TextSpan(
              text: 'tinta',
              style: TintaType.display(
                height,
                color: dark ? TintaColors.newsprint : TintaColors.studioInk,
              ).copyWith(height: 1),
              children: [
                TextSpan(
                  text: '.',
                  style: TextStyle(
                    color: dark ? TintaColors.sun : TintaColors.fluoroOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
