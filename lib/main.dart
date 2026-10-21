import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/routes.dart';
import 'data/library_store.dart';
import 'data/prefs.dart';
import 'data/studio_store.dart';
import 'data/vault.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final vault = await Vault.open();
  final (library, studio, prefs) = await (
    LibraryStore.open(vault),
    StudioStore.open(vault),
    AppPrefs.load(vault),
  ).wait;
  runApp(
    TintaApp(
      library: library,
      studio: studio,
      prefs: prefs,
      initialRoute: prefs.onboarded ? Routes.library : Routes.onboarding,
    ),
  );
}
