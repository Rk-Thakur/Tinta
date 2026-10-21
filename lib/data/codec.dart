import 'dart:ui';

import '../drawing/brushes.dart';
import '../drawing/stroke.dart';
import 'models.dart';

/// JSON encoding for everything Tinta stores on device. Points are packed
/// into flat number lists to keep page files small.
abstract final class Codec {
  static const version = 1;

  static int _c(Color c) => c.toARGB32();
  static Color _color(Object? v) => Color((v as num).toInt());
  static double _r(double v) => (v * 100).roundToDouble() / 100;

  static T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  // ---- Strokes & layers ----------------------------------------------------

  static Map<String, Object?> stroke(Stroke s) {
    final hasPressure = s.points.any((p) => p.pressure != null);
    return {
      'id': s.id,
      'b': s.brush.name,
      'c': _c(s.color),
      's': _r(s.size),
      if (s.opacity != 1) 'o': _r(s.opacity),
      if (s.multiply) 'm': true,
      if (s.presetId != null) 'p': s.presetId,
      if (s.grain != 0) 'g': _r(s.grain),
      if (s.smoothing != Smoothing.soft) 'sm': s.smoothing.name,
      // x, y, t triples (or x, y, pressure, t quads when a stylus was used).
      'q': hasPressure,
      'pts': [
        for (final p in s.points) ...[
          _r(p.x),
          _r(p.y),
          if (hasPressure) _r(p.pressure ?? 0.5),
          p.t,
        ],
      ],
    };
  }

  static Stroke strokeFrom(Map<String, Object?> j) {
    final quad = j['q'] == true;
    final raw = (j['pts']! as List).cast<num>();
    final step = quad ? 4 : 3;
    final pts = <StrokePoint>[
      for (var i = 0; i + step - 1 < raw.length; i += step)
        StrokePoint(
          raw[i].toDouble(),
          raw[i + 1].toDouble(),
          pressure: quad ? raw[i + 2].toDouble() : null,
          t: raw[i + step - 1].toInt(),
        ),
    ];
    return Stroke(
      id: (j['id']! as num).toInt(),
      brush: _enum(BrushKind.values, j['b'], BrushKind.pencil),
      color: _color(j['c']),
      size: (j['s']! as num).toDouble(),
      opacity: (j['o'] as num?)?.toDouble() ?? 1,
      multiply: j['m'] == true,
      presetId: j['p'] as String?,
      grain: (j['g'] as num?)?.toDouble() ?? 0,
      smoothing: _enum(Smoothing.values, j['sm'], Smoothing.soft),
      points: List.unmodifiable(pts),
    );
  }

  static Map<String, Object?> layer(PageLayer l) => {
    'id': l.id,
    'name': l.name,
    'blend': l.blend.name,
    'opacity': _r(l.opacity),
    'visible': l.visible,
    'strokes': [for (final s in l.strokes) stroke(s)],
  };

  static PageLayer layerFrom(Map<String, Object?> j) => PageLayer(
    id: j['id']! as String,
    name: j['name']! as String,
    blend: _enum(LayerBlend.values, j['blend'], LayerBlend.normal),
    opacity: (j['opacity'] as num?)?.toDouble() ?? 1,
    visible: j['visible'] != false,
    strokes: [
      for (final s in (j['strokes'] as List? ?? const []))
        strokeFrom(s as Map<String, Object?>),
    ],
  );

  // ---- Pages & books -------------------------------------------------------

  static Map<String, Object?> page(SketchPage p) => {
    'v': version,
    'id': p.id,
    'number': p.number,
    if (p.title != null) 'title': p.title,
    'paper': p.paper.name,
    'aspect': p.aspect,
    'riso': p.riso,
    'inks': [for (final c in p.risoInks) _c(c)],
    if (p.drawnDays.isNotEmpty) 'days': p.drawnDays,
    'layers': [for (final l in p.layers) layer(l)],
  };

