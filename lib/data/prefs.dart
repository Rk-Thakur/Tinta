import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'vault.dart';

/// App settings, stored in prefs.json.
class AppPrefs extends ChangeNotifier {
  AppPrefs({this.vault});

  final Vault? vault;

  bool _onboarded = false;
  bool _leftHanded = false;
  bool _twoFingerUndo = true;
  bool _reminder = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);
  ThemeChoice _theme = ThemeChoice.light;
  InkPair _inkPair = InkPair.riso;
  bool _pencilSounds = true;

  bool get onboarded => _onboarded;
  bool get leftHanded => _leftHanded;
  bool get twoFingerUndo => _twoFingerUndo;
  bool get reminder => _reminder;
  TimeOfDay get reminderTime => _reminderTime;
  ThemeChoice get theme => _theme;
  InkPair get inkPair => _inkPair;
  bool get pencilSounds => _pencilSounds;

  static Future<AppPrefs> load(Vault vault) async {
    final p = AppPrefs(vault: vault);
    final j = await vault.readJson('prefs.json');
    if (j != null) {
      p._onboarded = j['onboarded'] == true;
      p._leftHanded = j['leftHanded'] == true;
      p._twoFingerUndo = j['twoFingerUndo'] != false;
      p._reminder = j['reminder'] == true;
      p._reminderTime = TimeOfDay(
        hour: (j['reminderHour'] as num?)?.toInt() ?? 8,
        minute: (j['reminderMinute'] as num?)?.toInt() ?? 0,
      );
      p._theme = _byName(ThemeChoice.values, j['theme'], ThemeChoice.light);
      p._inkPair = _byName(InkPair.values, j['inkPair'], InkPair.riso);
      p._pencilSounds = j['pencilSounds'] != false;
    }
    return p;
  }

  static T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  void _changed() {
    notifyListeners();
    vault?.writeJson('prefs.json', {
      'onboarded': _onboarded,
      'leftHanded': _leftHanded,
      'twoFingerUndo': _twoFingerUndo,
      'reminder': _reminder,
      'reminderHour': _reminderTime.hour,
      'reminderMinute': _reminderTime.minute,
      'theme': _theme.name,
      'inkPair': _inkPair.name,
      'pencilSounds': _pencilSounds,
    });
  }

  set onboarded(bool v) {
    _onboarded = v;
    _changed();
  }

  set leftHanded(bool v) {
    _leftHanded = v;
    _changed();
  }

  set twoFingerUndo(bool v) {
    _twoFingerUndo = v;
    _changed();
  }

  set reminder(bool v) {
    _reminder = v;
    _changed();
  }

  set reminderTime(TimeOfDay v) {
    _reminderTime = v;
    _changed();
  }

  set theme(ThemeChoice v) {
    _theme = v;
    _changed();
  }

  set inkPair(InkPair v) {
    _inkPair = v;
    _changed();
  }

  set pencilSounds(bool v) {
    _pencilSounds = v;
    _changed();
  }
}

class PrefsScope extends InheritedNotifier<AppPrefs> {
  const PrefsScope({super.key, required AppPrefs prefs, required super.child})
    : super(notifier: prefs);

  static AppPrefs of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrefsScope>()!.notifier!;
}
