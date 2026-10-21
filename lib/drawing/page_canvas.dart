import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../data/models.dart';
import '../theme/tokens.dart';
import '../ui/art.dart';
import '../ui/widgets/paper.dart';
import 'canvas_controller.dart';
import 'stroke_renderer.dart';

/// The drawable page: fits the sheet into the available space, turns pointer
/// input into strokes, and handles two-finger pan / pinch / tap-to-undo.
///
/// Once an Apple Pencil (or any stylus) is seen, fingers only navigate, so a
/// resting palm never draws.
class PageCanvas extends StatefulWidget {
  const PageCanvas({
    super.key,
    required this.controller,
    required this.paper,
    this.art,
    this.padding = const EdgeInsets.all(20),
    this.twoFingerUndo = true,
  });

  final CanvasController controller;
  final PaperType paper;
  final Artwork? art;
  final EdgeInsets padding;
  final bool twoFingerUndo;

  @override
  State<PageCanvas> createState() => _PageCanvasState();
}

class _PageCanvasState extends State<PageCanvas> {
  // View transform: screen = origin + page * scale.
  Offset _origin = Offset.zero;
  double _scale = 1;
  double _fitScale = 1;
  Size? _fittedFor;

  final Map<int, Offset> _touches = {};
  int? _drawingPointer;
  bool _stylusMode = false;
  DateTime? _strokeStarted;

  // Two-finger navigation.
  double _startScale = 1;
  Offset _startOrigin = Offset.zero;
  Offset _startFocal = Offset.zero;
  double _startSpan = 1;
  DateTime? _multiStart;
  double _multiTravel = 0;

  CanvasController get _c => widget.controller;
  Size get _page => _c.pageSize;

  void _fit(Size box) {
    final avail = widget.padding.deflateSize(box);
    _fitScale = math.min(
      avail.width / _page.width,
      avail.height / _page.height,
    );
    _scale = _fitScale;
    final drawn = _page * _scale;
    _origin = Offset(
      widget.padding.left + (avail.width - drawn.width) / 2,
      widget.padding.top + (avail.height - drawn.height) / 2,
    );
    _fittedFor = box;
  }

  Offset _toPage(Offset local) => (local - _origin) / _scale;

  double? _pressure(PointerEvent e) {
    if (e.kind != PointerDeviceKind.stylus &&
        e.kind != PointerDeviceKind.invertedStylus) {
      return null;
    }
    final range = e.pressureMax - e.pressureMin;
    if (range <= 0) return null;
    return ((e.pressure - e.pressureMin) / range).clamp(0.0, 1.0);
  }

  bool _isStylus(PointerEvent e) =>
      e.kind == PointerDeviceKind.stylus ||
      e.kind == PointerDeviceKind.invertedStylus;

  /// Eyedropper: renders the page around [p] into a single pixel and reads it.
  Future<void> _sample(Offset p) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(-p.dx, -p.dy);
    paintPaper(canvas, _page, widget.paper);
    if (widget.art != null) paintArtwork(canvas, widget.art!, _page);
    StrokeRenderer.paintLayers(canvas, _page, _c.layers);
    final image = recorder.endRecording().toImageSync(1, 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (!mounted || data == null) return;
    final color = Color.fromARGB(
      255,
      data.getUint8(0),
      data.getUint8(1),
      data.getUint8(2),
    );
    _c.picking = false;
    _c.useColor(color);
  }

  void _down(PointerDownEvent e) {
    if (_c.picking) {
      _sample(_toPage(e.localPosition));
      return;
    }
    if (_isStylus(e)) {
      _stylusMode = true;
      if (_drawingPointer != null) return;
      _drawingPointer = e.pointer;
      _strokeStarted = DateTime.now();
      _c.pointerDown(_toPage(e.localPosition), pressure: _pressure(e));
      return;
    }

    _touches[e.pointer] = e.localPosition;
    if (_touches.length == 1 && !_stylusMode && _drawingPointer == null) {
      _drawingPointer = e.pointer;
      _strokeStarted = DateTime.now();
      _c.pointerDown(_toPage(e.localPosition));
      return;
    }
    if (_touches.length == 2) {
      // A second finger means navigation, not drawing.
      if (_drawingPointer != null && !_stylusMode) {
        final quick =
            _strokeStarted != null &&
            DateTime.now().difference(_strokeStarted!).inMilliseconds < 300;
        quick ? _c.cancel() : _c.pointerUp();
        _drawingPointer = null;
      }
      _beginNavigation();
    }
  }

