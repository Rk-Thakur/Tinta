import 'dart:math' as math;

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

/// Where the full stop is mid-bounce: [lift] up from its rest position (design
/// units) and squash/stretch [scaleX]/[scaleY] about its bottom.
class DotPose {
  const DotPose({this.lift = 0, this.scaleX = 1, this.scaleY = 1});

  static const rest = DotPose();

  final double lift;
  final double scaleX;
  final double scaleY;
}

/// The dot's bounce over one loop (t in 0..1): crouch, a big hop, a squash,
/// a small hop, a little squash, then rest for the remainder.
DotPose dotBounce(double t) {
  double hump(double p) => 4 * p * (1 - p); // 0 → 1 → 0
  double sine(double p) => math.sin(math.pi * p);
  DotPose hop(double p, double height, double stretch) {
    // Stretched while moving fast (take-off, landing), round at the top.
    final sy = 1 + stretch * (2 * p - 1).abs();
    return DotPose(
      lift: height * hump(p),
      scaleX: 1 / math.sqrt(sy),
      scaleY: sy,
    );
  }

  DotPose squash(double p, double amount) => DotPose(
    scaleX: 1 + amount * 0.75 * sine(p),
    scaleY: 1 - amount * sine(p),
  );

  if (t < 0.06) return squash(t / 0.06, 0.16); // crouch
  if (t < 0.34) return hop((t - 0.06) / 0.28, 14, 0.14);
  if (t < 0.42) return squash((t - 0.34) / 0.08, 0.26);
  if (t < 0.56) return hop((t - 0.42) / 0.14, 5, 0.06);
  if (t < 0.61) return squash((t - 0.56) / 0.05, 0.1);
  return DotPose.rest;
}

void _drawDot(Canvas canvas, double radius, Paint paint, DotPose pose) {
  canvas.save();
  // Squash about the dot's bottom so it lands on the baseline.
  canvas.translate(
    LogoGeometry.dot.dx,
    LogoGeometry.dot.dy - pose.lift + radius * (1 - pose.scaleY),
  );
  canvas.scale(pose.scaleX, pose.scaleY);
  canvas.drawCircle(Offset.zero, radius, paint);
  canvas.restore();
}

/// Paints the mark into [rect] (kept square-ish, centred, aspect preserved).
void paintLogoMark(
  Canvas canvas,
  Rect rect,
  LogoStyle style, {
  Color color = TintaColors.studioInk,
  DotPose dot = DotPose.rest,
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
      _drawDot(canvas, LogoGeometry.dotRadius, dotPaint..color = color, dot);
    case LogoStyle.small:
      canvas.drawPath(
        t,
        stroke(TintaColors.fluoroOrange, LogoGeometry.stroke + 2),
      );
      _drawDot(
        canvas,
        LogoGeometry.dotRadius + 1,
        dotPaint..color = TintaColors.sun,
        dot,
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
      _drawDot(
        canvas,
        LogoGeometry.dotRadius,
        dotPaint..color = dark ? TintaColors.sun : TintaColors.studioInk,
        dot,
      );
  }
  canvas.restore();
}

/// The mark on its own.
class TintaLogoMark extends StatefulWidget {
  const TintaLogoMark({
    super.key,
    this.size = 48,
    this.style = LogoStyle.paper,
    this.color = TintaColors.studioInk,
    this.bounce = false,
  });

  /// Height; width follows the mark's proportions.
  final double size;
  final LogoStyle style;
  final Color color;

  /// Bounce the full stop (off when the system asks for reduced motion).
  final bool bounce;

  /// One bounce loop, including the rest between bounces.
  static const bouncePeriod = Duration(milliseconds: 2400);

  @override
  State<TintaLogoMark> createState() => _TintaLogoMarkState();
}

class _TintaLogoMarkState extends State<TintaLogoMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: TintaLogoMark.bouncePeriod,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(TintaLogoMark old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final animate =
        widget.bounce &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (animate && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!animate && _loop.isAnimating) {
      _loop
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const b = LogoGeometry.bounds;
    return Semantics(
      label: 'Tinta',
      image: true,
      child: SizedBox(
        width: widget.size * b.width / b.height,
        height: widget.size,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _MarkPainter(widget.style, widget.color, _loop),
          ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.style, this.color, this.loop) : super(repaint: loop);

  final LogoStyle style;
  final Color color;
  final Animation<double> loop;

  @override
  void paint(Canvas canvas, Size size) => paintLogoMark(
    canvas,
    Offset.zero & size,
    style,
    color: color,
    dot: dotBounce(loop.value),
  );

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.style != style || old.color != color || old.loop != loop;
}

/// Mark + "tinta." wordmark, as on the lockup board.
class TintaLockup extends StatelessWidget {
  const TintaLockup({
    super.key,
    this.height = 32,
    this.dark = false,
    this.bounce = false,
  });

  /// Cap-ish height of the wordmark; the mark is drawn a little taller.
  final double height;

  /// On studio ink: screened mark, newsprint wordmark, sun full stop.
  final bool dark;

  /// Bounce the mark's dot.
  final bool bounce;

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
            bounce: bounce,
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
