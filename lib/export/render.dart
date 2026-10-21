import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../data/models.dart';
import '../drawing/stroke.dart';
import '../drawing/stroke_renderer.dart';
import '../ui/art.dart';
import '../ui/widgets/paper.dart';

/// Pixel size of a page export at [scale] (1× = 1024 px wide).
Size exportSize(SketchPage page, double scale) {
  final w = (1024 * scale).roundToDouble();
  return Size(w, (w * page.aspect).roundToDouble());
}

/// Records a page (or a subset of it) into a picture at [size] pixels.
ui.Picture recordPage(
  SketchPage page,
  Size size, {
  bool paper = true,
  bool art = true,
  List<PageLayer>? layers,
  Stroke? live,
  int liveLayer = -1,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  final scale = size.width / page.size.width;
  canvas.scale(scale);
  if (paper) paintPaper(canvas, page.size, page.paper);
  if (art && page.art != null) paintArtwork(canvas, page.art!, page.size);
  StrokeRenderer.paintLayers(
    canvas,
    page.size,
    layers ?? page.layers,
    live: live,
    liveLayer: liveLayer,
  );
  return recorder.endRecording();
}

Future<ui.Image> renderPage(SketchPage page, Size size, {bool paper = true}) =>
    recordPage(
      page,
      size,
      paper: paper,
    ).toImage(size.width.round(), size.height.round());

Future<Uint8List> encodePng(ui.Image image) async =>
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();

Future<Uint8List> straightRgba(ui.Image image) async =>
    (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer
        .asUint8List();

// ---- Riso separations -------------------------------------------------------

/// The inks a page prints with: its two riso inks, or the distinct stroke
/// colors of a normal page (most-used first, at most six).
List<Color> pageInks(SketchPage page) {
  if (page.riso) return page.risoInks;
  final counts = <int, int>{};
  for (final l in page.layers) {
    if (!l.visible) continue;
    for (final s in l.strokes) {
      if (s.brush == BrushKind.eraser) continue;
      counts.update(
        s.color.toARGB32(),
        (n) => n + s.points.length,
        ifAbsent: () => s.points.length,
      );
    }
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in sorted.take(6)) Color(e.key)];
}

/// One printing master per ink: that ink's strokes in black on white.
/// Erasers apply to every sheet; other inks are left out.
SketchPage separationFor(SketchPage page, Color ink) {
  final key = ink.toARGB32();
  return SketchPage(
    id: '${page.id}-sep-$key',
    number: page.number,
    // Exported on plain white (see Exporter); the paper type is unused.
    paper: PaperType.smooth,
    aspect: page.aspect,
    layers: [
      for (final l in page.layers)
        l.copyWith(
          blend: LayerBlend.normal,
          strokes: [
            for (final s in l.strokes)
              if (s.brush == BrushKind.eraser)
                s
              else if (s.color.toARGB32() == key)
                Stroke(
                  id: s.id,
                  brush: s.brush,
                  color: const Color(0xFF000000),
                  size: s.size,
                  opacity: s.opacity,
                  presetId: s.presetId,
                  grain: s.grain,
                  smoothing: s.smoothing,
                  points: s.points,
                ),
          ],
        ),
    ],
  );
}

// ---- PSD writer ---------------------------------------------------------------

class PsdLayer {
  PsdLayer({
    required this.name,
    required this.rgba,
    this.blend = LayerBlend.normal,
    this.opacity = 1,
    this.visible = true,
  });

  final String name;

  /// Straight (un-premultiplied) RGBA, full canvas size.
  final Uint8List rgba;
  final LayerBlend blend;
  final double opacity;
  final bool visible;
}

/// Minimal Photoshop writer: RGB, 8-bit, PackBits-compressed layers plus a
/// flattened composite. Layers are given bottom first.
Uint8List writePsd({
  required int width,
  required int height,
  required List<PsdLayer> layers,
  required Uint8List composite,
}) {
  final out = BytesBuilder(copy: false);
  final b = _Be(out);

  // Header.
  out.add(const [0x38, 0x42, 0x50, 0x53]); // 8BPS
  b.u16(1);
  out.add(Uint8List(6));
  b.u16(3); // channels in composite: R G B
  b.u32(height);
  b.u32(width);
  b.u16(8);
  b.u16(3); // RGB
  b.u32(0); // color mode data
  b.u32(0); // image resources

  // Layer records + channel data.
  final records = BytesBuilder(copy: false);
  final channelData = BytesBuilder(copy: false);
  final r = _Be(records);
  for (final layer in layers) {
    final channels = <int, Uint8List>{
      -1: _plane(layer.rgba, 3, width, height),
      0: _plane(layer.rgba, 0, width, height),
      1: _plane(layer.rgba, 1, width, height),
      2: _plane(layer.rgba, 2, width, height),
    };
    final encoded = {
      for (final e in channels.entries)
        e.key: _packChannel(e.value, width, height),
    };
    r.i32(0);
    r.i32(0);
    r.i32(height);
    r.i32(width);
    r.u16(4);
    for (final e in encoded.entries) {
      r.i16(e.key);
      r.u32(e.value.length);
    }
    records.add(const [0x38, 0x42, 0x49, 0x4D]); // 8BIM
    records.add(switch (layer.blend) {
      LayerBlend.normal => 'norm'.codeUnits,
      LayerBlend.multiply => 'mul '.codeUnits,
      LayerBlend.screen => 'scrn'.codeUnits,
      LayerBlend.overlay => 'over'.codeUnits,
    });
    records.addByte((layer.opacity * 255).round().clamp(0, 255));
    records.addByte(0); // clipping
    records.addByte(layer.visible ? 0 : 2); // flags: bit 1 = hidden
    records.addByte(0);
    final name = _pascal(layer.name);
    r.u32(4 + 4 + name.length);
    r.u32(0); // mask data
    r.u32(0); // blending ranges
    records.add(name);
    for (final data in encoded.values) {
      channelData.add(data);
    }
  }

  final layerInfo = BytesBuilder(copy: false);
  final li = _Be(layerInfo);
  li.i16(layers.length);
  layerInfo.add(records.takeBytes());
  layerInfo.add(channelData.takeBytes());
  if (layerInfo.length.isOdd) layerInfo.addByte(0);
  final layerInfoBytes = layerInfo.takeBytes();

  b.u32(4 + layerInfoBytes.length + 4); // layer and mask section
  b.u32(layerInfoBytes.length);
  out.add(layerInfoBytes);
  b.u32(0); // global layer mask

  // Composite image: RLE, all row counts first, then rows, planar R G B.
  final planes = [
    for (var c = 0; c < 3; c++) _plane(composite, c, width, height),
  ];
  final rows = [for (final p in planes) _packRows(p, width, height)];
  b.u16(1);
  for (final rs in rows) {
    for (final row in rs) {
      b.u16(row.length);
    }
  }
  for (final rs in rows) {
    for (final row in rs) {
      out.add(row);
    }
  }
  return out.takeBytes();
}

Uint8List _plane(Uint8List rgba, int channel, int width, int height) {
  final plane = Uint8List(width * height);
  for (var i = 0, j = channel; i < plane.length; i++, j += 4) {
    plane[i] = rgba[j];
  }
  return plane;
}

/// Channel data for a layer: compression flag, row byte counts, rows.
Uint8List _packChannel(Uint8List plane, int width, int height) {
  final rows = _packRows(plane, width, height);
  final out = BytesBuilder(copy: false);
  final b = _Be(out);
  b.u16(1);
  for (final row in rows) {
    b.u16(row.length);
  }
  for (final row in rows) {
    out.add(row);
  }
  return out.takeBytes();
}

List<Uint8List> _packRows(Uint8List plane, int width, int height) => [
  for (var y = 0; y < height; y++)
    packBits(Uint8List.sublistView(plane, y * width, (y + 1) * width)),
];

/// Apple PackBits run-length encoding, as used by PSD.
Uint8List packBits(Uint8List data) {
  final out = BytesBuilder(copy: false);
  var i = 0;
  while (i < data.length) {
    // Run of identical bytes?
    var run = 1;
    while (i + run < data.length && run < 128 && data[i + run] == data[i]) {
      run++;
    }
    if (run >= 2) {
      out.addByte(257 - run); // -(run - 1) as a signed byte
      out.addByte(data[i]);
      i += run;
      continue;
    }
    // Literal run until the next repeat (or 128 bytes).
    final start = i;
    while (i < data.length &&
        i - start < 128 &&
        !(i + 1 < data.length && data[i] == data[i + 1])) {
      i++;
    }
    if (i == start) i++; // single byte before a repeat
    out.addByte(i - start - 1);
    out.add(Uint8List.sublistView(data, start, i));
  }
  return out.takeBytes();
}

Uint8List _pascal(String name) {
  final bytes = name.codeUnits.where((c) => c < 128).take(255).toList();
  final total = ((bytes.length + 1 + 3) ~/ 4) * 4;
  final out = Uint8List(total);
  out[0] = bytes.length;
  out.setRange(1, 1 + bytes.length, bytes);
  return out;
}

/// Big-endian writer. Each value is added as its own small list, because
/// BytesBuilder(copy: false) keeps references to what it is given.
class _Be {
  _Be(this.out);
  final BytesBuilder out;

  void _put(int bytes, void Function(ByteData) write) {
    final d = ByteData(bytes);
    write(d);
    out.add(d.buffer.asUint8List());
  }

  void u16(int v) => _put(2, (d) => d.setUint16(0, v));
  void i16(int v) => _put(2, (d) => d.setInt16(0, v));
  void u32(int v) => _put(4, (d) => d.setUint32(0, v));
  void i32(int v) => _put(4, (d) => d.setInt32(0, v));
}