  static SketchPage pageFrom(Map<String, Object?> j) {
    final layers = [
      for (final l in (j['layers'] as List? ?? const []))
        layerFrom(l as Map<String, Object?>),
    ];
    final inks = [for (final c in (j['inks'] as List? ?? const [])) _color(c)];
    return SketchPage(
      id: j['id']! as String,
      number: (j['number']! as num).toInt(),
      title: j['title'] as String?,
      paper: _enum(PaperType.values, j['paper'], PaperType.smooth),
      aspect: (j['aspect'] as num?)?.toDouble() ?? 1.414,
      riso: j['riso'] == true,
      risoInks: inks.length == 2 ? inks : SketchPage.defaultRisoInks,
      drawnDays: [
        for (final d in (j['days'] as List? ?? const [])) d as String,
      ],
      layers: layers.isEmpty ? SketchPage.defaultLayers : layers,
    );
  }

  static Map<String, Object?> cover(CoverDesign c) => {
    'color': _c(c.color),
    'band': _c(c.band),
    'motif': c.motif.name,
    'motifColor': _c(c.motifColor),
    if (c.wordmark != null) 'wordmark': c.wordmark,
  };

  static CoverDesign coverFrom(Map<String, Object?> j) => CoverDesign(
    color: _color(j['color']),
    band: _color(j['band']),
    motif: _enum(CoverMotif.values, j['motif'], CoverMotif.dot),
    motifColor: _color(j['motifColor']),
    wordmark: j['wordmark'] as String?,
  );

  /// A sketchbook's metadata; its pages live in their own files.
  static Map<String, Object?> book(Sketchbook b) => {
    'id': b.id,
    'title': b.title,
    'cover': cover(b.cover),
    'paper': b.paper.name,
    'format': b.format.name,
    'pages': [for (final p in b.pages) p.id],
  };

  static Sketchbook bookFrom(Map<String, Object?> j, List<SketchPage> pages) =>
      Sketchbook(
        id: j['id']! as String,
        title: j['title']! as String,
        cover: coverFrom(j['cover']! as Map<String, Object?>),
        paper: _enum(PaperType.values, j['paper'], PaperType.smooth),
        format: _enum(PageFormat.values, j['format'], PageFormat.a5),
        pages: pages,
      );

  // ---- Brushes -------------------------------------------------------------

  static Map<String, Object?> preset(BrushPreset p) => {
    'id': p.id,
    'name': p.name,
    'category': p.category.name,
    'kind': p.kind.name,
    'size': p.size,
    'thinning': p.thinning,
    'taperStart': p.taperStart,
    'taperEnd': p.taperEnd,
    'opacity': p.opacity,
    'grain': p.grain,
    'smoothing': p.smoothing.name,
    'alwaysMultiply': p.alwaysMultiply,
  };

  static BrushPreset presetFrom(Map<String, Object?> j) => BrushPreset(
    id: j['id']! as String,
    name: j['name']! as String,
    category: _enum(BrushCategory.values, j['category'], BrushCategory.mine),
    kind: _enum(BrushKind.values, j['kind'], BrushKind.pencil),
    size: (j['size']! as num).toDouble(),
    thinning: (j['thinning'] as num?)?.toDouble() ?? 0.35,
    taperStart: (j['taperStart'] as num?)?.toDouble() ?? 0,
    taperEnd: (j['taperEnd'] as num?)?.toDouble() ?? 0,
    opacity: (j['opacity'] as num?)?.toDouble() ?? 1,
    grain: (j['grain'] as num?)?.toDouble() ?? 0,
    smoothing: _enum(Smoothing.values, j['smoothing'], Smoothing.soft),
    alwaysMultiply: j['alwaysMultiply'] == true,
  );

  static List<int> colors(List<Color> cs) => [for (final c in cs) _c(c)];
  static List<Color> colorsFrom(Object? v) => [
    for (final c in (v as List? ?? const [])) _color(c),
  ];
}
