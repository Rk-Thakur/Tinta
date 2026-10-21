import 'dart:ui';

import 'brushes.dart';

/// Page coordinate space: every page is [pageWidth] units wide and its height
/// follows its aspect ratio. Strokes are stored in these units, so they render
/// the same at any zoom, in thumbnails and in exports.
const double pageWidth = 400;

enum BrushKind {
  pencil('Pencil'),
  ink('Ink brush'),
  marker('Marker'),
  eraser('Eraser');

  const BrushKind(this.label);
  final String label;
}

/// One sampled point. `t` is ms since the page was opened, kept for replay.
class StrokePoint {
  const StrokePoint(this.x, this.y, {this.pressure, this.t = 0});

  final double x;
  final double y;

  /// 0..1 from a stylus; null for finger input (pressure is simulated).
  final double? pressure;
  final int t;

  Offset get offset => Offset(x, y);

  StrokePoint translate(Offset d) =>
      StrokePoint(x + d.dx, y + d.dy, pressure: pressure, t: t);
}

class Stroke {
  const Stroke({
    required this.id,
    required this.brush,
    required this.color,
    required this.size,
    required this.points,
    this.opacity = 1,
    this.multiply = false,
    this.presetId,
    this.grain = 0,
    this.smoothing = Smoothing.soft,
  });

  final int id;
  final BrushKind brush;
  final Color color;
  final double size;
  final double opacity;

  /// Riso overprint: the stroke multiplies with what's beneath.
  final bool multiply;
  final List<StrokePoint> points;

  /// Brush preset this stroke was drawn with (shape parameters).
  final String? presetId;

  /// 0..1 paper-tooth texture.
  final double grain;
  final Smoothing smoothing;

  BrushPreset get preset => Brushes.byId(presetId, brush);

  Rect get bounds {
    var l = double.infinity,
        t = double.infinity,
        r = -double.infinity,
        b = -double.infinity;
    for (final p in points) {
      if (p.x < l) l = p.x;
      if (p.y < t) t = p.y;
      if (p.x > r) r = p.x;
      if (p.y > b) b = p.y;
    }
    return Rect.fromLTRB(l, t, r, b).inflate(size);
  }

  Stroke copyWith({int? id, double? opacity, bool? multiply}) => Stroke(
    id: id ?? this.id,
    brush: brush,
    color: color,
    size: size,
    opacity: opacity ?? this.opacity,
    multiply: multiply ?? this.multiply,
    presetId: presetId,
    grain: grain,
    smoothing: smoothing,
    points: points,
  );

  Stroke translated(Offset d) => Stroke(
    id: id,
    brush: brush,
    color: color,
    size: size,
    opacity: opacity,
    multiply: multiply,
    presetId: presetId,
    grain: grain,
    smoothing: smoothing,
    points: [for (final p in points) p.translate(d)],
  );
}

enum LayerBlend {
  normal('Normal', BlendMode.srcOver),
  multiply('Multiply', BlendMode.multiply),
  screen('Screen', BlendMode.screen),
  overlay('Overlay', BlendMode.overlay);

  const LayerBlend(this.label, this.mode);
  final String label;
  final BlendMode mode;
}

class PageLayer {
  const PageLayer({
    required this.id,
    required this.name,
    this.strokes = const [],
    this.blend = LayerBlend.normal,
    this.opacity = 1,
    this.visible = true,
  });

  final String id;
  final String name;
  final List<Stroke> strokes;
  final LayerBlend blend;
  final double opacity;
  final bool visible;

  PageLayer copyWith({
    String? name,
    List<Stroke>? strokes,
    LayerBlend? blend,
    double? opacity,
    bool? visible,
  }) => PageLayer(
    id: id,
    name: name ?? this.name,
    strokes: strokes ?? this.strokes,
    blend: blend ?? this.blend,
    opacity: opacity ?? this.opacity,
    visible: visible ?? this.visible,
  );
}
