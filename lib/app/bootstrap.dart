import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/library_store.dart';
import '../data/prefs.dart';
import '../data/studio_store.dart';
import '../theme/tokens.dart';
import '../ui/logo.dart';
import 'app.dart';
import 'routes.dart';

/// Everything the app needs before its first screen.
class AppData {
  const AppData({
    required this.library,
    required this.studio,
    required this.prefs,
  });

  final LibraryStore library;
  final StudioStore studio;
  final AppPrefs prefs;
}

/// Starts the app: the splash (bouncing dot) while [load] runs, then
/// onboarding on a first launch, otherwise the library.
class TintaBootstrap extends StatefulWidget {
  const TintaBootstrap({
    super.key,
    required this.load,
    this.minimumSplash = const Duration(milliseconds: 1500),
  });

  final Future<AppData> Function() load;

  /// Long enough for one full bounce of the dot.
  final Duration minimumSplash;

  @override
  State<TintaBootstrap> createState() => _TintaBootstrapState();
}

class _TintaBootstrapState extends State<TintaBootstrap> {
  AppData? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final splash = Future<void>.delayed(widget.minimumSplash);
      final data = await widget.load();
      await splash;
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      // Fill the screen; the default layout would shrink the splash to its logo.
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        textDirection: TextDirection.ltr,
        children: [...previous, ?current],
      ),
      child: data == null
          ? SplashScreen(key: const ValueKey('splash'), error: _error)
          : TintaApp(
              key: const ValueKey('app'),
              library: data.library,
              studio: data.studio,
              prefs: data.prefs,
              // First launch (or onboarding never finished): onboarding.
              initialRoute: data.prefs.onboarded
                  ? Routes.library
                  : Routes.onboarding,
            ),
    );
  }
}

/// The logo on newsprint, matching the native launch screen, with the full
/// stop bouncing while the library loads.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.error});

  final Object? error;

  /// Same size as the native launch image's mark (120pt box × 0.9).
  static const markHeight = 108.0;

  @override
  Widget build(BuildContext context) {
    // Lives outside MaterialApp, so it brings its own basics.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: TintaColors.newsprint,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const TintaLogoMark(size: markHeight, bounce: true),
              if (error != null)
                Positioned(
                  left: 32,
                  right: 32,
                  bottom: 64,
                  child: Text(
                    'Tinta couldn’t open its library on this device.\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 14,
                      color: TintaColors.ink2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
