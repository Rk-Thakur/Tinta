import 'stroke.dart';

enum BrushCategory {
  sketch('Sketch'),
  ink('Ink'),
  paint('Paint'),
  riso('Riso grain'),
  mine('Mine');

  const BrushCategory(this.label);
  final String label;
}

enum Smoothing {
  off('Off', 0.15, 0.25),
  soft('Soft', 0.5, 0.5),
  max('Max', 0.8, 0.7);

  const Smoothing(this.label, this.streamline, this.smoothing);
  final String label;

  /// perfect_freehand parameters.
  final double streamline;
  final double smoothing;
}

/// A brush's shape and defaults. Strokes reference a preset by [id], so the
/// ids are stable and stored with every stroke.
class BrushPreset {
  const BrushPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.kind,
    required this.size,
    this.thinning = 0.35,
    this.taperStart = 0,
    this.taperEnd = 0,
    this.opacity = 1,
    this.grain = 0,
    this.smoothing = Smoothing.soft,
    this.alwaysMultiply = false,
  });

  final String id;
  final String name;
  final BrushCategory category;

  /// Which dock slot the preset lives in.
  final BrushKind kind;
  final double size;

  /// How much pressure/speed narrows the line (0 = uniform).
  final double thinning;

  /// Taper length as a multiple of size; 0 = round cap.
  final double taperStart;
  final double taperEnd;
  final double opacity;

  /// 0..1: how much paper tooth breaks up the stroke.
  final double grain;
  final Smoothing smoothing;

  /// Translucent media (marker, wash) always overprint.
  final bool alwaysMultiply;

  BrushPreset copyAsMine({
    required String id,
    required double size,
    required double opacity,
    required double grain,
    required Smoothing smoothing,
  }) => BrushPreset(
    id: id,
    name: name,
    category: BrushCategory.mine,
    kind: kind,
    size: size,
    thinning: thinning,
    taperStart: taperStart,
    taperEnd: taperEnd,
    opacity: opacity,
    grain: grain,
    smoothing: smoothing,
    alwaysMultiply: alwaysMultiply,
  );
}

abstract final class Brushes {
  static const hbPencil = BrushPreset(
    id: 'hb-pencil',
    name: 'HB pencil',
    category: BrushCategory.sketch,
    kind: BrushKind.pencil,
    size: 3,
    opacity: 0.92,
    grain: 0.25,
  );
  static const charcoal = BrushPreset(
    id: '6b-charcoal',
    name: '6B charcoal',
    category: BrushCategory.sketch,
    kind: BrushKind.pencil,
    size: 10,
    thinning: 0.2,
    opacity: 0.85,
    grain: 0.6,
  );
  static const fineliner = BrushPreset(
    id: 'fineliner',
    name: 'Fineliner',
    category: BrushCategory.sketch,
    kind: BrushKind.pencil,
    size: 2.4,
    thinning: 0.05,
  );
  static const brushPen = BrushPreset(
    id: 'brush-pen',
    name: 'Brush pen',
    category: BrushCategory.ink,
    kind: BrushKind.ink,
    size: 8,
    thinning: 0.75,
    taperStart: 2,
    taperEnd: 3,
    smoothing: Smoothing.max,
  );
  static const dipPen = BrushPreset(
    id: 'dip-pen',
    name: 'Dip pen',
    category: BrushCategory.ink,
    kind: BrushKind.ink,
    size: 4,
    thinning: 0.9,
    taperEnd: 4,
  );
  static const marker = BrushPreset(
    id: 'marker',
    name: 'Marker',
    category: BrushCategory.ink,
    kind: BrushKind.marker,
    size: 20,
    thinning: 0,
    opacity: 0.6,
    smoothing: Smoothing.max,
    alwaysMultiply: true,
  );
  static const gouache = BrushPreset(
    id: 'gouache',
    name: 'Gouache',
    category: BrushCategory.paint,
    kind: BrushKind.ink,
    size: 18,
    thinning: 0.15,
    taperEnd: 1,
    opacity: 0.95,
    grain: 0.15,
  );
  static const wash = BrushPreset(
    id: 'wash',
    name: 'Watercolor wash',
    category: BrushCategory.paint,
    kind: BrushKind.marker,
    size: 40,
    thinning: 0.2,
    opacity: 0.35,
    grain: 0.3,
    smoothing: Smoothing.max,
    alwaysMultiply: true,
  );
  static const risoCrayon = BrushPreset(
    id: 'riso-crayon',
    name: 'Riso crayon',
    category: BrushCategory.riso,
    kind: BrushKind.pencil,
    size: 9,
    thinning: 0.1,
    opacity: 0.9,
    grain: 0.75,
    alwaysMultiply: true,
  );
  static const risoFill = BrushPreset(
    id: 'riso-fill',
    name: 'Riso flood',
    category: BrushCategory.riso,
    kind: BrushKind.marker,
    size: 36,
    thinning: 0,
    opacity: 0.85,
    grain: 0.45,
    alwaysMultiply: true,
  );
  static const eraser = BrushPreset(
    id: 'eraser',
    name: 'Eraser',
    category: BrushCategory.sketch,
    kind: BrushKind.eraser,
    size: 28,
    thinning: 0,
  );

  static const builtIn = [
    hbPencil,
    charcoal,
    fineliner,
    brushPen,
    dipPen,
    marker,
    gouache,
    wash,
    risoCrayon,
    risoFill,
  ];

  static final Map<String, BrushPreset> _custom = {};

  /// Registers a user brush ("Mine") so strokes can resolve it.
  static void register(BrushPreset preset) => _custom[preset.id] = preset;

  static BrushPreset byId(String? id, BrushKind kind) {
    if (id != null) {
      for (final b in builtIn) {
        if (b.id == id) return b;
      }
      final custom = _custom[id];
      if (custom != null) return custom;
    }
    return defaultFor(kind);
  }

  static BrushPreset defaultFor(BrushKind kind) => switch (kind) {
    BrushKind.pencil => hbPencil,
    BrushKind.ink => brushPen,
    BrushKind.marker => marker,
    BrushKind.eraser => eraser,
  };
}
