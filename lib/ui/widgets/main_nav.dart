import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../theme/tokens.dart';
import '../icons.dart';

enum MainTab { library, replays, palettes, settings }

/// Floating dark bottom nav with the orange "new canvas" button in the middle.
class MainNav extends StatelessWidget {
  const MainNav({super.key, required this.current});

  final MainTab current;

  /// Height above the home-indicator inset.
  static const height = 72.0;

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
      // Docked to the bottom edge: rounded on top, home-indicator space inside.
      child: Container(
        height: height + MediaQuery.paddingOf(context).bottom,
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.paddingOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: TintaColors.studioInk,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TintaRadii.dock),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 20,
              offset: Offset(0, -4),
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
                  child: const SizedBox.square(
                    dimension: 56,
                    child: Center(
                      child: TintaIcon(
                        TintaIcons.plus,
                        size: 26,
                        strokeWidth: 2.6,
                        color: TintaColors.studioInk,
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
