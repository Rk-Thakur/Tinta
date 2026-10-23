import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinta/ui/logo.dart';

void main() {
  group('dot bounce', () {
    test('big hop, small hop, then rest', () {
      final big = dotBounce(0.06 + 0.28 / 2); // top of the first hop
      final small = dotBounce(0.42 + 0.14 / 2); // top of the second
      expect(big.lift, closeTo(14, 0.01));
      expect(small.lift, closeTo(5, 0.01));
      for (final t in [0.0, 0.61, 0.8, 0.99]) {
        final p = dotBounce(t);
        expect(p.lift, 0);
        expect(p.scaleY, closeTo(1, 1e-9));
      }
    });

    test('squashes flat on landing, stretches tall in flight', () {
      final landing = dotBounce(0.34 + 0.08 / 2);
      expect(landing.lift, 0);
      expect(landing.scaleY, lessThan(0.8));
      expect(landing.scaleX, greaterThan(1.1));
      final takeOff = dotBounce(0.07);
      expect(takeOff.scaleY, greaterThan(1.05));
      expect(takeOff.scaleX, lessThan(1));
    });
  });

  testWidgets('bouncing mark keeps animating', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: TintaLogoMark(bounce: true))),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('reduce motion: the dot stays still', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: TintaLogoMark(bounce: true)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
