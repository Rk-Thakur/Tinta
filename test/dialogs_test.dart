import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinta/theme/theme.dart';
import 'package:tinta/ui/widgets/dialogs.dart';

Future<void> _open(
  WidgetTester tester,
  Future<void> Function(BuildContext) show,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: TintaTheme.app(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => show(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  // Regression: the text controller used to be disposed while the dialog
  // was still animating closed ("used after being disposed").
  for (final action in ['Cancel', 'Save']) {
    testWidgets('rename: $action closes cleanly', (tester) async {
      String? result = 'unset';
      await _open(
        tester,
        (c) async => result = await promptText(
          c,
          title: 'Rename page',
          initial: 'Hands',
        ),
      );
      expect(find.text('Rename page'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Feet  ');
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(result, action == 'Save' ? 'Feet' : null);
    });
  }

  testWidgets(
    'rename: Save is disabled for an empty name; keyboard Done saves',
    (tester) async {
      String? result = 'unset';
      await _open(
        tester,
        (c) async => result = await promptText(
          c,
          title: 'Rename page',
          initial: 'Hands',
        ),
      );
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Rename page'), findsOneWidget); // still open

      await tester.enterText(find.byType(TextField), 'Feet');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(result, 'Feet');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tapping outside cancels', (tester) async {
    String? result = 'unset';
    await _open(
      tester,
      (c) async => result = await promptText(c, title: 'Rename page'),
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirm returns true only on the confirm button', (
    tester,
  ) async {
    bool? ok;
    Future<void> show(BuildContext c) async => ok = await confirmAction(
      c,
      title: 'Delete “Hands”?',
      message: 'Gone for good.',
      confirmLabel: 'Delete',
    );
    await _open(tester, show);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(ok, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(ok, isTrue);
  });
}
