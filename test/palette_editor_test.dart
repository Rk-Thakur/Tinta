import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tinta/app/app.dart';
import 'package:tinta/app/routes.dart';
import 'package:tinta/data/library_store.dart';
import 'package:tinta/data/studio_store.dart';
import 'package:tinta/ui/widgets/color_picker.dart';

Future<StudioStore> _openPalettes(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final studio = StudioStore();
  await tester.pumpWidget(
    TintaApp(
      library: LibraryStore.memory(),
      studio: studio,
      initialRoute: Routes.color,
    ),
  );
  await tester.pumpAndSettle();
  return studio;
}

void main() {
  test('hex parsing', () {
    expect(parseHex('#2F4BFF'), const Color(0xFF2F4BFF));
    expect(parseHex('2f4bff'), const Color(0xFF2F4BFF));
    expect(parseHex('#24F'), const Color(0xFF2244FF));
    expect(parseHex('#12'), isNull);
    expect(parseHex('zzzzzz'), isNull);
  });

  testWidgets('make a palette: name, colors, hex; it becomes active', (
    tester,
  ) async {
    final studio = await _openPalettes(tester);
    expect(tester.takeException(), isNull); // header fits on a phone
    final builtIns = studio.palettes.length;

    await tester.tap(find.text('New palette'));
    await tester.pumpAndSettle();
    expect(find.text('COLORS · 1 OF 8'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Beach');
    await tester.tap(find.bySemanticsLabel('Add a color'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Add a color'));
    await tester.pump();
    expect(find.text('COLORS · 3 OF 8'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Hex'), '#E8467C');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(studio.palettes, hasLength(builtIns + 1));
    final made = studio.palettes.last;
    expect(made.name, 'Beach');
    expect(made.colors, hasLength(3));
    expect(
      made.colors.last,
      const Color(0xFFE8467C),
    ); // the selected (newest) swatch
    expect(studio.activePalette.id, made.id);
    expect(find.text('Beach'), findsOneWidget);
  });

  testWidgets('edit and delete a palette; built-ins have no edit', (
    tester,
  ) async {
    final studio = await _openPalettes(tester);
    expect(find.bySemanticsLabel(RegExp('^Edit ')), findsNothing);
    studio.addPalette('Mine', const [Color(0xFF112233), Color(0xFF445566)]);
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Mine'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Edit Mine'));
    await tester.pumpAndSettle();
    expect(find.text('Edit palette'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Color 2,')));
    await tester.pump();
    await tester.tap(find.text('Remove color'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Mine, edited',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(studio.palettes.last.name, 'Mine, edited');
    expect(studio.palettes.last.colors, [const Color(0xFF112233)]);

    await tester.dragUntilVisible(
      find.text('Mine, edited'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Edit Mine, edited'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Delete palette'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Delete palette'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(studio.palettes.any((p) => p.name.startsWith('Mine')), isFalse);
    expect(tester.takeException(), isNull);
  });
}
