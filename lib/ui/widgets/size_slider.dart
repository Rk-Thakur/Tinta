import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// The studio's vertical brush-size rail. Uses a square-root curve so small
/// sizes (where precision matters) get most of the travel.
class VerticalSizeSlider extends StatelessWidget {
  const VerticalSizeSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.enabled = true,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final bool enabled;

  double get _t => math.sqrt(((value - min) / (max - min)).clamp(0.0, 1.0));
  double _fromT(double t) => min + (max - min) * t * t;

  @override
  Widget build(BuildContext context) {
    const width = 40.0;
    const height = 230.0;
    const labelSpace = 30.0;
    const trackLength = height - labelSpace * 2;

    void update(Offset local) {
      final t = 1 - ((local.dy - labelSpace) / trackLength).clamp(0.0, 1.0);
      onChanged(_fromT(t).roundToDouble().clamp(min, max));
    }

    final step = (max - min) / 30;
    return Semantics(
      label: 'Brush size',
      value: value.round().toString(),
      enabled: enabled,
      increasedValue: (value + step).clamp(min, max).round().toString(),
      decreasedValue: (value - step).clamp(min, max).round().toString(),
      onIncrease: enabled
          ? () => onChanged((value + step).clamp(min, max))
          : null,
      onDecrease: enabled
          ? () => onChanged((value - step).clamp(min, max))
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: enabled ? (d) => update(d.localPosition) : null,
          onVerticalDragUpdate: enabled ? (d) => update(d.localPosition) : null,
          onTapDown: enabled
              ? (d) {
                  HapticFeedback.selectionClick();
                  update(d.localPosition);
                }
              : null,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: TintaColors.dock,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: labelSpace,
                  child: Center(
                    child: Text(
                      '${value.round()}',
                      style: TintaType.mono(
                        10,
                        color: TintaColors.studioSubtle,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: trackLength,
                  width: width,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 6,
                        decoration: BoxDecoration(
                          color: TintaColors.dockRaised,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Container(
                        width: 6,
                        height: trackLength * _t,
                        decoration: BoxDecoration(
                          color: TintaColors.newsprint,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Positioned(
                        bottom: trackLength * _t - 12,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: TintaColors.newsprint,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: labelSpace,
                  child: Center(
                    child: Text(
                      'SIZE',
                      style: TintaType.mono(
                        10,
                        color: TintaColors.studioSubtle,
                      ),
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
