import 'package:flutter/material.dart';

import '../data/library_store.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../screens/all_sketchbooks_screen.dart';
import '../drawing/canvas_controller.dart';
import '../screens/brush_studio_sheet.dart';
import '../screens/canvas_screen.dart';
import '../screens/color_screen.dart';
import '../screens/export_sheet.dart';
import '../screens/layers_screen.dart';
import '../screens/kit_screen.dart';
import '../screens/library_screen.dart';
import '../screens/new_page_sheet.dart';
import '../screens/onboarding_screen.dart';
import '../screens/palette_editor_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/replay_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/sketchbook_sheet.dart';
import '../screens/sketchbook_screen.dart';

/// What the canvas opens on: an existing page, or a fresh one for a prompt.
/// Which page the canvas opens. The page must already be in the library.
class CanvasArgs {
  const CanvasArgs.page(this.page, {this.bookId});

  final SketchPage page;
  final String? bookId;
}

/// One route per artboard in the design kit.
abstract final class Routes {
  static const kit = '/kit';
  static const onboarding = '/onboarding';
  static const library = '/';
  static const sketchbooks = '/sketchbooks';
  static const book = '/book';
  static const palette = '/palette';
  static const sketchbook = '/sketchbook';
  static const newCanvas = '/new';
  static const canvas = '/canvas';
  static const brushes = '/brushes';
  static const layers = '/layers';
  static const color = '/color';
  static const replay = '/replay';
  static const export = '/export';
  static const settings = '/settings';

  /// (route, title) for every screen; drives the kit's screen index.
  static const all = <(String, String)>[
    (onboarding, '01 Onboarding'),
    (library, '02 Library'),
    (sketchbook, '03 Sketchbook'),
    (newCanvas, '04 New canvas'),
    (canvas, '05 Canvas'),
    (brushes, '06 Brush studio'),
    (layers, '07 Layers'),
    (color, '08 Color & palettes'),
    (replay, '09 Stroke replay'),
    (export, '10 Export & share'),
    (settings, '11 Settings'),
  ];

  static Route<dynamic> generate(RouteSettings settings) {
    if (settings.name == newCanvas) {
      return ModalBottomSheetRoute<void>(
        settings: settings,
        isScrollControlled: true,
        modalBarrierColor: const Color(0x99000000),
        builder: (_) => NewPageSheet(bookId: settings.arguments as String?),
      );
    }
    if (settings.name == book) {
      return ModalBottomSheetRoute<void>(
        settings: settings,
        isScrollControlled: true,
        modalBarrierColor: const Color(0x99000000),
        builder: (_) => SketchbookSheet(bookId: settings.arguments as String?),
      );
    }
    if (settings.name == export && settings.arguments is ExportArgs) {
      return ModalBottomSheetRoute<void>(
        settings: settings,
        isScrollControlled: true,
        modalBarrierColor: const Color(0x99000000),
        builder: (_) => ExportSheet(args: settings.arguments! as ExportArgs),
      );
    }
    if (settings.name == brushes && settings.arguments is CanvasController) {
      return ModalBottomSheetRoute<void>(
        settings: settings,
        isScrollControlled: true,
        backgroundColor: TintaColors.dock,
        modalBarrierColor: const Color(0x66000000),
        builder: (_) => BrushStudioSheet(
          controller: settings.arguments! as CanvasController,
        ),
      );
    }
    final Widget page = switch (settings.name) {
      layers when settings.arguments is LayersArgs => LayersScreen(
        args: settings.arguments! as LayersArgs,
      ),
      replay => _replay(settings.arguments),
      Routes.settings => const SettingsScreen(),
      palette => PaletteEditorScreen(
        args:
            settings.arguments as PaletteEditorArgs? ??
            const PaletteEditorArgs(),
      ),
      color => ColorScreen(controller: settings.arguments as CanvasController?),
      canvas when settings.arguments is CanvasArgs => CanvasScreen(
        args: settings.arguments! as CanvasArgs,
      ),
      kit => const KitScreen(),
      onboarding => const OnboardingScreen(),
      library => const LibraryScreen(),
      sketchbooks => const AllSketchbooksScreen(),
      sketchbook => SketchbookScreen(
        bookId: settings.arguments as String? ?? 'morning',
      ),
      _ => PlaceholderScreen(
        title: all
            .firstWhere(
              (r) => r.$1 == settings.name,
              orElse: () => (settings.name ?? '', 'Unknown'),
            )
            .$2,
      ),
    };
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }

  /// Replay a sketchbook (its id), a single page, or list all replays.
  static Widget _replay(Object? args) => switch (args) {
    SketchPage page => Builder(
      builder: (context) {
        final fresh = LibraryScope.of(context).page(page.id) ?? page;
        return ReplayScreen(
          args: ReplayArgs(pages: [fresh], title: fresh.title ?? 'Untitled'),
        );
      },
    ),
    String bookId => Builder(
      builder: (context) {
        final book = LibraryScope.of(context).sketchbook(bookId);
        if (book == null) return const ReplaysScreen();
        // Books list newest first; replay from the first page.
        return ReplayScreen(
          args: ReplayArgs(
            pages: book.pages.reversed.toList(),
            title: book.title,
          ),
        );
      },
    ),
    _ => const ReplaysScreen(),
  };
}
