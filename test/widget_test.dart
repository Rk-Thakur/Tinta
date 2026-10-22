import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tinta/app/app.dart';
import 'package:tinta/app/routes.dart';
import 'package:tinta/data/library_store.dart';
import 'package:tinta/data/models.dart';
import 'package:tinta/drawing/page_canvas.dart';
import 'package:tinta/ui/widgets/paper.dart';

import 'fixtures.dart';

void main() {
  Future<void> pumpPhone(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pump();
  }

  testWidgets('kit screen renders', (tester) async {
    await pumpPhone(tester, const TintaApp(initialRoute: Routes.kit));
    expect(find.text('The sketchbook that never needs Wi‑Fi.'), findsOneWidget);
  });

  testWidgets('first launch: empty library, onboarding makes a first book', (
    tester,
  ) async {
    await pumpPhone(tester, TintaApp(library: LibraryStore.memory()));
    expect(find.text('Draw anywhere.\nEven at 30,000 ft.'), findsOneWidget);

    await tester.tap(find.text('Open my first sketchbook'));
    await tester.pumpAndSettle();
    expect(find.text('My first sketchbook'), findsOneWidget);
    expect(find.text('Turn the page'), findsOneWidget);
    expect(find.text('0 days'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back to library'));
    await tester.pumpAndSettle();
    expect(find.text('Your studio'), findsOneWidget);
    expect(find.text('My first sketchbook'), findsOneWidget);
    expect(find.textContaining('Pages you start with'), findsOneWidget);
  });

  testWidgets('sketchbook stats come from real strokes', (tester) async {
    await pumpPhone(
      tester,
      TintaApp(library: fixtureLibrary(), initialRoute: Routes.library),
    );
    await tester.tap(find.text('Morning studies'));
    await tester.pumpAndSettle();
    expect(find.text('Figure, 2 min'), findsOneWidget);
    expect(
      find.text('3 days'),
      findsOneWidget,
    ); // today, yesterday, the day before
    expect(find.text('<1m'), findsOneWidget); // a few strokes, under a minute
  });

  testWidgets('new page sheet → canvas → draw → undo', (tester) async {
    await pumpPhone(tester, const TintaApp(initialRoute: Routes.library));
    await tester.tap(find.bySemanticsLabel('New canvas'));
    await tester.pumpAndSettle();
    expect(find.text('New page'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Kraft paper'));
    await tester.tap(find.text('Create page'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved on device'), findsOneWidget);

    final undo = find.bySemanticsLabel('Undo');
    expect(
      tester.getSemantics(undo).flagsCollection.isEnabled,
      Tristate.isFalse,
    );

    // Draw a stroke across the middle of the page.
    final center =
        tester.getCenter(find.byType(Scaffold).last) - const Offset(0, 80);
    final gesture = await tester.startGesture(center);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveBy(const Offset(8, 4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
    expect(
      tester.getSemantics(undo).flagsCollection.isEnabled,
      Tristate.isTrue,
    );

    await tester.tap(undo);
    await tester.pump();
    expect(
      tester.getSemantics(undo).flagsCollection.isEnabled,
      Tristate.isFalse,
    );
  });

  testWidgets('canvas → layers (add) and brush studio (pick preset)', (
    tester,
  ) async {
    await pumpPhone(tester, const TintaApp(initialRoute: Routes.library));
    await tester.tap(find.bySemanticsLabel('New canvas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create page'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Layers'));
    await tester.pumpAndSettle();
    expect(find.text('Line art'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Add layer'));
    await tester.pumpAndSettle();
    expect(find.text('Layer 2'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back to canvas'));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget); // layer badge

    await tester.tap(find.bySemanticsLabel('Brush settings'));
    await tester.pumpAndSettle();
    expect(find.text('Brush studio'), findsOneWidget);
    await tester.ensureVisible(find.text('Riso grain'));
    await tester.tap(find.text('Riso grain'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.bySemanticsLabel('Riso crayon'));
    await tester.tap(find.bySemanticsLabel('Riso crayon'));
    await tester.pumpAndSettle();
    expect(find.text('75%'), findsOneWidget); // crayon's paper grain
  });

  testWidgets('pinch zooms the page; the zoom chip fits it again', (
    tester,
  ) async {
    await pumpPhone(
      tester,
      TintaApp(library: LibraryStore.memory(), initialRoute: Routes.library),
    );
    await tester.tap(find.bySemanticsLabel('New canvas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create page'));
    await tester.pumpAndSettle();
    expect(find.textContaining('% · Fit'), findsNothing);

    final center = tester.getCenter(find.byType(PageCanvas));
    final a = await tester.startGesture(
      center - const Offset(30, 0),
      pointer: 1,
    );
    await tester.pump(const Duration(milliseconds: 50));
    final b = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 2,
    );
    for (var i = 0; i < 10; i++) {
      await a.moveBy(const Offset(-6, 0));
      await b.moveBy(const Offset(6, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();

    // Span 60 → 180: three times the fitted size.
    expect(find.text('300% · Fit'), findsOneWidget);
    // A pinch is navigation, not drawing.
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Undo'))
          .flagsCollection
          .isEnabled,
      Tristate.isFalse,
    );

    await tester.tap(find.text('300% · Fit'));
    await tester.pumpAndSettle();
    expect(find.textContaining('% · Fit'), findsNothing);
  });

  testWidgets('every cover design renders', (tester) async {
    await pumpPhone(
      tester,
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Wrap(
              children: [
                for (final c in coverPresets)
                  SketchbookCover(
                    cover: c,
                    width: 60,
                    title: 'Summer sketches',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(SketchbookCover), findsNWidgets(coverPresets.length));
    expect(coverPresets.length, greaterThanOrEqualTo(24));
    expect({for (final c in coverPresets) c.motif}, CoverMotif.values.toSet());
    expect(tester.takeException(), isNull);
  });

  testWidgets('library search filters sketchbooks', (tester) async {
    await pumpPhone(
      tester,
      TintaApp(library: fixtureLibrary(), initialRoute: Routes.library),
    );
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'ink');
    await tester.pump();
    expect(find.text('Inktober'), findsOneWidget);
    expect(find.text('Morning studies'), findsNothing);
  });
}
