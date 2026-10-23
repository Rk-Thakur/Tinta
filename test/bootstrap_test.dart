import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tinta/app/bootstrap.dart';
import 'package:tinta/data/library_store.dart';
import 'package:tinta/data/prefs.dart';
import 'package:tinta/data/studio_store.dart';
import 'package:tinta/screens/onboarding_screen.dart';
import 'package:tinta/ui/logo.dart';

AppData _data({required bool onboarded}) => AppData(
  library: LibraryStore.memory(),
  studio: StudioStore(),
  prefs: AppPrefs()..onboarded = onboarded,
);

void main() {
  testWidgets('first launch: splash with the bouncing dot, then onboarding', (
    tester,
  ) async {
    final loading = Completer<AppData>();
    await tester.pumpWidget(TintaBootstrap(load: () => loading.future));

    expect(find.byType(SplashScreen), findsOneWidget);
    final mark = tester.widget<TintaLogoMark>(find.byType(TintaLogoMark));
    expect(mark.bounce, isTrue);
    expect(mark.size, SplashScreen.markHeight);

    // Loaded quickly: the splash still stays for one bounce.
    loading.complete(_data(onboarded: false));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    // The onboarding logo sits still; only the splash bounces.
    expect(
      tester
          .widgetList<TintaLogoMark>(find.byType(TintaLogoMark))
          .every((m) => !m.bounce),
      isTrue,
    );
    // Nothing to go back to.
    expect(
      Navigator.of(tester.element(find.byType(OnboardingScreen))).canPop(),
      isFalse,
    );
  });

  testWidgets('returning user: splash, then straight to the library', (
    tester,
  ) async {
    await tester.pumpWidget(
      TintaBootstrap(
        load: () async => _data(onboarded: true),
        minimumSplash: const Duration(milliseconds: 300),
      ),
    );
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Your studio'), findsOneWidget);
  });

  testWidgets('a failed load says so on the splash', (tester) async {
    await tester.pumpWidget(
      TintaBootstrap(
        load: () async => throw const FileSystemExceptionStub(),
        minimumSplash: Duration.zero,
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.textContaining('couldn’t open its library'), findsOneWidget);
  });
}

class FileSystemExceptionStub implements Exception {
  const FileSystemExceptionStub();
  @override
  String toString() => 'disk unavailable';
}
