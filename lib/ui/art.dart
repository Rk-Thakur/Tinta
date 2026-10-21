import 'package:flutter/widgets.dart';
import 'package:path_parsing/path_parsing.dart';

/// Parses SVG path data (`d`) into a Flutter [Path].
Path svgPath(String d) {
  final proxy = _PathProxy();
  writeSvgPathDataToPath(d, proxy);
  return proxy.path;
}

class _PathProxy extends PathProxy {
  final path = Path();
  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
  @override
  void lineTo(double x, double y) => path.lineTo(x, y);
  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void close() => path.close();
}

/// One vector shape in an [Artwork]. `multiply` gives the riso overprint look.
sealed class ArtShape {
  const ArtShape({
    this.fill,
    this.stroke,
    this.strokeWidth = 2,
    this.opacity = 1,
    this.multiply = false,
    this.dash,
  });

  final Color? fill;
  final Color? stroke;
  final double strokeWidth;
  final double opacity;
  final bool multiply;
  final List<double>? dash;

  Path toPath();
}

class ArtPath extends ArtShape {
  const ArtPath(
    this.d, {
    super.fill,
    super.stroke,
    super.strokeWidth,
    super.opacity,
    super.multiply,
    super.dash,
  });
  final String d;
  @override
  Path toPath() => svgPath(d);
}

class ArtCircle extends ArtShape {
  const ArtCircle(
    this.cx,
    this.cy,
    this.r, {
    super.fill,
    super.stroke,
    super.strokeWidth,
    super.opacity,
    super.multiply,
    super.dash,
  });
  final double cx, cy, r;
  @override
  Path toPath() =>
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
}

class ArtRect extends ArtShape {
  const ArtRect(
    this.x,
    this.y,
    this.w,
    this.h, {
    this.rx = 0,
    super.fill,
    super.stroke,
    super.strokeWidth,
    super.opacity,
    super.multiply,
  });
  final double x, y, w, h, rx;
  @override
  Path toPath() =>
      Path()
        ..addRRect(RRect.fromLTRBR(x, y, x + w, y + h, Radius.circular(rx)));
}

/// A small vector drawing in its own coordinate space (like an SVG viewBox).
class Artwork {
  const Artwork(this.viewBox, this.shapes);
  final Size viewBox;
  final List<ArtShape> shapes;
}

/// Paints an [Artwork], scaled into the available box.
class ArtView extends StatelessWidget {
  const ArtView(
    this.art, {
    super.key,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  final Artwork art;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ArtPainter(art, fit, alignment),
    child: const SizedBox.expand(),
  );
}

/// Paints [art] scaled into a box of [size] at the canvas origin.
void paintArtwork(
  Canvas canvas,
  Artwork art,
  Size size, {
  BoxFit fit = BoxFit.contain,
  Alignment alignment = Alignment.center,
}) {
  final fitted = applyBoxFit(fit, art.viewBox, size);
  final dst = alignment.inscribe(fitted.destination, Offset.zero & size);
  final scale = dst.width / art.viewBox.width;
  canvas.save();
  canvas.clipRect(Offset.zero & size);
  canvas.translate(dst.left, dst.top);
  canvas.scale(scale);
  for (final s in art.shapes) {
    final path = s.toPath();
    final blend = s.multiply ? BlendMode.multiply : BlendMode.srcOver;
    if (s.fill != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = s.fill!.withValues(alpha: s.opacity)
          ..blendMode = blend,
      );
    }
    if (s.stroke != null) {
      final paint = Paint()
        ..color = s.stroke!.withValues(alpha: s.opacity)
        ..blendMode = blend
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(s.dash == null ? path : _dashed(path, s.dash!), paint);
    }
  }
  canvas.restore();
}

Path _dashed(Path source, List<double> pattern) {
  final out = Path();
  for (final metric in source.computeMetrics()) {
    var d = 0.0;
    var i = 0;
    while (d < metric.length) {
      final len = pattern[i % pattern.length];
      if (i.isEven) out.addPath(metric.extractPath(d, d + len), Offset.zero);
      d += len;
      i++;
    }
  }
  return out;
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art, this.fit, this.alignment);

  final Artwork art;
  final BoxFit fit;
  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) =>
      paintArtwork(canvas, art, size, fit: fit, alignment: alignment);

  @override
  bool shouldRepaint(_ArtPainter old) => old.art != art || old.fit != fit;
}
