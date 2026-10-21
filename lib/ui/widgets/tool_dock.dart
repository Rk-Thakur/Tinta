import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../icons.dart';
import 'buttons.dart';

class DockTool<T> {
  const DockTool({required this.id, required this.icon, required this.label});

  final T id;
  final TintaIcons icon;
  final String label;
}

/// The single floating dock of studio mode. Active tool is filled newsprint.
class ToolDock<T> extends StatelessWidget {
  const ToolDock({
    super.key,
    required this.tools,
    required this.selected,
    required this.onSelect,
    this.trailing = const [],
  });

  final List<DockTool<T>> tools;
  final T selected;
  final ValueChanged<T> onSelect;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: TintaColors.dock,
        borderRadius: BorderRadius.circular(TintaRadii.dock),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in tools)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: TileIconButton(
                icon: t.icon,
                label: t.label,
                selected: t.id == selected,
                size: 48,
                radius: TintaRadii.md,
                iconSize: 22,
                strokeWidth: 2,
                background: t.id == selected
                    ? TintaColors.newsprint
                    : Colors.transparent,
                foreground: t.id == selected
                    ? TintaColors.studioInk
                    : TintaColors.newsprint,
                onPressed: () => onSelect(t.id),
              ),
            ),
          if (trailing.isNotEmpty) ...[
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: TintaColors.ink2,
            ),
            ...trailing,
          ],
        ],
      ),
    );
  }
}
