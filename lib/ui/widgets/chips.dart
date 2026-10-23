import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../icons.dart';

/// "On device" status badge: the app's promise that nothing syncs.
class OnDeviceBadge extends StatelessWidget {
  const OnDeviceBadge({
    super.key,
    this.text = 'On device',
    this.icon = TintaIcons.offline,
    this.alwaysDark = false,
  });

  /// Keep the dark pill in the dark theme too (e.g. over artwork).
  final bool alwaysDark;

  final String text;
  final TintaIcons icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: alwaysDark ? TintaInk.studioInk : TintaColors.studioInk,
        borderRadius: BorderRadius.circular(TintaRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TintaIcon(icon, size: 14, color: TintaColors.sun, strokeWidth: 2.4),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TintaType.mono(
                12,
                color: alwaysDark ? TintaInk.newsprint : TintaColors.newsprint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum ChipTone { light, studio }

/// Filter / category chip. Light tone: white with border, blue when selected.
/// Studio tone: raised grey, newsprint when selected.
class TintaChip extends StatelessWidget {
  const TintaChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.tone = ChipTone.light,
    this.selectedColor,
    this.height = 32,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final ChipTone tone;
  final Color? selectedColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final light = tone == ChipTone.light;
    final selBg =
        selectedColor ?? (light ? TintaColors.risoBlue : TintaInk.newsprint);
    final selFg = selBg.computeLuminance() > 0.4
        ? TintaInk.studioInk
        : Colors.white;
    final bg = selected
        ? selBg
        : (light ? TintaColors.surface : TintaColors.dockRaised);
    final fg = selected
        ? selFg
        : (light ? TintaColors.studioInk : TintaInk.newsprint);
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: bg,
        shape: StadiumBorder(
          side: light && !selected
              ? BorderSide(color: TintaColors.line)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TintaType.body(
                  height > 32 ? 13 : 14,
                  weight: selected
                      ? (light ? FontWeight.w500 : FontWeight.w700)
                      : FontWeight.w400,
                  color: fg,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Uppercase mono section label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: TintaType.label(color: color));
}
