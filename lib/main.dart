import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/bootstrap.dart';
import 'data/library_store.dart';
import 'data/prefs.dart';
import 'data/studio_store.dart';
import 'data/vault.dart';
import 'services/tips.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Listen for tips from launch: the stores redeliver unfinished purchases.
  final tips = TipJar(StoreTipStore())..start();
  // The splash shows (dot bouncing) while the library loads from the device.
  runApp(TintaBootstrap(load: () => _load(tips)));
}

Future<AppData> _load(TipJar tips) async {
  final vault = await Vault.open();
  final (library, studio, prefs) = await (
    LibraryStore.open(vault),
    StudioStore.open(vault),
    AppPrefs.load(vault),
  ).wait;
  return AppData(library: library, studio: studio, prefs: prefs, tips: tips);
}
