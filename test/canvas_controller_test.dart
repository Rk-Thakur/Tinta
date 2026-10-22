import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tinta/data/models.dart';
import 'package:tinta/drawing/brushes.dart';
import 'package:tinta/drawing/canvas_controller.dart';
import 'package:tinta/drawing/stroke.dart';

CanvasController _controller({
  bool riso = false,
  List<List<PageLayer>>? commits,
}) => CanvasController(
  layers: SketchPage.defaultLayers,
  pageSize: const Size(400, 565),
  riso: riso,
  ink: const Color(0xFF17171C),
  onCommit: commits?.add,
);

void _draw(CanvasController c, List<Offset> pts) {
  c.pointerDown(pts.first);
  for (final p in pts.skip(1)) {
    c.pointerMove(p);
  }
  c.pointerUp();
}

void main() {
  test('a stroke commits to the active layer and reports the change', () {
    final commits = <List<PageLayer>>[];
    final c = _controller(commits: commits);
    _draw(c, const [Offset(10, 10), Offset(50, 50), Offset(90, 20)]);

    expect(c.layers.single.strokes, hasLength(1));
    final s = c.layers.single.strokes.single;
    expect(s.brush, BrushKind.pencil);
    expect(s.points, hasLength(3));
    expect(s.points.last.t, greaterThanOrEqualTo(s.points.first.t));
    expect(commits, hasLength(1));
    expect(c.canUndo, isTrue);
  });

  test('undo and redo walk the history; a new stroke clears redo', () {
    final c = _controller();
    _draw(c, const [Offset(0, 0), Offset(10, 10)]);
    _draw(c, const [Offset(20, 20), Offset(30, 30)]);

    c.undo();
    expect(c.layers.single.strokes, hasLength(1));
    expect(c.canRedo, isTrue);
    c.redo();
    expect(c.layers.single.strokes, hasLength(2));

    c.undo();
    _draw(c, const [Offset(40, 40), Offset(50, 50)]);
    expect(c.canRedo, isFalse);
    expect(c.layers.single.strokes, hasLength(2));
  });

  test('cancel drops the stroke in progress', () {
    final c = _controller();
    c.pointerDown(const Offset(5, 5));
    c.pointerMove(const Offset(25, 25));
    expect(c.liveStroke, isNotNull);
    c.cancel();
    c.pointerUp();
    expect(c.layers.single.strokes, isEmpty);
    expect(c.canUndo, isFalse);
  });

  test('riso mode multiplies ink but never the eraser', () {
    final c = _controller(riso: true);
    _draw(c, const [Offset(0, 0), Offset(10, 10)]);
    c.tool = CanvasTool.eraser;
    _draw(c, const [Offset(0, 0), Offset(10, 10)]);
    final strokes = c.layers.single.strokes;
    expect(strokes[0].multiply, isTrue);
    expect(strokes[1].brush, BrushKind.eraser);
    expect(strokes[1].multiply, isFalse);
  });

  test('size is per tool and clamped', () {
    final c = _controller();
    c.size = 500;
    expect(c.size, CanvasController.maxSize);
    c.tool = CanvasTool.marker;
    expect(c.size, isNot(CanvasController.maxSize));
  });

  test(
    'lasso selects enclosed strokes, drags them, and the move is undoable',
    () {
      final c = _controller();
      _draw(c, const [
        Offset(100, 100),
        Offset(120, 110),
        Offset(140, 100),
      ]); // inside
      _draw(c, const [Offset(300, 300), Offset(320, 310)]); // outside

      c.tool = CanvasTool.lasso;
      _draw(c, const [
        Offset(80, 80),
        Offset(160, 80),
        Offset(160, 140),
        Offset(80, 140),
      ]);
      expect(c.selection, hasLength(1));

      final before = c.layers.single.strokes.first.points.first;
      c.pointerDown(const Offset(110, 105));
      c.pointerMove(const Offset(160, 155));
      c.pointerUp();
      final after = c.layers.single.strokes.first.points.first;
      expect(after.x - before.x, closeTo(50, 0.001));
      expect(after.y - before.y, closeTo(50, 0.001));
      expect(c.layers.single.strokes.last.points.first.x, 300); // untouched

      c.undo();
      expect(c.layers.single.strokes.first.points.first.x, before.x);
    },
  );

  test('deleting a lasso selection removes only those strokes', () {
    final c = _controller();
    _draw(c, const [Offset(10, 10), Offset(20, 20)]);
    _draw(c, const [Offset(200, 200), Offset(210, 210)]);
    c.tool = CanvasTool.lasso;
    _draw(c, const [
      Offset(0, 0),
      Offset(40, 0),
      Offset(40, 40),
      Offset(0, 40),
    ]);
    c.deleteSelection();
    expect(c.layers.single.strokes, hasLength(1));
    expect(c.layers.single.strokes.single.points.first.x, 200);
  });

  group('layers', () {
    test('add puts a new layer above the active one and selects it', () {
      final c = _controller();
      c.addLayer();
      expect(c.layers, hasLength(2));
      expect(c.activeLayer, 1);
      _draw(c, const [Offset(0, 0), Offset(10, 10)]);
      expect(c.layers[1].strokes, hasLength(1));
      expect(c.layers[0].strokes, isEmpty);
    });

    test('merge down bakes opacity and multiply into strokes', () {
      final c = _controller();
      _draw(c, const [Offset(0, 0), Offset(10, 10)]);
      c.addLayer();
      _draw(c, const [Offset(20, 20), Offset(30, 30)]);
      c.updateLayer(
        1,
        c.layers[1].copyWith(opacity: 0.5, blend: LayerBlend.multiply),
      );
      c.mergeDown(1);

      expect(c.layers, hasLength(1));
      expect(c.activeLayer, 0);
      final merged = c.layers.single.strokes;
      expect(merged, hasLength(2));
      expect(
        merged.last.opacity,
        closeTo(Brushes.hbPencil.opacity * 0.5, 1e-9),
      );
      expect(merged.last.multiply, isTrue);
      expect(merged.first.multiply, isFalse);

      c.undo();
      expect(c.layers, hasLength(2));
    });

    test('move keeps the active layer selected', () {
      final c = _controller();
      c.addLayer(); // index 1, active
      c.addLayer(); // index 2, active
      final activeId = c.layers[c.activeLayer].id;
      c.moveLayer(2, 0);
      expect(c.layers.first.id, activeId);
      expect(c.activeLayer, 0);
    });

    test(
      'duplicate copies strokes with fresh ids; last layer cannot be deleted',
      () {
        final c = _controller();
        _draw(c, const [Offset(0, 0), Offset(10, 10)]);
        c.duplicateLayer(0);
        expect(c.layers, hasLength(2));
        expect(c.layers[1].name, 'Line art copy');
        expect(
          c.layers[1].strokes.single.id,
          isNot(c.layers[0].strokes.single.id),
        );
        c.deleteLayer(1);
        c.deleteLayer(0);
        expect(c.layers, hasLength(1));
      },
    );

    test('slider previews make one undo step on commit', () {
      final c = _controller();
      c.previewLayer(0, c.layers[0].copyWith(opacity: 0.8));
      c.previewLayer(0, c.layers[0].copyWith(opacity: 0.4));
      expect(c.canUndo, isFalse);
      c.commitPending();
      expect(c.layers[0].opacity, 0.4);
      c.undo();
      expect(c.layers[0].opacity, 1);
      expect(c.canUndo, isFalse);
    });

    test('hidden layers are kept but flagged', () {
      final c = _controller();
      c.updateLayer(0, c.layers[0].copyWith(visible: false));
      expect(c.layers[0].visible, isFalse);
    });
  });

  group('brushes', () {
    test('selecting a preset loads it into its dock slot', () {
      final c = _controller();
      c.selectPreset(Brushes.wash);
      expect(c.tool, CanvasTool.marker);
      expect(c.size, Brushes.wash.size);
      expect(c.opacity, Brushes.wash.opacity);
      _draw(c, const [Offset(0, 0), Offset(10, 10)]);
      final s = c.layers.single.strokes.single;
      expect(s.presetId, Brushes.wash.id);
      expect(s.grain, Brushes.wash.grain);
      expect(s.preset.alwaysMultiply, isTrue);
    });

    test('settings are remembered per slot', () {
      final c = _controller();
      c.opacity = 0.5;
      c.grain = 0.7;
      c.smoothing = Smoothing.max;
      c.tool = CanvasTool.ink;
      expect(c.opacity, Brushes.brushPen.opacity);
      c.tool = CanvasTool.pencil;
      expect(c.opacity, 0.5);
      expect(c.grain, 0.7);
      expect(c.smoothing, Smoothing.max);
    });

    test('unknown preset ids fall back to the slot default', () {
      expect(Brushes.byId('gone', BrushKind.ink), Brushes.brushPen);
    });
  });

  group('riso inks', () {
    test('picking a color replaces the selected ink, keeping two', () {
      final saved = <List<Color>>[];
      final c = CanvasController(
        layers: SketchPage.defaultLayers,
        pageSize: const Size(400, 565),
        riso: true,
        ink: SketchPage.defaultRisoInks.first,
        risoInks: SketchPage.defaultRisoInks,
        onInksChanged: saved.add,
      );
      c.color = SketchPage.defaultRisoInks[1]; // select orange
      c.useColor(const Color(0xFF2E9E6A));
      expect(c.risoInks, [
        SketchPage.defaultRisoInks.first,
        const Color(0xFF2E9E6A),
      ]);
      expect(c.color, const Color(0xFF2E9E6A));
      expect(saved.single, hasLength(2));
    });

    test('choosing a palette on a riso page takes its first two colors', () {
      final saved = <List<Color>>[];
      final c = CanvasController(
        layers: SketchPage.defaultLayers,
        pageSize: const Size(400, 565),
        riso: true,
        ink: SketchPage.defaultRisoInks.first,
        risoInks: SketchPage.defaultRisoInks,
        onInksChanged: saved.add,
      );
      c.useRisoPalette(const [
        Color(0xFFFFD23F),
        Color(0xFF2E9E6A),
        Color(0xFFE8467C),
      ]);
      expect(c.risoInks, const [Color(0xFFFFD23F), Color(0xFF2E9E6A)]);
      expect(c.color, const Color(0xFFFFD23F));
      expect(saved, hasLength(1));

      c.useRisoPalette(const [Color(0xFF112233)]); // one color: first ink only
      expect(c.risoInks, const [Color(0xFF112233), Color(0xFF2E9E6A)]);
    });

    test('useRisoPalette does nothing on normal pages', () {
      final c = _controller();
      c.useRisoPalette(const [Color(0xFFFFD23F)]);
      expect(c.risoInks, isEmpty);
    });

    test('on normal pages useColor only sets the color', () {
      final c = _controller();
      c.useColor(const Color(0xFFE8467C));
      expect(c.risoInks, isEmpty);
      expect(c.color, const Color(0xFFE8467C));
    });
  });
}
