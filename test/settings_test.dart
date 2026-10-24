import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tinta/app/app.dart';
import 'package:tinta/app/routes.dart';
import 'package:tinta/data/library_store.dart';
import 'package:tinta/data/prefs.dart';
import 'package:tinta/drawing/page_canvas.dart';
import 'package:tinta/services/links.dart';
import 'package:tinta/theme/tokens.dart';

Future<AppPrefs> _open(
  WidgetTester tester, {
  String route = Routes.settings,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final prefs = AppPrefs();
  await tester.pumpWidget(
    TintaApp(library: LibraryStore.memory(), prefs: prefs, initialRoute: route),
  );
  await tester.pumpAndSettle();
  return prefs;
}

bool _enabled(WidgetTester tester, String label) =>
    tester
        .getSemantics(find.bySemanticsLabel(label))
        .flagsCollection
        .isEnabled ==
    Tristate.isTrue;

void main() {
  tearDown(() => TintaColors.apply(dark: false, pair: InkPair.riso));

  testWidgets('settings: theme, ink pair and toggles as designed', (
    tester,
  ) async {
    final prefs = await _open(tester);
    expect(tester.takeException(), isNull); // fits a phone
    for (final text in [
      'Offline',
      'THEME',
      'Newsprint',
      'INK PAIR · TINTS THE WHOLE APP',
      'Pencil sounds',
      'Left‑handed dock',
      'Two‑finger tap to undo',
      'Three fingers to redo',
      'Daily prompt',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }

    BuildContext settings() => tester.element(find.text('Pencil sounds'));
    expect(Theme.of(settings()).scaffoldBackgroundColor, TintaInk.newsprint);

    await tester.tap(find.bySemanticsLabel('Dark theme'));
    await tester.pumpAndSettle();
    expect(prefs.theme, ThemeChoice.dark);
    expect(TintaColors.isDark, isTrue);
    expect(find.text('Studio ink'), findsOneWidget);
    expect(Theme.of(settings()).brightness, Brightness.dark);

    await tester.tap(find.bySemanticsLabel('Green & pink ink pair'));
    await tester.pumpAndSettle();
    expect(prefs.inkPair, InkPair.garden);
    expect(TintaColors.fluoroOrange, InkPair.garden.secondary);

    await tester.tap(find.bySemanticsLabel('Light theme'));
    await tester.pumpAndSettle();
    expect(TintaColors.isDark, isFalse);
    expect(TintaColors.risoBlue, InkPair.garden.primary);

    expect(prefs.pencilSounds, isTrue);
    await tester.tap(find.bySemanticsLabel('Pencil sounds'));
    await tester.pump();
    expect(prefs.pencilSounds, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('buy me a coffee opens the tip page, then says thanks', (
    tester,
  ) async {
    final opened = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('tinta/device'),
      (call) async {
        if (call.method == 'openUrl') {
          opened.add((call.arguments as Map)['url']);
          return true;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('tinta/device'),
        null,
      ),
    );
    await _open(tester);
    final card = find.text('Enjoying tinta? Buy me a coffee');
    await tester.dragUntilVisible(
      card,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(opened, [buyMeACoffeeUrl]);
    expect(find.text('Thank you, that means a lot!'), findsOneWidget);
  });

  testWidgets('two-finger tap undoes, three-finger tap redoes', (tester) async {
    await _open(tester, route: Routes.library);
    await tester.tap(find.bySemanticsLabel('New canvas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create page'));
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(PageCanvas));
    final pen = await tester.startGesture(center, pointer: 1);
    for (var i = 0; i < 8; i++) {
      await pen.moveBy(const Offset(8, 4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await pen.up();
    // The top bar slid away while drawing; it returns shortly after.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'Undo'), isTrue);

    Future<void> tap(int fingers) async {
      final gestures = [
        for (var i = 0; i < fingers; i++)
          await tester.startGesture(
            center + Offset(40.0 * i, 0),
            pointer: 10 + i,
          ),
      ];
      await tester.pump(const Duration(milliseconds: 60));
      for (final g in gestures) {
        await g.up();
      }
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    await tap(2);
    expect(_enabled(tester, 'Undo'), isFalse);
    expect(_enabled(tester, 'Redo'), isTrue);

    await tap(3);
    expect(_enabled(tester, 'Undo'), isTrue);
    expect(_enabled(tester, 'Redo'), isFalse);
  });
}
