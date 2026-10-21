import 'package:flutter/material.dart';

import '../data/library_store.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/widgets/widgets.dart';
import 'library_screen.dart';

/// "See all" from the library: every sketchbook as a shelf of covers.
class AllSketchbooksScreen extends StatelessWidget {
  const AllSketchbooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final books = LibraryScope.of(context).sketchbooks;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 14.0;
            final columns = constraints.maxWidth >= 600 ? 4 : 2;
            final width =
                (constraints.maxWidth -
                    TintaSpace.gutter * 2 -
                    gap * (columns - 1)) /
                columns;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                TintaSpace.gutter,
                8,
                TintaSpace.gutter,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Row(
                  children: [
                    TileIconButton(
                      icon: TintaIcons.back,
                      label: 'Back to library',
                      background: TintaColors.surface,
                      foreground: TintaColors.studioInk,
                      borderColor: TintaColors.line,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 10),
                    Text('Sketchbooks', style: TintaType.display28),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: gap,
                  runSpacing: 20,
                  children: [
                    for (final b in books) BookTile(book: b, width: width),
                    NewBookTile(width: width),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