  void _beginNavigation() {
    final pts = _touches.values.toList();
    _startFocal = (pts[0] + pts[1]) / 2;
    _startSpan = math.max((pts[0] - pts[1]).distance, 1);
    _startScale = _scale;
    _startOrigin = _origin;
    _multiStart = DateTime.now();
    _multiTravel = 0;
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer == _drawingPointer) {
      _c.pointerMove(_toPage(e.localPosition), pressure: _pressure(e));
      return;
    }
    if (!_touches.containsKey(e.pointer)) return;
    _multiTravel += e.delta.distance;
    _touches[e.pointer] = e.localPosition;

    if (_touches.length >= 2) {
      final pts = _touches.values.take(2).toList();
      final focal = (pts[0] + pts[1]) / 2;
      final span = math.max((pts[0] - pts[1]).distance, 1);
      final next = (_startScale * span / _startSpan).clamp(
        _fitScale * 0.5,
        _fitScale * 8,
      );
      final anchor = (_startFocal - _startOrigin) / _startScale;
      setState(() {
        _scale = next;
        _origin = focal - anchor * next;
      });
    } else if (_touches.length == 1 && _stylusMode) {
      // With a stylus around, one finger pans.
      setState(() => _origin += e.delta);
    }
  }

  void _up(PointerEvent e, {bool cancelled = false}) {
    if (e.pointer == _drawingPointer) {
      _drawingPointer = null;
      cancelled ? _c.cancel() : _c.pointerUp();
    }
    if (_touches.remove(e.pointer) == null) return;

    if (_multiStart != null && _touches.isEmpty) {
      final quick =
          DateTime.now().difference(_multiStart!).inMilliseconds < 250;
      if (!cancelled && quick && _multiTravel < 20 && widget.twoFingerUndo) {
        _c.undo();
      }
      _multiStart = null;
    } else if (_touches.length == 2) {
      _beginNavigation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest;
        if (_fittedFor != box) _fit(box);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: (e) => _up(e, cancelled: true),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: _PaperLayer(
                    origin: _origin,
                    scale: _scale,
                    page: _page,
                    paper: widget.paper,
                    art: widget.art,
                  ),
                ),
              ),
              RepaintBoundary(
                child: CustomPaint(
                  painter: _InkLayer(
                    controller: _c,
                    origin: _origin,
                    scale: _scale,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PaperLayer extends CustomPainter {
  _PaperLayer({
    required this.origin,
    required this.scale,
    required this.page,
    required this.paper,
    this.art,
  });

  final Offset origin;
  final double scale;
  final Size page;
  final PaperType paper;
  final Artwork? art;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = origin & (page * scale);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawShadow(
      Path()..addRRect(rrect),
      const Color(0xFF000000),
      18,
      false,
    );
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    paintPaper(canvas, page, paper);
    if (art != null) paintArtwork(canvas, art!, page);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PaperLayer old) =>
      old.origin != origin ||
      old.scale != scale ||
      old.paper != paper ||
      old.art != art ||
      old.page != page;
}

class _InkLayer extends CustomPainter {
  _InkLayer({
    required this.controller,
    required this.origin,
    required this.scale,
  }) : super(repaint: controller.repaint);

  final CanvasController controller;
  final Offset origin;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final c = controller;
    final page = c.pageSize;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        origin & (page * scale),
        const Radius.circular(6),
      ),
    );
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);

    final selected = c.selection;
    StrokeRenderer.paintLayers(
      canvas,
      page,
      c.layers,
      live: c.liveStroke,
      liveLayer: c.activeLayer,
      hidden: selected,
      lifted: selected.isEmpty ? const [] : c.selectedStrokes,
      liftedOffset: c.dragOffset,
    );
    canvas.restore();

    // Lasso and selection chrome are drawn in screen space so they stay crisp.
    final lasso = c.lassoPath;
    if (lasso != null && lasso.length > 1) {
      final path = Path()
        ..addPolygon([for (final p in lasso) origin + p * scale], false);
      _dashed(canvas, path, TintaColors.risoBlue);
    }
    final bounds = c.selectionBounds;
    if (bounds != null) {
      final r = Rect.fromPoints(
        origin + bounds.topLeft * scale,
        origin + bounds.bottomRight * scale,
      );
      _dashed(
        canvas,
        Path()..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(8))),
        TintaColors.risoBlue,
      );
    }
  }

  void _dashed(Canvas canvas, Path path, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_InkLayer old) =>
      old.origin != origin ||
      old.scale != scale ||
      old.controller != controller;
}
