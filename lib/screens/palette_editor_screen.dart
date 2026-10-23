import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/studio_store.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/widgets/color_picker.dart';
import '../ui/widgets/dialogs.dart';
import '../ui/widgets/widgets.dart';

class PaletteEditorArgs {
  const PaletteEditorArgs({this.paletteId, this.startWith});

  /// Edit this user palette; null makes a new one.
  final String? paletteId;

  /// First color of a new palette (e.g. the canvas's current ink).
  final Color? startWith;
}

/// Make or edit a palette: a name and up to [StudioStore.maxColors] colors.
class PaletteEditorScreen extends StatefulWidget {
  const PaletteEditorScreen({super.key, this.args = const PaletteEditorArgs()});

  final PaletteEditorArgs args;

  @override
  State<PaletteEditorScreen> createState() => _PaletteEditorScreenState();
}

class _PaletteEditorScreenState extends State<PaletteEditorScreen> {
  final _name = TextEditingController();
  final _hex = TextEditingController();
  final List<Color> _colors = [];
  int _selected = 0;
  late HSVColor _hsv;
  Palette? _editing;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final studio = StudioScope.of(context);
    final id = widget.args.paletteId;
    if (id != null) {
      for (final p in studio.palettes) {
        if (p.id == id) _editing = p;
      }
    }
    if (_editing != null) {
      _name.text = _editing!.name;
      _colors.addAll(_editing!.colors);
    } else {
      _colors.add(widget.args.startWith ?? TintaInk.risoBlue);
    }
    _select(0);
  }

  @override
  void dispose() {
    _name.dispose();
    _hex.dispose();
    super.dispose();
  }

  void _select(int i) {
    _selected = i;
    _hsv = HSVColor.fromColor(_colors[i]);
    _hex.text = hexOf(_colors[i]);
  }

  /// Live edit of the selected swatch.
  void _setColor(Color c, {bool updateHex = true}) {
    setState(() {
      _colors[_selected] = c;
      if (updateHex) _hex.text = hexOf(c);
    });
  }

  void _add() {
    if (_colors.length >= StudioStore.maxColors) return;
    HapticFeedback.selectionClick();
    // Start from a neighbour of the last color, so new swatches aren't clones.
    final last = HSVColor.fromColor(_colors.last);
    final next = last.withHue((last.hue + 40) % 360).toColor();
    setState(() {
      _colors.add(next);
      _select(_colors.length - 1);
    });
  }

  void _removeSelected() {
    if (_colors.length <= 1) return;
    setState(() {
      _colors.removeAt(_selected);
      _select(_selected.clamp(0, _colors.length - 1));
    });
  }

  String get _nameOrDefault =>
      _name.text.trim().isEmpty ? 'My palette' : _name.text.trim();

  void _save() {
    final studio = StudioScope.of(context);
    if (_editing != null) {
      studio.updatePalette(
        _editing!.id,
        name: _nameOrDefault,
        colors: List.of(_colors),
      );
    } else {
      studio.addPalette(_nameOrDefault, List.of(_colors));
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final editing = _editing;
    if (editing == null) return;
    final ok = await confirmAction(
      context,
      title: 'Delete “${editing.name}”?',
      message: 'The palette is removed. Pages drawn with its colors keep them.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    StudioScope.of(context).removePalette(editing);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = _colors.length < StudioStore.maxColors;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            28 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            Row(
              spacing: 10,
              children: [
                TileIconButton(
                  icon: TintaIcons.close,
                  label: 'Close without saving',
                  background: TintaColors.surface,
                  foreground: TintaColors.studioInk,
                  borderColor: TintaColors.line,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Text(
                    _editing == null ? 'New palette' : 'Edit palette',
                    style: TintaType.display28,
                  ),
                ),
                PillButton(label: 'Save', compact: true, onPressed: _save),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              style: TintaType.body(17),
              decoration: _fieldDecoration(label: 'Name', hint: 'My palette'),
            ),
            const SizedBox(height: 18),
            Text(
              'COLORS · ${_colors.length} OF ${StudioStore.maxColors}',
              style: TintaType.mono(
                11,
                color: TintaColors.ink2,
              ).copyWith(letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < _colors.length; i++)
                  _Swatch(
                    color: _colors[i],
                    selected: i == _selected,
                    index: i,
                    onTap: () => setState(() => _select(i)),
                  ),
                if (canAdd)
                  Semantics(
                    button: true,
                    label: 'Add a color',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: _add,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: TintaColors.surface,
                          borderRadius: BorderRadius.circular(TintaRadii.sm),
                          border: Border.all(
                            color: TintaColors.line,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: TintaIcon(
                            TintaIcons.plus,
                            size: 22,
                            strokeWidth: 2.4,
                            color: TintaColors.ink2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SaturationValueBox(
              hsv: _hsv,
              onChanged: (hsv) {
                _hsv = hsv;
                _setColor(hsv.toColor());
              },
              onChangeEnd: () {},
            ),
            const SizedBox(height: 16),
            HueBar(
              hsv: _hsv,
              onChanged: (hsv) {
                _hsv = hsv;
                _setColor(hsv.toColor());
              },
              onChangeEnd: () {},
            ),
            const SizedBox(height: 12),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: TextField(
                    controller: _hex,
                    style: TintaType.mono(16, weight: FontWeight.w600),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[#0-9a-fA-F]'),
                      ),
                      LengthLimitingTextInputFormatter(7),
                    ],
                    decoration: _fieldDecoration(label: 'Hex'),
                    onChanged: (v) {
                      final c = parseHex(v);
                      if (c == null) return;
                      _hsv = HSVColor.fromColor(c);
                      _setColor(c, updateHex: false);
                    },
                  ),
                ),
                TextButton.icon(
                  onPressed: _colors.length > 1 ? _removeSelected : null,
                  style: TextButton.styleFrom(
                    foregroundColor: tintaDanger,
                    minimumSize: const Size(44, 44),
                    textStyle: TintaType.body(14, weight: FontWeight.w500),
                  ),
                  icon: TintaIcon(
                    TintaIcons.close,
                    size: 16,
                    color: _colors.length > 1
                        ? tintaDanger
                        : TintaColors.studioMuted,
                  ),
                  label: const Text('Remove color'),
                ),
              ],
            ),
            if (_editing != null) ...[
              const SizedBox(height: 28),
              Center(
                child: TextButton(
                  onPressed: _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: tintaDanger,
                    minimumSize: const Size(44, 44),
                  ),
                  child: const Text('Delete palette'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({required String label, String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TintaType.body(14, color: TintaColors.ink2),
        hintStyle: TintaType.body(17, color: TintaColors.studioMuted),
        filled: true,
        fillColor: TintaColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TintaRadii.md),
          borderSide: BorderSide(color: TintaColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TintaRadii.md),
          borderSide: BorderSide(color: TintaColors.studioInk, width: 2),
        ),
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.index,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Color ${index + 1}, ${hexOf(color)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TintaRadii.sm + 3),
            border: Border.all(
              color: selected ? TintaColors.studioInk : Colors.transparent,
              width: 3,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(TintaRadii.sm - 2),
              border: color.computeLuminance() > 0.85
                  ? Border.all(color: TintaColors.line)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
