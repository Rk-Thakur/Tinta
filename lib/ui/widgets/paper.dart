import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../drawing/stroke_renderer.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../art.dart';

/// A sheet of paper: base color plus its texture (dot grid, cold-press tooth).
class PaperSurface extends StatelessWidget {
  const PaperSurface({super.key, required this.paper, this.child});

  final PaperType paper;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PaperPainter(paper),
      child: child ?? const SizedBox.expand(),
    );
  }
}

/// Paints a sheet of [paper] filling [size]: base color plus texture.
void paintPaper(Canvas canvas, Size size, PaperType paper) {
  canvas.drawRect(Offset.zero & size, Paint()..color = paper.color);
  switch (paper) {
    case PaperType.dotGrid:
      _dots(
        canvas,
        size,
        spacing: 12,
        radius: 1.2,
        color: TintaColors.studioMuted,
      );
    case PaperType.coldPress:
      _dots(
        canvas,
        size,
        spacing: 5,
        radius: 1,
        color: const Color(0xFFE2DCCD),
      );
    default:
      break;
  }
}

void _dots(
  Canvas canvas,
  Size size, {
  required double spacing,
  required double radius,
  required Color color,
}) {
  final points = <Offset>[];
  final offset = spacing / 2;
  for (var y = offset; y < size.height; y += spacing) {
    for (var x = offset; x < size.width; x += spacing) {
      points.add(Offset(x, y));
    }
  }
  // One draw call for the whole texture.
  canvas.drawPoints(
    PointMode.points,
    points,
    Paint()
      ..color = color
      ..strokeWidth = radius * 2
      ..strokeCap = StrokeCap.round,
  );
}

class _PaperPainter extends CustomPainter {
  _PaperPainter(this.paper);

  final PaperType paper;

  @override
  void paint(Canvas canvas, Size size) => paintPaper(canvas, size, paper);

  @override
  bool shouldRepaint(_PaperPainter old) => old.paper != paper;
}

/// Page thumbnail as it sits in a sketchbook: paper, art, a hint of page stack.
class PageThumb extends StatelessWidget {
  const PageThumb({super.key, required this.page, this.height});

  final SketchPage page;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(4),
          right: Radius.circular(14),
        ),
        boxShadow: [BoxShadow(color: TintaColors.line, offset: Offset(3, 3))],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(4),
          right: Radius.circular(14),
        ),
        child: PagePreview(page: page),
      ),
    );
  }
}

/// Book cover drawn at the design's 124×164 and scaled to fit.
class SketchbookCover extends StatelessWidget {
  const SketchbookCover({
    super.key,
    required this.cover,
    this.width = 124,
    this.title,
  });

  final CoverDesign cover;
  final double width;

  /// Shown on wordmark covers that have no fixed text.
  final String? title;

  static const _base = Size(124, 164);

  @override
  Widget build(BuildContext context) {
    final dark = cover.color.computeLuminance() < 0.05;
    return SizedBox(
      width: width,
      height: width * _base.height / _base.width,
      child: FittedBox(
        child: SizedBox.fromSize(
          size: _base,
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(6),
              right: Radius.circular(16),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: cover.color)),
                // Spine shading.
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 8,
                  child: ColoredBox(
                    color: dark
                        ? const Color(0x14FFFFFF)
                        : const Color(0x2E000000),
                  ),
                ),
                // Elastic band.
                Positioned(
                  right: 18,
                  top: 0,
                  bottom: 0,
                  width: 8,
                  child: ColoredBox(color: cover.band),
                ),
                ..._motif(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _motif() {
    return switch (cover.motif) {
      CoverMotif.dot => [
        Positioned(
          left: 20,
          top: 22,
          width: 70,
          height: 70,
          child: ArtView(
            Artwork(const Size(70, 70), [
              ArtCircle(30, 30, 22, fill: cover.motifColor, opacity: 0.9),
            ]),
          ),
        ),
      ],
      CoverMotif.mountains => [
        Positioned(
          left: 16,
          top: 30,
          width: 80,
          height: 60,
          child: ArtView(
            Artwork(const Size(80, 60), [
              ArtPath('M4 50L28 14l16 22 10-12 22 26z', fill: cover.motifColor),
            ]),
          ),
        ),
      ],
      CoverMotif.wordmark => [
        Positioned(
          left: 18,
          top: 24,
          child: Text(
            cover.wordmark ?? _wordmarkFrom(title),
            style: TintaType.display(
              22,
              color: cover.motifColor,
            ).copyWith(height: 1, letterSpacing: -0.5),
          ),
        ),
      ],
    };
  }
}

/// A page's paper, imported art and strokes, scaled to fit. Used for
/// thumbnails everywhere.
class PagePreview extends StatelessWidget {
  const PagePreview({super.key, required this.page, this.showPaper = true});

  final SketchPage page;
  final bool showPaper;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PreviewPainter(page, showPaper),
    child: const SizedBox.expand(),
  );
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.page, this.showPaper);

  final SketchPage page;
  final bool showPaper;

  @override
  void paint(Canvas canvas, Size size) {
    if (showPaper) paintPaper(canvas, size, page.paper);
    final fitted = applyBoxFit(BoxFit.contain, page.size, size).destination;
    final dst = Alignment.center.inscribe(fitted, Offset.zero & size);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(dst.left, dst.top);
    canvas.scale(dst.width / page.size.width);
    StrokeRenderer.paintLayers(canvas, page.size, page.layers);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.page != page || old.showPaper != showPaper;
}

/// "Summer Sketches" → "summer\nsketches" (two short lines for the cover).
String _wordmarkFrom(String? title) {
  final words = (title ?? '')
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  if (words.length == 1) {
    return words.first.length > 6
        ? '${words.first.substring(0, 4)}\n${words.first.substring(4)}'
        : words.first;
  }
  return '${words.first}\n${words.skip(1).take(2).join(' ')}';
}

/// Covers offered when making a sketchbook. Wordmark covers print the title.
const coverPresets = <CoverDesign>[
  CoverDesign(
    color: TintaColors.risoBlue,
    band: TintaColors.studioInk,
    motif: CoverMotif.dot,
  ),
  CoverDesign(
    color: TintaColors.fluoroOrange,
    band: TintaColors.studioInk,
    motif: CoverMotif.mountains,
    motifColor: TintaColors.studioInk,
  ),
  CoverDesign(
    color: TintaColors.studioInk,
    band: TintaColors.sun,
    motif: CoverMotif.wordmark,
    motifColor: TintaColors.newsprint,
  ),
  CoverDesign(
    color: TintaColors.sun,
    band: TintaColors.risoBlue,
    motif: CoverMotif.dot,
    motifColor: TintaColors.risoBlue,
  ),
  CoverDesign(
    color: TintaColors.overprintViolet,
    band: TintaColors.fluoroOrange,
    motif: CoverMotif.mountains,
    motifColor: TintaColors.sun,
  ),
  CoverDesign(
    color: Color(0xFF2E9E6A),
    band: TintaColors.studioInk,
    motif: CoverMotif.wordmark,
    motifColor: TintaColors.newsprint,
  ),
];
