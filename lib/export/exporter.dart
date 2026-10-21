import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/models.dart';
import '../drawing/replay.dart';
import '../drawing/stroke.dart';
import 'render.dart';

enum ExportFormat {
  png('PNG', 'Image', 'png'),
  pdf('PDF', 'Print', 'pdf'),
  psd('PSD', 'Layers', 'psd'),
  mp4('MP4', 'Replay', 'mp4'),
  riso('Riso separations', 'One sheet per ink, print‑ready', 'pdf');

  const ExportFormat(this.label, this.subtitle, this.extension);
  final String label;
  final String subtitle;
  final String extension;

  /// Formats the Photos app can hold.
  bool get photosCompatible => this == png || this == mp4;
}

class ExportCancelled implements Exception {}

/// Turns pages into files in [dir]. Everything happens on device.
class Exporter {
  Exporter(this.dir);

  final Directory dir;
  static const _video = MethodChannel('tinta/video');

  bool _cancelled = false;
  void cancel() => _cancelled = true;

  String _fileName(SketchPage page, String ext, {String? suffix}) {
    final base = (page.title?.trim().isNotEmpty ?? false)
        ? page.title!.trim()
        : 'Page ${page.number}';
    final slug = base
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
    return 'tinta-${slug.isEmpty ? 'page' : slug}${suffix == null ? '' : '-$suffix'}-$stamp.$ext';
  }

  Future<File> _write(String name, List<int> bytes) async {
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  Future<File> png(
    SketchPage page, {
    double scale = 2,
    bool transparent = false,
  }) async {
    final image = await renderPage(
      page,
      exportSize(page, scale),
      paper: !transparent,
    );
    final bytes = await encodePng(image);
    image.dispose();
    return _write(_fileName(page, 'png'), bytes);
  }

  Future<File> pdf(SketchPage page, {double scale = 2}) async {
    final image = await renderPage(page, exportSize(page, scale));
    final bytes = await encodePng(image);
    image.dispose();
    final doc = pw.Document(
      title: page.title ?? 'Tinta page',
      creator: 'Tinta',
    );
    final format = PdfPageFormat(
      PdfPageFormat.a4.width,
      PdfPageFormat.a4.width * page.aspect,
    );
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.fill),
      ),
    );
    return _write(_fileName(page, 'pdf'), await doc.save());
  }

  /// Layered Photoshop file: paper, imported art and every Tinta layer.
  Future<File> psd(
    SketchPage page, {
    double scale = 2,
    bool transparent = false,
  }) async {
    final size = exportSize(page, scale);
    final w = size.width.round();
    final h = size.height.round();

    Future<Uint8List> pixels(ui.Picture picture) async {
      final img = await picture.toImage(w, h);
      final data = await straightRgba(img);
      img.dispose();
      return data;
    }

    final layers = <PsdLayer>[];
    if (!transparent) {
      layers.add(
        PsdLayer(
          name: 'Paper · ${page.paper.label}',
          rgba: await pixels(recordPage(page, size, layers: const [])),
        ),
      );
    }
    for (final l in page.layers) {
      final solo = l.copyWith(
        visible: true,
        opacity: 1,
        blend: LayerBlend.normal,
      );
      layers.add(
        PsdLayer(
          name: l.name,
          rgba: await pixels(
            recordPage(page, size, paper: false, layers: [solo]),
          ),
          blend: l.blend,
          opacity: l.opacity,
          visible: l.visible,
        ),
      );
    }
    final composite = await pixels(recordPage(page, size, paper: !transparent));
    final bytes = writePsd(
      width: w,
      height: h,
      layers: layers,
      composite: composite,
    );
    return _write(_fileName(page, 'psd'), bytes);
  }

  /// Print masters: one PDF page per ink, that ink in black on white.
  Future<File> riso(SketchPage page, {double scale = 2}) async {
    final inks = pageInks(page);
    if (inks.isEmpty) {
      throw StateError('Nothing to separate yet: this page has no ink.');
    }
    final size = exportSize(page, scale);
    final doc = pw.Document(
      title: '${page.title ?? 'Tinta page'} · separations',
      creator: 'Tinta',
    );
    final format = PdfPageFormat(
      PdfPageFormat.a4.width,
      PdfPageFormat.a4.width * page.aspect + 28,
    );
    for (var i = 0; i < inks.length; i++) {
      final sep = separationFor(page, inks[i]);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        Offset.zero & size,
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      canvas.drawPicture(recordPage(sep, size, paper: false));
      final image = await recorder.endRecording().toImage(
        size.width.round(),
        size.height.round(),
      );
      final bytes = await encodePng(image);
      image.dispose();
      final hex =
          '#${inks[i].toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Column(
            children: [
              pw.Expanded(
                child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.fill),
              ),
              pw.Container(
                height: 28,
                padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Ink ${i + 1} of ${inks.length} · $hex · ${page.title ?? 'Tinta page'}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _write(
      _fileName(page, 'pdf', suffix: 'separations'),
      await doc.save(),
    );
  }

  /// Replay video. [speed] multiplies drawing speed; long replays are sped up
  /// so the video stays under [maxSeconds].
  Future<File> mp4(
    List<SketchPage> pages, {
    required SketchPage titlePage,
    double scale = 1,
    double speed = 4,
    int fps = 30,
    int maxSeconds = 60,
    void Function(double progress)? onProgress,
  }) async {
    final timeline = ReplayTimeline(pages);
    if (timeline.isEmpty) {
      throw StateError('Nothing to replay yet: draw on this page first.');
    }
    _cancelled = false;

    final totalMs = timeline.duration.inMilliseconds;
    final effectiveSpeed = math.max(speed, totalMs / 1000 / maxSeconds);
    final drawFrames = (totalMs / effectiveSpeed / 1000 * fps).ceil();
    final frames = drawFrames + fps; // hold the finished page for a second

    // H.264 wants dimensions in multiples of 16.
    int even16(double v) => math.max(16, (v / 16).round() * 16);
    final width = even16(720 * scale.clamp(1, 2));
    final aspect = pages.first.aspect;
    final height = even16(width * aspect);
    final size = Size(width.toDouble(), height.toDouble());

    final file = File(
      '${dir.path}/${_fileName(titlePage, 'mp4', suffix: 'replay')}',
    );
    await _video.invokeMethod('start', {
      'path': file.path,
      'width': width,
      'height': height,
      'fps': fps,
    });
    try {
      for (var f = 0; f < frames; f++) {
        if (_cancelled) throw ExportCancelled();
        final ms = math.min(totalMs, (f * 1000 / fps * effectiveSpeed).round());
        final frame = timeline.frameAt(ms);
        final page = pages[frame.pageIndex];
        final picture = recordPage(
          page,
          size,
          layers: frame.layers,
          live: frame.live,
          liveLayer: frame.liveLayer,
        );
        final image = await picture.toImage(width, height);
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        image.dispose();
        await _video.invokeMethod('frame', {'rgba': rgba});
        onProgress?.call((f + 1) / frames);
      }
      await _video.invokeMethod('finish');
    } catch (e) {
      await _video.invokeMethod('cancel').catchError((_) => null);
      if (await file.exists()) await file.delete();
      rethrow;
    }
    return file;
  }
}

/// Whether a page has anything to replay.
bool hasReplay(List<SketchPage> pages) => pages.any(
  (p) => p.layers.any(
    (l) => l.strokes.any(
      (s) => s.points.isNotEmpty && s.brush != BrushKind.eraser,
    ),
  ),
);
