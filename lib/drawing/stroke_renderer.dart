import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:perfect_freehand/perfect_freehand.dart' as pf;

import 'stroke.dart';

/// Turns strokes into filled outline paths and paints them.
abstract final class StrokeRenderer {
  static final _pathCache = Expando<Path>('strokePath');
  static final _pictureCache = Expando<ui.Picture>('layerPicture');

  static pf.StrokeOptions _options(Stroke s, {bool complete = true}) {
    final preset = s.preset;
    final simulate = s.points.isEmpty || s.points.first.pressure == null;
    final uniform = s.brush == BrushKind.eraser || preset.thinning == 0;
    return pf.StrokeOptions(
      size: s.size,
      thinning: s.brush == BrushKind.eraser ? 0 : preset.thinning,
      smoothing: s.smoothing.smoothing,
      streamline: s.smoothing.streamline,
      simulatePressure: simulate && !uniform,
      start: preset.taperStart > 0
          ? pf.StrokeEndOptions.start(
              taperEnabled: true,
              customTaper: s.size * preset.taperStart,
            )
          : null,
      end: preset.taperEnd > 0
          ? pf.StrokeEndOptions.end(
              taperEnabled: true,
              customTaper: s.size * preset.taperEnd,
            )
          : null,
      isComplete: complete,
    );
  }

  static Path _buildPath(Stroke s, {bool complete = true}) {
    final outline = pf.getStroke([
      for (final p in s.points) pf.PointVector(p.x, p.y, p.pressure),
    ], options: _options(s, complete: complete));
    final path = Path();
    if (outline.isEmpty) return path;
    if (outline.length < 3) {
      return path
        ..addOval(Rect.fromCircle(center: outline.first, radius: s.size / 2));
    }
    // Quadratic curves through midpoints give a smooth outline.
    path.moveTo(outline.first.dx, outline.first.dy);
    for (var i = 0; i < outline.length - 1; i++) {
      final p0 = outline[i];
      final p1 = outline[i + 1];
      path.quadraticBezierTo(
        p0.dx,
        p0.dy,
        (p0.dx + p1.dx) / 2,
        (p0.dy + p1.dy) / 2,
      );
    }
    return path..close();
  }

  /// Outline path; cached for committed strokes (they're immutable).
  static Path pathOf(Stroke s, {bool live = false}) {
    if (live) return _buildPath(s, complete: false);
    return _pathCache[s] ??= _buildPath(s);
  }

  static BlendMode _blend(Stroke s) {
    if (s.brush == BrushKind.eraser) return BlendMode.clear;
    if (s.multiply || s.preset.alwaysMultiply) return BlendMode.multiply;
    return BlendMode.srcOver;
  }

  static Paint paintOf(Stroke s) => Paint()
    ..isAntiAlias = true
    ..color = s.color.withValues(
      alpha: s.brush == BrushKind.eraser ? 1 : s.opacity,
    )
    ..blendMode = _blend(s);

  static void paintStroke(Canvas canvas, Stroke s, {bool live = false}) {
    final path = pathOf(s, live: live);
    if (s.grain <= 0 || s.brush == BrushKind.eraser) {
      canvas.drawPath(path, paintOf(s));
      return;
    }
    // Grain: draw the stroke opaque in its own layer, knock paper tooth out
    // of it, then composite with the stroke's opacity and blend mode.
    final bounds = path.getBounds().inflate(2);
    canvas.saveLayer(
      bounds,
      Paint()
        ..blendMode = _blend(s)
        ..color = Color.fromRGBO(0, 0, 0, s.opacity),
    );
    canvas.drawPath(path, Paint()..color = s.color.withValues(alpha: 1));
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = _grainShader
        ..blendMode = BlendMode.dstOut
        ..color = Color.fromRGBO(0, 0, 0, s.grain.clamp(0.0, 1.0)),
    );
    canvas.restore();
  }

  static final _identity = Float64List.fromList([
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
  ]);

  /// Tiling paper-tooth noise, fixed to page space so it reads as paper.
  static final ui.ImageShader _grainShader = () {
    const tile = 64;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rng = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 900; i++) {
      paint.color = Color.fromRGBO(0, 0, 0, 0.35 + rng.nextDouble() * 0.65);
      final r = 0.4 + rng.nextDouble() * 0.9;
      canvas.drawCircle(
        Offset(rng.nextDouble() * tile, rng.nextDouble() * tile),
        r,
        paint,
      );
    }
    final image = recorder.endRecording().toImageSync(tile, tile);
    return ui.ImageShader(
      image,
      TileMode.repeated,
      TileMode.repeated,
      _identity,
    );
  }();

  /// A recorded picture of a layer's strokes, cached per strokes list.
  static ui.Picture layerPicture(List<Stroke> strokes) {
    return _pictureCache[strokes] ??= () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (final s in strokes) {
        paintStroke(canvas, s);
      }
      return recorder.endRecording();
    }();
  }

  /// Paints every visible layer in page units. Each layer gets its own
  /// compositing layer so the eraser only clears that layer's ink, and the
  /// layer's blend mode applies to the paper and layers beneath it.
  static void paintLayers(
    Canvas canvas,
    Size pageSize,
    List<PageLayer> layers, {
    Stroke? live,
    int liveLayer = -1,
    Set<int> hidden = const {},
    Offset liftedOffset = Offset.zero,
    List<Stroke> lifted = const [],
  }) {
    final bounds = Offset.zero & pageSize;
    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i];
      if (!layer.visible) continue;
      canvas.saveLayer(
        bounds,
        Paint()
          ..blendMode = layer.blend.mode
          ..color = Color.fromRGBO(0, 0, 0, layer.opacity),
      );
      if (hidden.isEmpty) {
        canvas.drawPicture(layerPicture(layer.strokes));
      } else {
        for (final s in layer.strokes) {
          if (!hidden.contains(s.id)) paintStroke(canvas, s);
        }
      }
      if (i == liveLayer) {
        if (lifted.isNotEmpty) {
          canvas.save();
          canvas.translate(liftedOffset.dx, liftedOffset.dy);
          for (final s in lifted) {
            paintStroke(canvas, s);
          }
          canvas.restore();
        }
        if (live != null) paintStroke(canvas, live, live: true);
      }
      canvas.restore();
    }
  }
}
