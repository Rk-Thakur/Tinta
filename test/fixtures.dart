import 'dart:ui';

import 'package:tinta/data/library_store.dart';
import 'package:tinta/data/models.dart';
import 'package:tinta/drawing/stroke.dart';
import 'package:tinta/theme/tokens.dart';

/// A small hand-built library for tests (the app itself starts empty).
Stroke fixtureStroke(int id, int t0, {Color color = TintaInk.studioInk}) =>
    Stroke(
      id: id,
      brush: BrushKind.pencil,
      color: color,
      size: 3,
      points: [
        for (var i = 0; i < 6; i++)
          StrokePoint(40.0 + i * 10, 60.0 + i * 5, t: t0 + i * 16),
      ],
    );

SketchPage fixturePage(
  String id,
  int number, {
  String? title,
  List<String> days = const [],
}) => SketchPage(
  id: id,
  number: number,
  title: title,
  paper: PaperType.toned,
  drawnDays: days,
  layers: [
    PageLayer(
      id: 'l1',
      name: 'Line art',
      strokes: [fixtureStroke(1, 0), fixtureStroke(2, 1000)],
    ),
  ],
);

LibraryStore fixtureLibrary({DateTime? today}) {
  final now = today ?? DateTime.now();
  String daysAgo(int n) => dayKey(DateTime(now.year, now.month, now.day - n));
  return LibraryStore.memory(
    sketchbooks: [
      Sketchbook(
        id: 'b1',
        title: 'Morning studies',
        cover: CoverDesign(
          color: TintaInk.risoBlue,
          band: TintaInk.studioInk,
          motif: CoverMotif.dot,
        ),
        paper: PaperType.toned,
        format: PageFormat.a5,
        pages: [
          fixturePage(
            'b1-p2',
            2,
            title: 'Figure, 2 min',
            days: [daysAgo(0), daysAgo(1)],
          ),
          fixturePage('b1-p1', 1, title: 'Coffee mug', days: [daysAgo(2)]),
        ],
      ),
      Sketchbook(
        id: 'b2',
        title: 'Inktober',
        cover: CoverDesign(
          color: TintaInk.studioInk,
          band: TintaColors.sun,
          motif: CoverMotif.wordmark,
        ),
        paper: PaperType.smooth,
        format: PageFormat.square,
        pages: [],
      ),
    ],
    loosePages: [fixturePage('loose-a', 1, title: 'Warm-up')],
  );
}
