import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tinta/app/app.dart';
import 'package:tinta/app/routes.dart';

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

  testWidgets('onboarding → library → sketchbook', (tester) async {
    await pumpPhone(tester, const TintaApp());
    expect(find.text('Draw anywhere.\nEven at 30,000 ft.'), findsOneWidget);

    await tester.tap(find.text('Open my first sketchbook'));
    await tester.pumpAndSettle();
    expect(find.text('Your studio'), findsOneWidget);
    expect(find.text('Morning studies'), findsOneWidget);
    expect(find.text('Loose pages'), findsOneWidget);

    await tester.tap(find.text('Morning studies'));
    await tester.pumpAndSettle();
    expect(find.text('Figure, 2 min'), findsOneWidget);
    expect(find.text('Turn the page'), findsOneWidget);
    expect(find.text('6 days'), findsOneWidget);
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

  testWidgets('library search filters sketchbooks', (tester) async {
    await pumpPhone(tester, const TintaApp(initialRoute: Routes.library));
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'ink');
    await tester.pump();
    expect(find.text('Inktober'), findsOneWidget);
    expect(find.text('Travel journal'), findsNothing);
  });
}
