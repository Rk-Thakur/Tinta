import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/widgets.dart';

import '../drawing/stroke.dart';
import '../theme/tokens.dart';

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

/// Cover patterns. Stored by name, so only ever append new ones.
enum CoverMotif { dot, mountains, wordmark, stripes, waves, grid, arch, checks }

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
    this.aspect = 1.414,
    this.riso = false,
    this.layers = defaultLayers,
    this.risoInks = defaultRisoInks,
    this.drawnDays = const [],
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

  /// Height / width.
  final double aspect;

  /// Riso mode: two inks that overprint (multiply).
  final bool riso;
  final List<PageLayer> layers;

  /// The two inks a riso page prints with.
  final List<Color> risoInks;

  /// Local calendar days ("2026-10-21") on which this page was drawn on.
  final List<String> drawnDays;

  Size get size => Size(pageWidth, pageWidth * aspect);

  bool get isBlank => layers.every((l) => l.strokes.isEmpty);

  /// Time spent actually drawing, from stroke timestamps: strokes less than
  /// [idle] apart count as one session; longer pauses don't count.
  Duration activeTime({Duration idle = const Duration(seconds: 30)}) {
    final spans = <(int, int)>[
      for (final l in layers)
        for (final s in l.strokes)
          if (s.points.isNotEmpty) (s.points.first.t, s.points.last.t),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    var total = 0;
    int? start, end;
    for (final (s, e) in spans) {
      if (start == null || s - end! > idle.inMilliseconds) {
        if (start != null) total += end! - start;
        start = s;
        end = e;
      } else if (e > end) {
        end = e;
      }
    }
    if (start != null) total += end! - start;
    return Duration(milliseconds: total);
  }

  SketchPage copyWith({
    String? title,
    List<PageLayer>? layers,
    int? number,
    List<Color>? risoInks,
    List<String>? drawnDays,
  }) => SketchPage(
    id: id,
    number: number ?? this.number,
    title: title ?? this.title,
    paper: paper,
    aspect: aspect,
    riso: riso,
    layers: layers ?? this.layers,
    risoInks: risoInks ?? this.risoInks,
    drawnDays: drawnDays ?? this.drawnDays,
  );
}

/// "2026-10-21" for a local date.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Sketchbook {
  const Sketchbook({
    required this.id,
    required this.title,
    required this.cover,
    required this.paper,
    required this.format,
    required this.pages,
  });

  final String id;
  final String title;
  final CoverDesign cover;
  final PaperType paper;
  final PageFormat format;

  /// Newest first.
  final List<SketchPage> pages;

  int get pageCount => pages.length;

  /// Pages with something drawn. Lists and counts show only these, so a
  /// page just opened (or about to be discarded) never flickers in.
  List<SketchPage> get drawnPages => [
    for (final p in pages)
      if (!p.isBlank) p,
  ];
  int get drawnCount => pages.where((p) => !p.isBlank).length;

  /// Total drawing time across the book's pages.
  Duration get timeDrawn =>
      pages.fold(Duration.zero, (sum, p) => sum + p.activeTime());

  /// Consecutive days with drawing, ending today (or yesterday, so a streak
  /// isn't lost before today's session).
  int streakDays({DateTime? now}) {
    final days = {for (final p in pages) ...p.drawnDays};
    if (days.isEmpty) return 0;
    var day = DateUtils.dateOnly(now ?? DateTime.now());
    if (!days.contains(dayKey(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (days.contains(dayKey(day))) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }

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
  );
}

class DailyPrompt {
  const DailyPrompt({required this.text, required this.minutes});
  final String text;
  final int minutes;
}
