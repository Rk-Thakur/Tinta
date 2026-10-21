import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/widgets/widgets.dart';

/// Stand-in for screens not built yet.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TintaSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TileIconButton(
                icon: TintaIcons.back,
                label: 'Back',
                background: TintaColors.surface,
                foreground: TintaColors.studioInk,
                borderColor: TintaColors.line,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: TintaSpace.x6),
              Text(title, style: TintaType.display28),
              const SizedBox(height: TintaSpace.x2),
              Text('Not built yet.', style: TintaType.body13),
            ],
          ),
        ),
      ),
    );
  }
}
