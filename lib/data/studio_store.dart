import 'package:flutter/widgets.dart';

import '../drawing/brushes.dart';
import 'codec.dart';
import 'vault.dart';
import '../theme/tokens.dart';

class Palette {
  const Palette({required this.id, required this.name, required this.colors});

  final String id;
  final String name;
  final List<Color> colors;
}

/// App-wide studio preferences: palettes and the user's own brushes,
/// stored in studio.json.
class StudioStore extends ChangeNotifier {
  StudioStore({this.vault});

  final Vault? vault;

  static Future<StudioStore> open(Vault vault) async {
    final store = StudioStore(vault: vault);
    await store.reload();
    return store;
  }

  /// Re-reads palettes and brushes from the vault (after a restore).
  Future<void> reload() async {
    _palettes
      ..clear()
      ..addAll(builtInPalettes);
    _activePalette = builtInPalettes.first.id;
    _mine.clear();
    final j = await vault?.readJson('studio.json');
    if (j != null) {
      for (final p in (j['palettes'] as List? ?? const [])) {
        final m = p as Map<String, Object?>;
        _palettes.add(
          Palette(
            id: m['id']! as String,
            name: m['name']! as String,
            colors: Codec.colorsFrom(m['colors']),
          ),
        );
      }
      final active = j['activePalette'] as String?;
      if (_palettes.any((p) => p.id == active)) _activePalette = active!;
      for (final b in (j['brushes'] as List? ?? const [])) {
        final preset = Codec.presetFrom(b as Map<String, Object?>);
        Brushes.register(preset);
        _mine.add(preset);
      }
    }
    notifyListeners();
  }

  void _save() {
    vault?.writeJson('studio.json', {
      'v': Codec.version,
      'activePalette': _activePalette,
      // Built-ins ship with the app; only user palettes are stored.
      'palettes': [
        for (final p in _palettes.skip(builtInPalettes.length))
          {'id': p.id, 'name': p.name, 'colors': Codec.colors(p.colors)},
      ],
      'brushes': [for (final b in _mine) Codec.preset(b)],
    });
  }

  /// Adds a user palette (e.g. from a photo) and makes it active.
  Palette addPalette(String name, List<Color> colors) {
    final p = Palette(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      colors: colors,
    );
    _palettes.add(p);
    _activePalette = p.id;
    notifyListeners();
    _save();
    return p;
  }

  /// Most colors a palette can hold.
  static const maxColors = 8;

  /// Renames / recolors a user palette (built-ins are fixed).
  void updatePalette(
    String id, {
    required String name,
    required List<Color> colors,
  }) {
    final i = _palettes.indexWhere((p) => p.id == id);
    if (i < 0 || !isUserPalette(_palettes[i])) return;
    _palettes[i] = Palette(
      id: id,
      name: name,
      colors: List.unmodifiable(colors),
    );
    notifyListeners();
    _save();
  }

  void removePalette(Palette p) {
    if (builtInPalettes.any((b) => b.id == p.id)) return;
    _palettes.removeWhere((x) => x.id == p.id);
    if (_activePalette == p.id) _activePalette = builtInPalettes.first.id;
    notifyListeners();
    _save();
  }

  bool isUserPalette(Palette p) => !builtInPalettes.any((b) => b.id == p.id);

  static const builtInPalettes = [
    Palette(
      id: 'riso-duo',
      name: 'Riso duo',
      colors: [
        TintaColors.risoBlue,
        TintaColors.fluoroOrange,
        TintaColors.overprintViolet,
        TintaColors.studioInk,
      ],
    ),
    Palette(
      id: 'ink-wash',
      name: 'Ink & wash',
      colors: [
        Color(0xFF1F2A36),
        Color(0xFF4E6170),
        Color(0xFF93A3AE),
        Color(0xFFD5DCE0),
        Color(0xFFEDE6D8),
      ],
    ),
    Palette(
      id: 'market-day',
      name: 'Market day',
      colors: [
        TintaColors.sun,
        Color(0xFF2E9E6A),
        Color(0xFFE8467C),
        Color(0xFFF28C28),
      ],
    ),
  ];

  final List<Palette> _palettes = List.of(builtInPalettes);
  String _activePalette = builtInPalettes.first.id;
  final List<BrushPreset> _mine = [];
  int _mineCounter = 0;

  List<Palette> get palettes => List.unmodifiable(_palettes);
  Palette get activePalette =>
      _palettes.firstWhere((p) => p.id == _activePalette);
  List<BrushPreset> get myBrushes => List.unmodifiable(_mine);

  set activePalette(Palette p) {
    _activePalette = p.id;
    notifyListeners();
    _save();
  }

  /// Saves the given tweak of [base] as a new "Mine" brush.
  BrushPreset saveBrush(
    BrushPreset base, {
    required double size,
    required double opacity,
    required double grain,
    required Smoothing smoothing,
  }) {
    final preset = base.copyAsMine(
      id: 'mine-${DateTime.now().millisecondsSinceEpoch}-${_mineCounter++}',
      size: size,
      opacity: opacity,
      grain: grain,
      smoothing: smoothing,
    );
    Brushes.register(preset);
    _mine.add(preset);
    notifyListeners();
    _save();
    return preset;
  }
}

class StudioScope extends InheritedNotifier<StudioStore> {
  const StudioScope({
    super.key,
    required StudioStore store,
    required super.child,
  }) : super(notifier: store);

  static StudioStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StudioScope>()!.notifier!;
}
