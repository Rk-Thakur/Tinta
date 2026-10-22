import 'package:flutter/material.dart';

import '../app/routes.dart';

import '../data/studio_store.dart';
import '../drawing/canvas_controller.dart';
import '../services/photo_palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/widgets/color_picker.dart';
import '../ui/widgets/widgets.dart';
import 'palette_editor_screen.dart';

/// Returned when the user asks to sample a color from the page.
const colorScreenEyedropper = 'eyedropper';

/// What two inks look like printed on top of each other.
Color overprint(Color a, Color b) =>
    Color.from(alpha: 1, red: a.r * b.r, green: a.g * b.g, blue: a.b * b.b);

/// Color picker + palettes. With a [controller] it edits the open page's ink;
/// from the library (no controller) it only manages palettes.
class ColorScreen extends StatefulWidget {
  const ColorScreen({super.key, this.controller});

  final CanvasController? controller;

  @override
  State<ColorScreen> createState() => _ColorScreenState();
}

class _ColorScreenState extends State<ColorScreen> {
  late HSVColor _hsv;

  CanvasController? get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(_c?.color ?? TintaColors.risoBlue);
  }

  void _preview(HSVColor hsv) => setState(() => _hsv = hsv);
  void _apply() => _c?.useColor(_hsv.toColor());

  String? _photoMessage;

  Future<void> _fromPhoto() async {
    final studio = StudioScope.of(context);
    setState(() => _photoMessage = null);
    try {
      final colors = await PhotoPalette.pick();
      if (colors == null || !mounted) return;
      if (colors.isEmpty) {
        setState(() => _photoMessage = 'Couldn’t find colors in that photo.');
        return;
      }
      final now = DateTime.now();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      studio.addPalette(
        'From photo · ${months[now.month - 1]} ${now.day}',
        colors,
      );
    } catch (e) {
      if (mounted) setState(() => _photoMessage = 'Couldn’t open photos: $e');
    }
  }

  void _pick(Color color) {
    setState(() => _hsv = HSVColor.fromColor(color));
    _c?.useColor(color);
  }

  @override
  Widget build(BuildContext context) {
    final studio = StudioScope.of(context);
    final ink = _hsv.toColor();
    final c = _c;
    final risoInks = c?.risoInks ?? const [];
    final other = risoInks.length == 2
        ? risoInks.firstWhere((x) => x != c!.color, orElse: () => risoInks[1])
        : null;
    final partner = other ?? TintaColors.fluoroOrange;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              spacing: 10,
              children: [
                TileIconButton(
                  icon: TintaIcons.back,
                  label: c == null ? 'Back' : 'Back to canvas',
                  background: TintaColors.surface,
                  foreground: TintaColors.studioInk,
                  borderColor: TintaColors.line,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Text(
                    c == null ? 'Palettes' : 'Color',
                    style: TintaType.display28,
                  ),
                ),
                if (c != null)
                  TileIconButton(
                    icon: TintaIcons.eyedropper,
                    label: 'Eyedropper: pick a color from the page',
                    strokeWidth: 2,
                    background: TintaColors.studioInk,
                    foreground: TintaColors.newsprint,
                    onPressed: () =>
                        Navigator.of(context).pop(colorScreenEyedropper),
                  ),
              ],
            ),
            if (c != null) ...[
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    Container(
                      width: 84,
                      decoration: BoxDecoration(
                        color: ink,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: TintaColors.surface,
                          border: Border.all(color: TintaColors.line),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            Text(
                              risoInks.length == 2 ? 'RISO INK' : 'CURRENT INK',
                              style: TintaType.mono(
                                11,
                                color: TintaColors.ink2,
                              ).copyWith(letterSpacing: 1),
                            ),
                            Text(
                              hexOf(ink),
                              style: TintaType.mono(
                                22,
                                weight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              spacing: 6,
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: overprint(ink, partner),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Overprints with ${hexOf(partner)} as ${hexOf(overprint(ink, partner))}',
                                    style: TintaType.body(
                                      13,
                                      color: TintaColors.ink2,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (risoInks.length == 2) ...[
                const SizedBox(height: 10),
                Text(
                  'Riso page: it prints with two inks. Choosing a palette uses its first two colors; '
                  'tapping a color swaps the selected ink.',
                  style: TintaType.body13,
                ),
              ],
              const SizedBox(height: 16),
              SaturationValueBox(
                hsv: _hsv,
                onChanged: _preview,
                onChangeEnd: _apply,
              ),
              const SizedBox(height: 16),
              HueBar(hsv: _hsv, onChanged: _preview, onChangeEnd: _apply),
            ],
            const SizedBox(height: 22),
            // Reflows onto two lines rather than overflowing (narrow phones,
            // large text).
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                if (c !=
                    null) // from the library, the page title already says "Palettes"
                  Text(
                    'Palettes',
                    style: TintaType.display(20, weight: FontWeight.w600),
                  ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed(
                        Routes.palette,
                        arguments: PaletteEditorArgs(startWith: c?.color),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: TintaColors.risoBlue,
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: TintaType.body(14, weight: FontWeight.w500),
                      ),
                      icon: const TintaIcon(
                        TintaIcons.plus,
                        size: 16,
                        strokeWidth: 2.4,
                        color: TintaColors.risoBlue,
                      ),
                      label: const Text('New palette'),
                    ),
                    TextButton(
                      onPressed: _fromPhoto,
                      style: TextButton.styleFrom(
                        foregroundColor: TintaColors.risoBlue,
                        minimumSize: const Size(44, 44),
                        textStyle: TintaType.body(14, weight: FontWeight.w500),
                      ),
                      child: const Text('From photo'),
                    ),
                  ],
                ),
              ],
            ),
            if (_photoMessage != null)
              Text(_photoMessage!, style: TintaType.body13),
            const SizedBox(height: 10),
            for (final p in studio.palettes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PaletteCard(
                  palette: p,
                  active: p.id == studio.activePalette.id,
                  onActivate: () {
                    studio.activePalette = p;
                    // On a riso page the palette's first two colors become its inks.
                    if (risoInks.length == 2) {
                      c!.useRisoPalette(p.colors);
                      setState(() => _hsv = HSVColor.fromColor(c.color));
                    }
                  },
                  onPick: c == null ? null : _pick,
                  selected: c?.color,
                  onEdit: studio.isUserPalette(p)
                      ? () => Navigator.of(context).pushNamed(
                          Routes.palette,
                          arguments: PaletteEditorArgs(paletteId: p.id),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({
    required this.palette,
    required this.active,
    required this.onActivate,
    required this.onPick,
    required this.selected,
    this.onEdit,
  });

  /// Your own palettes can be edited (and deleted from the editor).
  final VoidCallback? onEdit;

  final Palette palette;
  final bool active;
  final VoidCallback onActivate;
  final ValueChanged<Color>? onPick;
  final Color? selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TintaColors.surface,
        border: Border.all(
          color: active ? TintaColors.studioInk : TintaColors.line,
          width: active ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(TintaRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          // Name + USE/ACTIVE is one control; edit is its own button, so
          // screen readers can reach both.
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  selected: active,
                  label:
                      '${palette.name} palette${active ? ', active' : ''}. Use on canvas.',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: onActivate,
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 32,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              palette.name,
                              style: TintaType.body(
                                14,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            active ? 'ACTIVE' : 'USE',
                            style: TintaType.mono(
                              11,
                              color: active
                                  ? TintaColors.ink2
                                  : TintaColors.risoBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (onEdit != null)
                Semantics(
                  button: true,
                  label: 'Edit ${palette.name}',
                  excludeSemantics: true,
                  child: InkResponse(
                    onTap: onEdit,
                    radius: 22,
                    child: const SizedBox(
                      width: 40,
                      height: 32,
                      child: Center(
                        child: TintaIcon(
                          TintaIcons.pencil,
                          size: 16,
                          color: TintaColors.ink2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Row(
            spacing: 6,
            children: [
              for (final color in palette.colors)
                Expanded(
                  child: Semantics(
                    button: onPick != null,
                    selected: color == selected,
                    label: hexOf(color),
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: onPick == null ? onActivate : () => onPick!(color),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(10),
                          border: color == selected
                              ? Border.all(
                                  color: TintaColors.studioInk,
                                  width: 3,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
