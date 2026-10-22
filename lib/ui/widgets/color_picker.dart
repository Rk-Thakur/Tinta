import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// "#2F4BFF".
String hexOf(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

/// Parses "#2F4BFF", "2f4bff" or "#24F" (alpha is always opaque).
Color? parseHex(String input) {
  var h = input.trim().replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length != 6 || !RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(h)) return null;
  return Color(0xFF000000 | int.parse(h, radix: 16));
}

class SaturationValueBox extends StatelessWidget {
  const SaturationValueBox({
    super.key,
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

class HueBar extends StatelessWidget {
  const HueBar({
    super.key,
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
