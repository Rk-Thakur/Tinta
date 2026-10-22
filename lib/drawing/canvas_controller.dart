import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'brushes.dart';
import 'stroke.dart';

enum CanvasTool {
  pencil('Pencil', BrushKind.pencil),
  ink('Ink brush', BrushKind.ink),
  marker('Marker', BrushKind.marker),
  eraser('Eraser', BrushKind.eraser),
  lasso('Lasso', null);

  const CanvasTool(this.label, this.brush);
  final String label;
  final BrushKind? brush;
}

/// Brush settings remembered per dock slot.
class ToolSettings {
  ToolSettings.fromPreset(BrushPreset p)
    : presetId = p.id,
      size = p.size,
      opacity = p.opacity,
      grain = p.grain,
      smoothing = p.smoothing;

  String presetId;
  double size;
  double opacity;
  double grain;
  Smoothing smoothing;
}

/// State of one open page: layers, current tool, the stroke in progress,
/// lasso selection, and undo/redo history.
class CanvasController extends ChangeNotifier {
  CanvasController({
    required List<PageLayer> layers,
    required this.pageSize,
    required this.riso,
    required Color ink,
    List<Color> risoInks = const [],
    this.onCommit,
    this.onInksChanged,
  }) : _layers = layers,
       _activeLayer = layers.length - 1,
       _color = ink,
       _risoInks = List.of(risoInks) {
    var maxId = 0;
    var maxT = 0;
    for (final l in layers) {
      for (final s in l.strokes) {
        maxId = math.max(maxId, s.id);
        if (s.points.isNotEmpty) maxT = math.max(maxT, s.points.last.t);
      }
    }
    _nextStrokeId = maxId + 1;
    // Keep replay time monotonic across editing sessions.
    _timeBase = maxT == 0 ? 0 : maxT + 500;
    _clock.start();
  }

  final Size pageSize;
  final bool riso;

  /// Called with the new layers after every committed change.
  final ValueChanged<List<PageLayer>>? onCommit;

  /// Called when a riso page's two inks change.
  final ValueChanged<List<Color>>? onInksChanged;

  static const maxHistory = 100;
  static const minSize = 1.0;
  static const maxSize = 60.0;

  List<PageLayer> _layers;
  int _activeLayer;
  CanvasTool _tool = CanvasTool.pencil;
  Color _color;
  final Map<CanvasTool, ToolSettings> _settings = {
    CanvasTool.pencil: ToolSettings.fromPreset(Brushes.hbPencil),
    CanvasTool.ink: ToolSettings.fromPreset(Brushes.brushPen),
    CanvasTool.marker: ToolSettings.fromPreset(Brushes.marker),
    CanvasTool.eraser: ToolSettings.fromPreset(Brushes.eraser),
  };
  final List<Color> _risoInks;
  bool _picking = false;

  final List<List<PageLayer>> _undo = [];
  final List<List<PageLayer>> _redo = [];

  late int _nextStrokeId;
  late int _timeBase;
  final _clock = Stopwatch();

  List<StrokePoint>? _livePoints;

  // Lasso.
  final _repaint = _Ticker();

  /// Fires on every live point; listen to this plus the controller to paint.
  Listenable get repaint => Listenable.merge([this, _repaint]);

  List<Offset>? _lassoPath;
  Set<int> _selection = {};
  Offset _dragOffset = Offset.zero;
  Offset? _dragStart;

  @override
  void dispose() {
    _repaint.dispose();
    super.dispose();
  }

  // ---- Read-only state -----------------------------------------------------

  List<PageLayer> get layers => _layers;
  int get activeLayer => _activeLayer;
  CanvasTool get tool => _tool;
  Color get color => _color;

  /// Settings of the current tool (the pencil's while lassoing).
  ToolSettings get settings =>
      _settings[_tool] ?? _settings[CanvasTool.pencil]!;
  double get size => settings.size;
  double get opacity => settings.opacity;
  double get grain => settings.grain;
  Smoothing get smoothing => settings.smoothing;
  BrushPreset get preset =>
      Brushes.byId(settings.presetId, _tool.brush ?? BrushKind.pencil);

