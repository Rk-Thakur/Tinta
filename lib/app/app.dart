import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/library_store.dart';
import '../data/prefs.dart';
import '../data/studio_store.dart';
import '../theme/theme.dart';
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
  late final LibraryStore _store = widget.library ?? LibraryStore.seeded();
  late final StudioStore _studio = widget.studio ?? StudioStore();
  late final AppPrefs _prefs = widget.prefs ?? AppPrefs();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
            theme: TintaTheme.light(),
            initialRoute: widget.initialRoute,
            // Only the requested route; by default '/x' would also stack '/' under it.
            onGenerateInitialRoutes: (name) => [
              Routes.generate(RouteSettings(name: name)),
            ],
            onGenerateRoute: Routes.generate,
            // Light screens get a dark status bar; studio screens override this.
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.dark,
              child: child!,
            ),
          ),
        ),
      ),
    );
  }
}
