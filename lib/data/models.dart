import 'package:flutter/widgets.dart';

import '../drawing/stroke.dart';
import '../theme/tokens.dart';
import '../ui/art.dart';

enum PaperType {
  smooth('Smooth', TintaColors.paperSmooth),
  coldPress('Cold‑press', Color(0xFFF7F3EA)),
  toned('Toned', TintaColors.paperToned),
  kraft('Kraft', TintaColors.paperKraft),
  dotGrid('Dot grid', TintaColors.surface),
  night('Night', TintaColors.studioInk);

  const PaperType(this.label, this.color);
  final String label;
  final Color color;
}

enum PageFormat {
  screen('Screen', null),
  square('Square', 1),
  a5('A5', 1.414),
  a4('A4', 1.414),
  custom('Custom', null);

  const PageFormat(this.label, this.aspect);
  final String label;

  /// Height / width; null when it depends on the device or the user.
  final double? aspect;
}

extension PaperTone on PaperType {
  bool get isDark => this == PaperType.night;

  /// Default ink that reads on this paper.
  Color get defaultInk =>
      isDark ? TintaColors.newsprint : TintaColors.studioInk;
}

enum CoverMotif { dot, mountains, wordmark }

/// How a sketchbook's cover looks: base color, elastic band, and a motif.
class CoverDesign {
  const CoverDesign({
    required this.color,
    required this.band,
    required this.motif,
    this.motifColor = TintaColors.fluoroOrange,
    this.wordmark,
  });

  final Color color;
  final Color band;
  final CoverMotif motif;
  final Color motifColor;
  final String? wordmark;
}

class SketchPage {
  const SketchPage({
    required this.id,
    required this.number,
    this.title,
    required this.paper,
    this.art,
    this.aspect = 1.414,
    this.riso = false,
    this.layers = defaultLayers,
    this.risoInks = defaultRisoInks,
  });

  static const defaultRisoInks = [
    TintaColors.risoBlue,
    TintaColors.fluoroOrange,
  ];

  static const defaultLayers = [PageLayer(id: 'l1', name: 'Line art')];

  final String id;
  final int number;
  final String? title;
  final PaperType paper;

  /// Imported artwork shown beneath the layers (sample pages use it).
  final Artwork? art;

  /// Height / width.
  final double aspect;

  /// Riso mode: two inks that overprint (multiply).
  final bool riso;
  final List<PageLayer> layers;

  /// The two inks a riso page prints with.
  final List<Color> risoInks;

  Size get size => Size(pageWidth, pageWidth * aspect);

  bool get isBlank => art == null && layers.every((l) => l.strokes.isEmpty);

  SketchPage copyWith({
    String? title,
    List<PageLayer>? layers,
    int? number,
    List<Color>? risoInks,
  }) => SketchPage(
    id: id,
    number: number ?? this.number,
    title: title ?? this.title,
    paper: paper,
    art: art,
    aspect: aspect,
    riso: riso,
    layers: layers ?? this.layers,
    risoInks: risoInks ?? this.risoInks,
  );
}

class Sketchbook {
  const Sketchbook({
    required this.id,
    required this.title,
    required this.cover,
    required this.paper,
    required this.format,
    required this.pages,
    this.timeDrawn = Duration.zero,
    this.streakDays = 0,
  });

  final String id;
  final String title;
  final CoverDesign cover;
  final PaperType paper;
  final PageFormat format;

  /// Newest first.
  final List<SketchPage> pages;
  final Duration timeDrawn;
  final int streakDays;

  int get pageCount => pages.length;

  Sketchbook copyWith({
    List<SketchPage>? pages,
    String? title,
    CoverDesign? cover,
  }) => Sketchbook(
    id: id,
    title: title ?? this.title,
    cover: cover ?? this.cover,
    paper: paper,
    format: format,
    pages: pages ?? this.pages,
    timeDrawn: timeDrawn,
    streakDays: streakDays,
  );
}

class DailyPrompt {
  const DailyPrompt({required this.text, required this.minutes});
  final String text;
  final int minutes;
}
