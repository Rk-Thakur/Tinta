import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/studio_store.dart';
import '../drawing/brushes.dart';
import '../drawing/canvas_controller.dart';
import '../drawing/stroke.dart';
import '../drawing/stroke_renderer.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/widgets/widgets.dart';

/// Bottom sheet over the canvas: pick a brush and tune size, opacity,
/// paper grain and smoothing for the current dock slot.
class BrushStudioSheet extends StatefulWidget {
  const BrushStudioSheet({super.key, required this.controller});

  final CanvasController controller;

  @override
  State<BrushStudioSheet> createState() => _BrushStudioSheetState();
}

class _BrushStudioSheetState extends State<BrushStudioSheet> {
  late BrushCategory _category;

  CanvasController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    if (_c.tool == CanvasTool.lasso || _c.tool == CanvasTool.eraser) {
      _c.tool = CanvasTool.pencil;
    }
    _category = _c.preset.category;
  }

  List<BrushPreset> _presetsIn(BrushCategory cat, StudioStore studio) =>
      cat == BrushCategory.mine
      ? studio.myBrushes
      : [
          for (final b in Brushes.builtIn)
            if (b.category == cat) b,
        ];

  @override
  Widget build(BuildContext context) {
    final studio = StudioScope.of(context);
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final presets = _presetsIn(_category, studio);
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: TintaInk.ink2,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Brush studio',
                        style: TintaType.display(26, color: TintaInk.newsprint),
                      ),
                    ),
                    PillButton(
                      label: 'Done',
                      variant: PillVariant.light,
                      compact: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 8,
                    children: [
                      for (final cat in BrushCategory.values)
                        TintaChip(
                          label: cat.label,
                          tone: ChipTone.studio,
                          height: 34,
                          selected: cat == _category,
                          onTap: () => setState(() => _category = cat),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Room for three rows so the sheet doesn't jump between categories.
                Container(
                  constraints: const BoxConstraints(minHeight: 3 * 64 + 2 * 8),
                  alignment: Alignment.topCenter,
                  child: presets.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: TintaInk.studioInk,
                            borderRadius: BorderRadius.circular(TintaRadii.md),
                          ),
                          child: Text(
                            'No brushes of your own yet. Tune any brush below, then “Save as my brush”.',
                            style: TintaType.body(
                              14,
                              color: TintaColors.studioSubtle,
                            ),
                          ),
                        )
                      : Column(
                          spacing: 8,
                          children: [
                            for (final p in presets)
                              _PresetRow(
                                preset: p,
                                selected: p.id == _c.settings.presetId,
                                onTap: () => _c.selectPreset(p),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                _Settings(controller: _c, studio: studio),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final BrushPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: preset.name,
      excludeSemantics: true,
      child: Material(
        color: TintaInk.studioInk,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TintaRadii.md),
          side: selected
              ? const BorderSide(color: TintaColors.sun, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 14),
                SizedBox(
                  width: 110,
                  child: Text(
                    preset.name,
                    maxLines: 2,
                    style: TintaType.body(
                      15,
                      weight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: TintaInk.newsprint,
                      height: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: CustomPaint(
                      painter: _PreviewPainter(preset),
                      child: const SizedBox(height: 40),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws a sample wave with the real stroke renderer.
class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.preset);

  final BrushPreset preset;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = <StrokePoint>[
      for (var i = 0; i <= 40; i++)
        StrokePoint(
          8 + (size.width - 16) * i / 40,
          size.height / 2 + math.sin(i / 40 * math.pi * 2) * size.height * 0.25,
        ),
    ];
    final stroke = Stroke(
      id: 0,
      brush: preset.kind,
      color: TintaInk.newsprint,
      size: math.min(preset.size, 14),
      opacity: preset.opacity,
      presetId: preset.id,
      grain: preset.grain,
      smoothing: preset.smoothing,
      points: pts,
    );
    // Own transparent layer: multiply brushes then show their true color
    // instead of vanishing into the dark row.
    canvas.saveLayer(Offset.zero & size, Paint());
    StrokeRenderer.paintStroke(canvas, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.preset != preset;
}

class _Settings extends StatelessWidget {
  const _Settings({required this.controller, required this.studio});

  final CanvasController controller;
  final StudioStore studio;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TintaInk.studioInk,
        borderRadius: BorderRadius.circular(TintaRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          LabeledSlider(
            label: 'Size',
            valueText: '${c.size.round()} px',
            value: c.size,
            min: CanvasController.minSize,
            max: CanvasController.maxSize,
            onChanged: (v) => c.size = v.roundToDouble(),
          ),
          LabeledSlider(
            label: 'Opacity',
            valueText: '${(c.opacity * 100).round()}%',
            value: c.opacity,
            min: 0.05,
            onChanged: (v) => c.opacity = v,
          ),
          LabeledSlider(
            label: 'Paper grain',
            valueText: '${(c.grain * 100).round()}%',
            value: c.grain,
            fillColor: TintaColors.sun,
            onChanged: (v) => c.grain = v,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Stroke smoothing',
                  style: TintaType.body(14, color: TintaInk.newsprint),
                ),
              ),
              SegmentedPills<Smoothing>(
                options: Smoothing.values,
                value: c.smoothing,
                labelOf: (s) => s.label,
                tone: ControlTone.studio,
                dense: true,
                onChanged: (s) => c.smoothing = s,
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                final saved = studio.saveBrush(
                  c.preset,
                  size: c.size,
                  opacity: c.opacity,
                  grain: c.grain,
                  smoothing: c.smoothing,
                );
                c.selectPreset(saved);
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(
                    content: Text('Saved “${saved.name}” to Mine.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: TintaColors.sun,
                minimumSize: const Size(44, 44),
              ),
              icon: const TintaIcon(
                TintaIcons.plus,
                size: 18,
                strokeWidth: 2.4,
                color: TintaColors.sun,
              ),
              label: const Text('Save as my brush'),
            ),
          ),
        ],
      ),
    );
  }
}
