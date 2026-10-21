import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tinta/data/models.dart';
import 'package:tinta/drawing/stroke.dart';
import 'package:tinta/screens/replay_screen.dart';

SketchPage _pageWithStroke() {
  return SketchPage(
    id: 'p1',
    number: 1,
    title: 'Test page',
    paper: PaperType.smooth,
    layers: [
      PageLayer(
        id: 'l1',
        name: 'Line art',
        strokes: [
          Stroke(
            id: 1,
            brush: BrushKind.ink,
            color: Colors.black,
            size: 4,
            points: const [
              StrokePoint(10, 10, t: 0),
              StrokePoint(40, 40, t: 120),
              StrokePoint(90, 60, t: 260),
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('replay scrubber exposes increase/decrease semantics', (
    tester,
  ) async {
    // The studio UI targets tablets; phone widths overflow the action row
    // because the test font renders every glyph as a full-width box.
    tester.view.physicalSize = const Size(1024 * 2, 768 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ReplayScreen(
          args: ReplayArgs(pages: [_pageWithStroke()], title: 'Test page'),
        ),
      ),
    );
    await tester.pump();

    final scrubber = find.bySemanticsLabel('Replay position');
    expect(scrubber, findsOneWidget);

    final node = tester.getSemantics(scrubber);
    final data = node.getSemanticsData();
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);

    // Flutter asserts that a node exposing "increase" carries both a value
    // and an increasedValue (and likewise for decrease).
    expect(node.value, isNotEmpty);
    expect(node.increasedValue, isNotEmpty);
    expect(node.decreasedValue, isNotEmpty);
  });
}
