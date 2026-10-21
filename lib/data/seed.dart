import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import '../ui/art.dart';
import 'models.dart';

/// Sample content matching the design kit; written to the device on first launch.
abstract final class SeedArt {
  static const figure = Artwork(Size(160, 196), [
    ArtPath(
      'M40 150c0-40 20-70 40-70s40 30 40 70',
      stroke: TintaColors.studioInk,
      strokeWidth: 2.5,
    ),
    ArtCircle(80, 62, 22, stroke: TintaColors.studioInk, strokeWidth: 2.5),
    ArtPath('M30 160h100', stroke: TintaColors.risoBlue, strokeWidth: 6),
  ]);

  static const mug = Artwork(Size(160, 196), [
    ArtRect(30, 70, 100, 70, rx: 6, fill: TintaColors.fluoroOrange),
    ArtPath(
      'M40 70c0-30 80-30 80 0',
      stroke: TintaColors.studioInk,
      strokeWidth: 3,
    ),
    ArtPath('M60 100h40', stroke: TintaColors.studioInk, strokeWidth: 3),
  ]);

  static const wave = Artwork(Size(160, 120), [
    ArtPath(
      'M10 90c30-10 40-60 70-50s30 40 70 20',
      stroke: TintaColors.risoBlue,
      strokeWidth: 3,
    ),
  ]);

  static const swoop = Artwork(Size(170, 104), [
    ArtPath(
      'M20 80c20-50 40-50 60-20s40 20 70-40',
      stroke: TintaColors.risoBlue,
      strokeWidth: 4,
    ),
    ArtCircle(130, 30, 10, fill: TintaColors.fluoroOrange),
  ]);

  static const overprint = Artwork(Size(170, 104), [
    ArtRect(30, 20, 60, 60, fill: TintaColors.sun),
    ArtRect(
      70,
      40,
      60,
      44,
      fill: TintaColors.risoBlue,
      opacity: 0.85,
      multiply: true,
    ),
  ]);

  static const _cycle = [figure, mug, wave, swoop, overprint];

  /// Stable keys so saved pages can refer to their sample art.
  static const byKey = {
    'figure': figure,
    'mug': mug,
    'wave': wave,
    'swoop': swoop,
    'overprint': overprint,
  };

  static String? keyOf(Artwork? art) {
    if (art == null) return null;
    for (final e in byKey.entries) {
      if (identical(e.value, art)) return e.key;
    }
    return null;
  }
}

List<SketchPage> _pages(
  String bookId,
  int count,
  PaperType paper,
  Map<int, (String?, Artwork)> named,
) {
  return [
    for (var n = count; n >= 1; n--)
      SketchPage(
        id: '$bookId-p$n',
        number: n,
        title: named[n]?.$1,
        paper: paper,
        art: named[n]?.$2 ?? SeedArt._cycle[n % SeedArt._cycle.length],
      ),
  ];
}

final seedSketchbooks = <Sketchbook>[
  Sketchbook(
    id: 'morning',
    title: 'Morning studies',
    cover: const CoverDesign(
      color: TintaColors.risoBlue,
      band: TintaColors.studioInk,
      motif: CoverMotif.dot,
    ),
    paper: PaperType.toned,
    format: PageFormat.a5,
    pages: _pages('morning', 14, PaperType.toned, {
      14: ('Figure, 2 min', SeedArt.figure),
      13: ('Coffee mug', SeedArt.mug),
      12: (null, SeedArt.wave),
    }),
    timeDrawn: const Duration(hours: 2, minutes: 40),
    streakDays: 6,
  ),
  Sketchbook(
    id: 'travel',
    title: 'Travel journal',
    cover: const CoverDesign(
      color: TintaColors.fluoroOrange,
      band: TintaColors.studioInk,
      motif: CoverMotif.mountains,
      motifColor: TintaColors.studioInk,
    ),
    paper: PaperType.coldPress,
    format: PageFormat.a5,
    pages: _pages('travel', 32, PaperType.coldPress, const {}),
    timeDrawn: const Duration(hours: 7, minutes: 15),
    streakDays: 0,
  ),
  Sketchbook(
    id: 'inktober',
    title: 'Inktober',
    cover: const CoverDesign(
      color: TintaColors.studioInk,
      band: TintaColors.sun,
      motif: CoverMotif.wordmark,
      motifColor: TintaColors.newsprint,
      wordmark: 'ink\ntober',
    ),
    paper: PaperType.smooth,
    format: PageFormat.square,
    pages: _pages('inktober', 21, PaperType.smooth, const {}),
    timeDrawn: const Duration(hours: 5, minutes: 5),
    streakDays: 21,
  ),
];

const seedLoosePages = <SketchPage>[
  SketchPage(
    id: 'loose-1',
    number: 1,
    paper: PaperType.smooth,
    art: SeedArt.swoop,
    aspect: 104 / 170,
  ),
  SketchPage(
    id: 'loose-2',
    number: 2,
    paper: PaperType.smooth,
    art: SeedArt.overprint,
    aspect: 104 / 170,
    riso: true,
  ),
];

const seedPrompt = DailyPrompt(
  text: 'Draw your keys without lifting the pen.',
  minutes: 3,
);
