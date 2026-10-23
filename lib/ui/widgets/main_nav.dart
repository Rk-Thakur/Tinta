import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../theme/tokens.dart';
import '../icons.dart';

enum MainTab { library, replays, palettes, settings }

/// Floating dark bottom nav with the orange "new canvas" button in the middle.
class MainNav extends StatelessWidget {
  const MainNav({super.key, required this.current});

  final MainTab current;

  static const height = 68.0;

  /// Gap from the screen edges (sides, and bottom when there's no home
  /// indicator); with one, the bar sits just above it.
  static const margin = 16.0;
  static double bottomOffset(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    return inset > 0 ? inset : margin;
  }

  @override
  Widget build(BuildContext context) {
    void go(String route, MainTab? tab) {
      if (tab == current) return;
      Navigator.of(context).pushNamed(route);
    }

    Widget item(MainTab tab, TintaIcons icon, String label, String route) =>
        _NavItem(
          icon: icon,
          label: label,
          active: tab == current,
          onTap: () => go(route, tab),
        );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Main',
      // A rounded pill near the bottom edge, with space all around it.
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          // Dark in both themes; lifted a little off the dark ground.
          color: TintaColors.isDark ? TintaColors.dock : TintaInk.studioInk,
          borderRadius: BorderRadius.circular(TintaRadii.dock),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            item(MainTab.library, TintaIcons.book, 'Library', Routes.library),
            item(MainTab.replays, TintaIcons.clock, 'Replays', Routes.replay),
            Semantics(
              button: true,
              label: 'New canvas',
              excludeSemantics: true,
              child: Material(
                color: TintaColors.fluoroOrange,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => go(Routes.newCanvas, null),
                  child: SizedBox.square(
                    dimension: 56,
                    child: Center(
                      child: TintaIcon(
                        TintaIcons.plus,
                        size: 26,
                        strokeWidth: 2.6,
                        color: TintaInk.studioInk,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            item(
              MainTab.palettes,
              TintaIcons.palette,
              'Palettes',
              Routes.color,
            ),
            item(
              MainTab.settings,
              TintaIcons.settings,
              'Settings',
              Routes.settings,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final TintaIcons icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: TintaIcon(
              icon,
              size: 24,
              color: active ? TintaColors.sun : TintaColors.studioMuted,
            ),
          ),
        ),
      ),
    );
  }
}
