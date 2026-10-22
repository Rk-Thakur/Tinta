import 'package:flutter/material.dart';

import '../data/studio_store.dart';
import '../drawing/canvas_controller.dart';
import '../services/photo_palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/widgets/widgets.dart';

/// Returned when the user asks to sample a color from the page.
const colorScreenEyedropper = 'eyedropper';

String hexOf(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

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
                  'Riso page: picking a color replaces the selected ink, so the page keeps two inks.',
                  style: TintaType.body13,
                ),
              ],
              const SizedBox(height: 16),
              _SaturationValueBox(
                hsv: _hsv,
                onChanged: _preview,
                onChangeEnd: _apply,
              ),
              const SizedBox(height: 16),
              _HueBar(hsv: _hsv, onChanged: _preview, onChangeEnd: _apply),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: c == null
                      ? const SizedBox.shrink() // the page title already says "Palettes"
                      : Text(
                          'Palettes',
                          style: TintaType.display(20, weight: FontWeight.w600),
                        ),
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
            if (_photoMessage != null)
              Text(_photoMessage!, style: TintaType.body13),
            const SizedBox(height: 10),
            for (final p in studio.palettes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PaletteCard(
                  palette: p,
                  active: p.id == studio.activePalette.id,
                  onActivate: () => studio.activePalette = p,
                  onPick: c == null ? null : _pick,
                  selected: c?.color,
                  onRemove: studio.isUserPalette(p)
                      ? () => studio.removePalette(p)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SaturationValueBox extends StatelessWidget {
  const _SaturationValueBox({
    required this.hsv,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const height = 210.0;
        final width = constraints.maxWidth;
        void update(Offset p) => onChanged(
          hsv
              .withSaturation((p.dx / width).clamp(0.0, 1.0))
              .withValue(1 - (p.dy / height).clamp(0.0, 1.0)),
        );
        final hue = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
        return Semantics(
          label: 'Saturation and brightness',
          value:
              '${(hsv.saturation * 100).round()}% saturation, ${(hsv.value * 100).round()}% brightness',
          child: GestureDetector(
            onPanStart: (d) => update(d.localPosition),
            onPanUpdate: (d) => update(d.localPosition),
            onPanEnd: (_) => onChangeEnd(),
            onTapUp: (d) {
              update(d.localPosition);
              onChangeEnd();
            },
            child: SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(TintaRadii.lg),
                        gradient: LinearGradient(colors: [Colors.white, hue]),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(TintaRadii.lg),
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black, Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: hsv.saturation * width - 13,
                    top: (1 - hsv.value) * height - 13,
                    child: _Thumb(color: hsv.toColor(), size: 26),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HueBar extends StatelessWidget {
  const _HueBar({
    required this.hsv,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void update(Offset p) =>
            onChanged(hsv.withHue((p.dx / width).clamp(0.0, 1.0) * 360));
        return Semantics(
          label: 'Hue',
          value: '${hsv.hue.round()} degrees',
          child: GestureDetector(
            onHorizontalDragStart: (d) => update(d.localPosition),
            onHorizontalDragUpdate: (d) => update(d.localPosition),
            onHorizontalDragEnd: (_) => onChangeEnd(),
            onTapUp: (d) {
              update(d.localPosition);
              onChangeEnd();
            },
            child: SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: LinearGradient(
                        colors: [
                          for (var h = 0; h <= 360; h += 60)
                            HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: hsv.hue / 360 * width - 14,
                    child: _Thumb(
                      color: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Color(0x4D000000), spreadRadius: 1)],
    ),
  );
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({
    required this.palette,
    required this.active,
    required this.onActivate,
    required this.onPick,
    required this.selected,
    this.onRemove,
  });

  final VoidCallback? onRemove;

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
          Semantics(
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
                        style: TintaType.body(14, weight: FontWeight.w700),
                      ),
                    ),
                    if (onRemove != null)
                      Semantics(
                        button: true,
                        label: 'Remove ${palette.name}',
                        excludeSemantics: true,
                        child: InkResponse(
                          onTap: onRemove,
                          radius: 20,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: TintaIcon(
                              TintaIcons.close,
                              size: 14,
                              color: TintaColors.ink2,
                            ),
                          ),
                        ),
                      ),
                    Text(
                      active ? 'ACTIVE' : 'USE',
                      style: TintaType.mono(
                        11,
                        color: active ? TintaColors.ink2 : TintaColors.risoBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