  /// The two inks of a riso page (empty otherwise).
  List<Color> get risoInks => List.unmodifiable(_risoInks);

  /// Eyedropper mode: the next touch on the page samples a color.
  bool get picking => _picking;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// A pen or finger is laying down ink right now (not lasso, not pinch).
  bool get isInking => _livePoints != null;

  bool get isDrawing =>
      _livePoints != null || _lassoPath != null || _dragStart != null;

  List<Offset>? get lassoPath => _lassoPath;
  Set<int> get selection => _selection;
  Offset get dragOffset => _dragOffset;

  List<Stroke> get selectedStrokes => [
    for (final s in _layers[_activeLayer].strokes)
      if (_selection.contains(s.id)) s,
  ];

  Rect? get selectionBounds {
    final strokes = selectedStrokes;
    if (strokes.isEmpty) return null;
    return strokes
        .map((s) => s.bounds)
        .reduce((a, b) => a.expandToInclude(b))
        .shift(_dragOffset);
  }

  /// The stroke being drawn right now, in page units.
  Stroke? get liveStroke {
    final pts = _livePoints;
    final brush = _tool.brush;
    if (pts == null || brush == null) return null;
    return _makeStroke(brush, pts, id: -1);
  }

  // ---- Settings ------------------------------------------------------------

  set tool(CanvasTool t) {
    if (t == _tool) return;
    _clearSelection();
    _tool = t;
    notifyListeners();
  }

  set color(Color c) {
    _color = c;
    if (_tool == CanvasTool.eraser || _tool == CanvasTool.lasso) {
      _tool = CanvasTool.pencil;
    }
    notifyListeners();
  }

  set size(double v) {
    if (_tool == CanvasTool.lasso) return;
    settings.size = v.clamp(minSize, maxSize);
    notifyListeners();
  }

  set opacity(double v) {
    settings.opacity = v.clamp(0.05, 1.0);
    notifyListeners();
  }

