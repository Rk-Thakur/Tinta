import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/library_store.dart';
import '../data/prefs.dart';
import '../data/studio_store.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import 'routes.dart';

class TintaApp extends StatefulWidget {
  /// Without stores the app runs fully in memory with sample content (tests).
  const TintaApp({
    super.key,
    this.initialRoute = Routes.onboarding,
    this.library,
    this.studio,
    this.prefs,
  });

  final String initialRoute;
  final LibraryStore? library;
  final StudioStore? studio;
  final AppPrefs? prefs;

  @override
  State<TintaApp> createState() => _TintaAppState();
}

class _TintaAppState extends State<TintaApp> with WidgetsBindingObserver {
  late final LibraryStore _store = widget.library ?? LibraryStore.memory();
  late final StudioStore _studio = widget.studio ?? StudioStore();
  late final AppPrefs _prefs = widget.prefs ?? AppPrefs();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyLook();
    _prefs.addListener(_onPrefs);
  }

  /// Theme + ink pair from prefs (and the system, for [ThemeChoice.system]).
  /// Returns whether the palette changed.
  bool _applyLook() {
    final dark = switch (_prefs.theme) {
      ThemeChoice.light => false,
      ThemeChoice.dark => true,
      ThemeChoice.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
    if (dark == TintaColors.isDark && _prefs.inkPair == TintaColors.inkPair) {
      return false;
    }
    TintaColors.apply(dark: dark, pair: _prefs.inkPair);
    return true;
  }

  void _onPrefs() {
    if (_applyLook()) _repaintEverything();
  }

  @override
  void didChangePlatformBrightness() {
    if (_applyLook()) _repaintEverything();
  }

  /// Colors are read straight from [TintaColors], so after a switch every
  /// screen (including the ones under the current one) rebuilds and repaints
  /// in place, keeping its state.
  void _repaintEverything() {
    setState(() {});
    void visit(Element e) {
      e.markNeedsBuild();
      if (e is RenderObjectElement) e.renderObject.markNeedsPaint();
      e.visitChildren(visit);
    }

    if (mounted) (context as Element).visitChildren(visit);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Never lose a stroke: write pending changes when the app is backgrounded.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _store.flush();
    } else if (state == AppLifecycleState.resumed) {
      _store.refreshFreeSpace();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _prefs.removeListener(_onPrefs);
    _store.dispose();
    _studio.dispose();
    _prefs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrefsScope(
      prefs: _prefs,
      child: LibraryScope(
        store: _store,
        child: StudioScope(
          store: _studio,
          child: MaterialApp(
            title: 'Tinta',
            debugShowCheckedModeBanner: false,
            theme: TintaTheme.app(),
            initialRoute: widget.initialRoute,
            // Only the requested route; by default '/x' would also stack '/' under it.
            onGenerateInitialRoutes: (name) => [
              Routes.generate(RouteSettings(name: name)),
            ],
            onGenerateRoute: Routes.generate,
            // Status bar follows the theme; studio screens override this.
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: TintaColors.isDark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              child: child!,
            ),
          ),
        ),
      ),
    );
  }
}
