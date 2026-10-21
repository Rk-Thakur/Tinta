import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../icons.dart';

enum PillVariant { ink, accent, outline, light, blue }

/// The 52px pill button. `compact` gives the 40px variant used in sheets ("Done").
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PillVariant.ink,
    this.trailing,
    this.leading,
    this.compact = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillVariant variant;
  final TintaIcons? trailing;
  final TintaIcons? leading;
  final bool compact;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      PillVariant.ink => (TintaColors.studioInk, Colors.white, null),
      PillVariant.accent => (
        TintaColors.fluoroOrange,
        TintaColors.studioInk,
        null,
      ),
      PillVariant.outline => (
        Colors.transparent,
        TintaColors.studioInk,
        TintaColors.studioInk,
      ),
      PillVariant.light => (TintaColors.newsprint, TintaColors.studioInk, null),
      PillVariant.blue => (TintaColors.risoBlue, Colors.white, null),
    };
    final height = compact ? 40.0 : 52.0;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[
          TintaIcon(leading!, size: 18, color: fg, strokeWidth: 2.2),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TintaType.body(
            compact ? 14 : 16,
            weight: FontWeight.w700,
            color: fg,
            height: 1,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          TintaIcon(trailing!, size: 18, color: fg, strokeWidth: 2.2),
        ],
      ],
    );
    return SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: Material(
        color: bg,
        shape: StadiumBorder(
          side: border == null
              ? BorderSide.none
              : BorderSide(color: border, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 22),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Square icon button ("tile"): 44 in headers, 48 in the dock, 52 for primary actions.
class TileIconButton extends StatelessWidget {
  const TileIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 44,
    this.radius = TintaRadii.sm,
    this.background = TintaColors.dock,
    this.foreground = TintaColors.newsprint,
    this.borderColor,
    this.iconSize = 20,
    this.strokeWidth = 2.2,
    this.badge,
    this.selected,
  });

  final TintaIcons icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final double radius;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final double iconSize;
  final double strokeWidth;
  final String? badge;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final button = Semantics(
      button: true,
      label: label,
      selected: selected,
      enabled: onPressed != null,
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: TintaIcon(
                icon,
                size: iconSize,
                color: foreground,
                strokeWidth: strokeWidth,
              ),
            ),
          ),
        ),
      ),
    );
    if (badge == null) return button;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            constraints: const BoxConstraints(minWidth: 18),
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TintaColors.fluoroOrange,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              badge!,
              style: TintaType.mono(
                11,
                weight: FontWeight.w600,
                color: TintaColors.studioInk,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Round ink swatch button.
class ColorDot extends StatelessWidget {
  const ColorDot({
    super.key,
    required this.color,
    required this.label,
    this.onPressed,
    this.size = 30,
    this.selected = false,
    this.ringColor = TintaColors.newsprint,
    this.outline,
  });

  final Color color;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final bool selected;
  final Color ringColor;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? Border.all(color: ringColor, width: size >= 44 ? 3 : 2)
        : (outline == null ? null : Border.all(color: outline!));
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        // Keep a 44px touch target around small dots.
        child: SizedBox.square(
          dimension: size < 44 ? 44 : size,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: border,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