  set grain(double v) {
    settings.grain = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  set smoothing(Smoothing v) {
    settings.smoothing = v;
    notifyListeners();
  }

  /// Loads a preset into its dock slot and switches to that slot.
  void selectPreset(BrushPreset p) {
    _clearSelection();
    final slot = CanvasTool.values.firstWhere((t) => t.brush == p.kind);
    _settings[slot] = ToolSettings.fromPreset(p);
    _tool = slot;
    notifyListeners();
  }

  /// On a riso page, swaps the selected ink for [c] (keeping two inks);
  /// elsewhere just sets the color.
  /// On a riso page, adopts a palette: its first two colors become the
  /// page's inks (a one-color palette replaces just the first ink).
  void useRisoPalette(List<Color> colors) {
    if (_risoInks.length != 2 || colors.isEmpty) return;
    _risoInks[0] = colors[0];
    if (colors.length > 1) _risoInks[1] = colors[1];
    onInksChanged?.call(List.unmodifiable(_risoInks));
    color = _risoInks[0];
  }

  void useColor(Color c) {
    if (_risoInks.length == 2) {
      final slot = _risoInks.indexOf(_color);
      _risoInks[slot < 0 ? 0 : slot] = c;
      onInksChanged?.call(List.unmodifiable(_risoInks));
    }
    color = c;
  }

  set picking(bool v) {
    _picking = v;
    notifyListeners();
  }

  set activeLayer(int i) {
    _clearSelection();
    _activeLayer = i.clamp(0, _layers.length - 1);
    notifyListeners();
  }

  // ---- Pointer input (page units) -----------------------------------------

  int get _now => _timeBase + _clock.elapsedMilliseconds;

  void pointerDown(Offset p, {double? pressure}) {
    if (_tool == CanvasTool.lasso) {
      final bounds = selectionBounds;
      if (bounds != null && bounds.inflate(12).contains(p)) {
        _dragStart = p - _dragOffset;
      } else {
        _clearSelection();
        _lassoPath = [p];
      }
      notifyListeners();
      return;
    }
    _livePoints = [StrokePoint(p.dx, p.dy, pressure: pressure, t: _now)];
    notifyListeners();
  }

  void pointerMove(Offset p, {double? pressure}) {
    if (_dragStart != null) {
      _dragOffset = p - _dragStart!;
    } else if (_lassoPath != null) {
      _lassoPath!.add(p);
    } else if (_livePoints != null) {
      final last = _livePoints!.last;
      // Skip sub-pixel jitter.
      if ((Offset(last.x, last.y) - p).distanceSquared < 0.25) return;
      _livePoints!.add(StrokePoint(p.dx, p.dy, pressure: pressure, t: _now));
    } else {
      return;
    }
    // Live updates only repaint the ink; chrome doesn't need to rebuild.
    _repaint.tick();
  }

  void pointerUp() {
    if (_dragStart != null) {
      _dragStart = null;
      _commitMove();
      return;
    }
    if (_lassoPath != null) {
      _finishLasso();
      return;
    }
    final pts = _livePoints;
    final brush = _tool.brush;
    _livePoints = null;
    if (pts == null || brush == null) return;
    final stroke = _makeStroke(brush, pts, id: _nextStrokeId++);
    final layer = _layers[_activeLayer];
    _commit(
      _replaceLayer(
        _activeLayer,
        layer.copyWith(strokes: [...layer.strokes, stroke]),
      ),
    );
  }

  /// Abandons the gesture in progress (e.g. a second finger landed).
  void cancel() {
    _livePoints = null;
    _lassoPath = null;
    if (_dragStart != null) {
      _dragStart = null;
      _dragOffset = Offset.zero;
    }
    notifyListeners();
  }

  // ---- History -------------------------------------------------------------

  void undo() {
    if (_undo.isEmpty) return;
    _clearSelection();
    _redo.add(_layers);
    _layers = _undo.removeLast();
    _activeLayer = _activeLayer.clamp(0, _layers.length - 1);
    notifyListeners();
    onCommit?.call(_layers);
  }

  void redo() {
    if (_redo.isEmpty) return;
    _clearSelection();
    _undo.add(_layers);
    _layers = _redo.removeLast();
    _activeLayer = _activeLayer.clamp(0, _layers.length - 1);
    notifyListeners();
    onCommit?.call(_layers);
  }

  /// Replaces all layers as one undoable step (used by the layers panel).
  void setLayers(List<PageLayer> layers, {int? active}) {
    _clearSelection();
    _activeLayer = (active ?? _activeLayer).clamp(0, layers.length - 1);
    _commit(layers);
  }

  // ---- Layers --------------------------------------------------------------

  int _layerCounter = 0;
  List<PageLayer>? _pendingSnapshot;

  String _newLayerId() =>
      'l${DateTime.now().microsecondsSinceEpoch}-${_layerCounter++}';

  /// Adds an empty layer above the active one and selects it.
  void addLayer() {
    final at = _activeLayer + 1;
    final layer = PageLayer(
      id: _newLayerId(),
      name: 'Layer ${_layers.length + 1}',
    );
    setLayers(List.of(_layers)..insert(at, layer), active: at);
  }

  void duplicateLayer(int i) {
    final src = _layers[i];
    final copy = src.copyWith(
      name: '${src.name} copy',
      strokes: [for (final s in src.strokes) s.copyWith(id: _nextStrokeId++)],
    );
    setLayers(
      List.of(_layers)..insert(
        i + 1,
        PageLayer(
          id: _newLayerId(),
          name: copy.name,
          strokes: copy.strokes,
          blend: copy.blend,
          opacity: copy.opacity,
          visible: copy.visible,
        ),
      ),
      active: i + 1,
    );
  }

  /// Deletes a layer; the last remaining layer is kept.
  void deleteLayer(int i) {
    if (_layers.length <= 1) return;
    setLayers(List.of(_layers)..removeAt(i), active: math.max(0, i - 1));
  }

  /// Folds layer [i] into the one below it. The upper layer's opacity and
  /// multiply blend are baked into its strokes so the result looks the same.
  void mergeDown(int i) {
    if (i <= 0 || i >= _layers.length) return;
    final upper = _layers[i];
    final lower = _layers[i - 1];
    final baked = [
      for (final s in upper.strokes)
        s.copyWith(
          opacity: s.opacity * upper.opacity,
          multiply: s.multiply || upper.blend == LayerBlend.multiply,
        ),
    ];
    final merged = lower.copyWith(strokes: [...lower.strokes, ...baked]);
    setLayers(
      List.of(_layers)
        ..[i - 1] = merged
        ..removeAt(i),
      active: i - 1,
    );
  }

  /// Moves a layer in the stack (indices bottom→top).
  void moveLayer(int from, int to) {
    if (from == to) return;
    final activeId = _layers[_activeLayer].id;
    final next = List.of(_layers);
    final layer = next.removeAt(from);
    next.insert(to.clamp(0, next.length), layer);
    setLayers(next, active: next.indexWhere((l) => l.id == activeId));
  }

  void updateLayer(int i, PageLayer layer) =>
      setLayers(_replaceLayer(i, layer), active: _activeLayer);

  /// Live change without a history entry (e.g. while dragging a slider);
  /// call [commitPending] when the gesture ends.
  void previewLayer(int i, PageLayer layer) {
    _pendingSnapshot ??= _layers;
    _layers = _replaceLayer(i, layer);
    notifyListeners();
  }

  void commitPending() {
    final snap = _pendingSnapshot;
    if (snap == null) return;
    _pendingSnapshot = null;
    _undo.add(snap);
    if (_undo.length > maxHistory) _undo.removeAt(0);
    _redo.clear();
    notifyListeners();
    onCommit?.call(_layers);
  }

  void deleteSelection() {
    if (_selection.isEmpty) return;
    final layer = _layers[_activeLayer];
    final ids = _selection;
    _selection = {};
    _dragOffset = Offset.zero;
    _commit(
      _replaceLayer(
        _activeLayer,
        layer.copyWith(
          strokes: [
            for (final s in layer.strokes)
              if (!ids.contains(s.id)) s,
          ],
        ),
      ),
    );
  }

  void clearSelection() {
    _clearSelection();
    notifyListeners();
  }

  // ---- Internals -----------------------------------------------------------

  Stroke _makeStroke(
    BrushKind brush,
    List<StrokePoint> pts, {
    required int id,
  }) => Stroke(
    id: id,
    brush: brush,
    color: _color,
    size: size,
    opacity: opacity,
    multiply: riso && brush != BrushKind.eraser,
    presetId: settings.presetId,
    grain: brush == BrushKind.eraser ? 0 : grain,
    smoothing: smoothing,
    points: List.unmodifiable(pts),
  );

  void _commit(List<PageLayer> next) {
    _undo.add(_layers);
    if (_undo.length > maxHistory) _undo.removeAt(0);
    _redo.clear();
    _layers = next;
    notifyListeners();
    onCommit?.call(_layers);
  }

  List<PageLayer> _replaceLayer(int i, PageLayer layer) =>
      List.of(_layers)..[i] = layer;

  void _clearSelection() {
    _selection = {};
    _dragOffset = Offset.zero;
    _lassoPath = null;
    _dragStart = null;
  }

  void _finishLasso() {
    final pts = _lassoPath!;
    _lassoPath = null;
    if (pts.length < 3) {
      notifyListeners();
      return;
    }
    final region = Path()..addPolygon(pts, true);
    final picked = <int>{};
    for (final s in _layers[_activeLayer].strokes) {
      if (s.brush == BrushKind.eraser || s.points.isEmpty) continue;
      final inside = s.points.where((p) => region.contains(p.offset)).length;
      if (inside >= s.points.length * 0.6) picked.add(s.id);
    }
    _selection = picked;
    _dragOffset = Offset.zero;
    notifyListeners();
  }

  void _commitMove() {
    final d = _dragOffset;
    if (d.distance < 0.5 || _selection.isEmpty) {
      _dragOffset = Offset.zero;
      notifyListeners();
      return;
    }
    final layer = _layers[_activeLayer];
    final moved = [
      for (final s in layer.strokes)
        _selection.contains(s.id) ? s.translated(d) : s,
    ];
    _dragOffset = Offset.zero;
    _commit(_replaceLayer(_activeLayer, layer.copyWith(strokes: moved)));
  }
}

class _Ticker extends ChangeNotifier {
  void tick() => notifyListeners();
}
