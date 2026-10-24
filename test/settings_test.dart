import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tinta/app/app.dart';
import 'package:tinta/app/routes.dart';
import 'package:tinta/data/library_store.dart';
import 'package:tinta/data/prefs.dart';
import 'package:tinta/drawing/page_canvas.dart';
import 'package:tinta/services/tips.dart';
import 'package:tinta/theme/tokens.dart';

Future<AppPrefs> _open(
  WidgetTester tester, {
  String route = Routes.settings,
  TipJar? tips,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final prefs = AppPrefs();
  await tester.pumpWidget(
    TintaApp(
      library: LibraryStore.memory(),
      prefs: prefs,
      tips: tips,
      initialRoute: route,
    ),
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

  testWidgets('buy me a coffee: pick a size, pay, get thanked', (tester) async {
    final store = _FakeStore();
    final prefs = await _open(tester, tips: TipJar(store));
    await _openTipSheet(tester);
    expect(find.text('\$1.99'), findsOneWidget);
    expect(find.text('\$4.99'), findsOneWidget);
    expect(find.text('\$9.99'), findsOneWidget);
    expect(tester.takeException(), isNull); // three tiles fit a phone

    await tester.tap(find.bySemanticsLabel('Big coffee, \$4.99'));
    await tester.pump();
    expect(store.bought, ['tinta.tip.medium']);

    store.updates_.add(('tinta.tip.medium', TipOutcome.purchased));
    await tester.pumpAndSettle();
    expect(find.text('Thank you!'), findsOneWidget);
    expect(prefs.coffees, 2);

    await tester.tap(find.text('Back to drawing'));
    await tester.pumpAndSettle();
    expect(find.text('Thank you, that means a lot!'), findsOneWidget);
    await store.updates_.close();
  });

  testWidgets('a canceled or failed payment goes back to the choices', (
    tester,
  ) async {
    final store = _FakeStore();
    final prefs = await _open(tester, tips: TipJar(store));
    await _openTipSheet(tester);

    await tester.tap(find.bySemanticsLabel('Coffee, \$1.99'));
    store.updates_.add(('tinta.tip.small', TipOutcome.canceled));
    await tester.pumpAndSettle();
    expect(find.text('Buy me a coffee'), findsOneWidget);
    expect(find.textContaining('didn’t go through'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Coffee, \$1.99'));
    store.updates_.add(('tinta.tip.small', TipOutcome.failed));
    await tester.pumpAndSettle();
    expect(find.textContaining('You weren’t charged'), findsOneWidget);
    expect(prefs.coffees, 0);

    // A store error mid-payment doesn't crash; it's a failed payment.
    await tester.tap(find.bySemanticsLabel('Coffee, \$1.99'));
    await tester.pump();
    store.updates_.addError(StateError('store hiccup'));
    await tester.pumpAndSettle();
    expect(find.textContaining('You weren’t charged'), findsOneWidget);
    expect(find.text('Buy me a coffee'), findsOneWidget);
    await store.updates_.close();
  });

  testWidgets('no store: the tip sheet says tips are unavailable', (
    tester,
  ) async {
    await _open(tester);
    await _openTipSheet(tester);
    expect(find.text('Tips aren’t available right now'), findsOneWidget);
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

Future<void> _openTipSheet(WidgetTester tester) async {
  final card = find.text('Enjoying tinta? Buy me a coffee');
  await tester.dragUntilVisible(
    card,
    find.byType(ListView),
    const Offset(0, -200),
  );
  await tester.tap(card);
  await tester.pumpAndSettle();
}

class _FakeStore implements TipStore {
  final updates_ = StreamController<(String, TipOutcome)>.broadcast();
  final bought = <String>[];

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<TipOffer>> offers() async => const [
    TipOffer(Tip.small, '\$1.99'),
    TipOffer(Tip.medium, '\$4.99'),
    TipOffer(Tip.large, '\$9.99'),
  ];

  @override
  Future<void> buy(TipOffer offer) async => bought.add(offer.tip.productId);

  @override
  Stream<(String, TipOutcome)> get updates => updates_.stream;
}
