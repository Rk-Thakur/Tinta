import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

enum ControlTone { light, studio }

/// Pill segmented control (Grid / Shelf / List, Off / Soft / Max, 1× / 4× / 16×).
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.tone = ControlTone.light,
    this.dense = false,
  });

  final List<T> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final ControlTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final light = tone == ControlTone.light;
    final track = light ? TintaColors.segmentTrack : TintaColors.dockRaised;
    final selBg = light ? TintaColors.surface : TintaColors.newsprint;
    final idle = light ? TintaColors.ink2 : TintaColors.studioSubtle;
    return Container(
      padding: EdgeInsets.all(dense ? 3 : 4),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(TintaRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            Semantics(
              button: true,
              selected: o == value,
              child: GestureDetector(
                onTap: () => onChanged(o),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  constraints: BoxConstraints(minHeight: dense ? 30 : 36),
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 16),
                  decoration: BoxDecoration(
                    color: o == value ? selBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(TintaRadii.pill),
                  ),
                  child: Text(
                    labelOf(o),
                    style: TintaType.body(
                      dense ? 12 : 14,
                      weight: o == value ? FontWeight.w700 : FontWeight.w400,
                      color: o == value ? TintaColors.studioInk : idle,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 52×32 toggle switch.
class TintaSwitch extends StatelessWidget {
  const TintaSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = TintaColors.risoBlue,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 52,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? activeColor : TintaColors.line,
            borderRadius: BorderRadius.circular(TintaRadii.pill),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slider with a 6px track and 24px thumb. Light tone has an outlined white thumb.
class TintaSlider extends StatelessWidget {
  const TintaSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.tone = ControlTone.light,
    this.fillColor,
    this.label,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final ControlTone tone;
  final Color? fillColor;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final light = tone == ControlTone.light;
    final fill =
        fillColor ?? (light ? TintaColors.studioInk : TintaColors.newsprint);
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: fill,
        inactiveTrackColor: light ? TintaColors.line : TintaColors.dockRaised,
        thumbShape: _RingThumb(
          fill: light ? Colors.white : fill,
          ring: light ? TintaColors.studioInk : null,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
        overlayColor: fill.withValues(alpha: 0.12),
        trackShape: const RoundedRectSliderTrackShape(),
        padding: EdgeInsets.zero,
        thumbSize: const WidgetStatePropertyAll(Size(24, 24)),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
        semanticFormatterCallback: (_) => label ?? '',
      ),
    );
  }
}

class _RingThumb extends SliderComponentShape {
  const _RingThumb({required this.fill, this.ring});

  final Color fill;
  final Color? ring;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(24);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 12, Paint()..color = fill);
    if (ring != null) {
      canvas.drawCircle(
        center,
        11,
        Paint()
          ..color = ring!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }
}

/// Labelled slider row: "Size ........ 12 px".
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.valueText,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.tone = ControlTone.studio,
    this.fillColor,
  });

  final String label;
  final String valueText;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final ControlTone tone;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final fg = tone == ControlTone.light
        ? TintaColors.studioInk
        : TintaColors.newsprint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: TintaType.body(14, color: fg)),
            ),
            Text(valueText, style: TintaType.mono(14, color: fg)),
          ],
        ),
        const SizedBox(height: 8),
        TintaSlider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          tone: tone,
          fillColor: fillColor,
          label: '$label $valueText',
        ),
      ],
    );
  }
}
