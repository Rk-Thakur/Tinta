import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/routes.dart';
import '../data/library_store.dart';
import '../data/models.dart';
import '../data/prefs.dart';
import '../data/studio_store.dart';
import '../drawing/canvas_controller.dart';
import '../drawing/page_canvas.dart';
import 'color_screen.dart';
import 'export_sheet.dart';
import 'layers_screen.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/widgets/dialogs.dart';
import '../ui/widgets/size_slider.dart';
import '../ui/widgets/widgets.dart';

/// Studio mode: dark chrome, the page, one floating dock.
class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key, required this.args});

  final CanvasArgs args;

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  late LibraryStore _store;
  late SketchPage _page;
  CanvasController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    _store = LibraryScope.of(context);
    final args = widget.args;
    if (args.prompt != null) {
      _page = _store.addPage(
        SketchPage(
          id: '',
          number: 0,
          title: args.prompt!.text,
          paper: PaperType.smooth,
        ),
      );
    } else {
      _page = _store.page(args.page!.id) ?? args.page!;
    }
    _controller = CanvasController(
      layers: _page.layers,
      pageSize: _page.size,
      riso: _page.riso,
      ink: _page.riso ? _page.risoInks.first : _page.paper.defaultInk,
      risoInks: _page.riso ? _page.risoInks : const [],
      onCommit: (layers) {
        // Build on the stored page so renames elsewhere aren't overwritten.
        final stored = _store.page(_page.id) ?? _page;
        final today = dayKey(DateTime.now());
        _page = stored.copyWith(
          layers: layers,
          drawnDays: stored.drawnDays.contains(today)
              ? null
              : [...stored.drawnDays, today],
        );
        _store.updatePage(_page);
      },
      onInksChanged: (inks) {
        _page = (_store.page(_page.id) ?? _page).copyWith(risoInks: inks);
        _store.updatePage(_page);
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  CanvasController get _c => _controller!;

  /// Riso pages show their two inks; other pages the active palette plus
  /// the current color when it came from the picker.
  List<(Color, String)> _inks(StudioStore studio) {
    if (_page.riso) {
      return [for (final c in _c.risoInks) (c, 'Ink ${hexOf(c)}')];
    }
    final colors = [...studio.activePalette.colors.take(4)];
    if (!colors.contains(_c.color)) colors.add(_c.color);
    return [for (final c in colors) (c, 'Ink ${hexOf(c)}')];
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final prefs = PrefsScope.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: Theme.of(context)
            .copyWith(scaffoldBackgroundColor: TintaColors.studioInk),
        child: Scaffold(
          body: ListenableBuilder(
            listenable: _c,
            builder: (context, _) => Stack(
              children: [
                Column(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: _TopBar(
                        page: _store.page(_page.id) ?? _page,
                        controller: _c,
                      ),
                    ),
                    Expanded(
                      child: PageCanvas(
                        controller: _c,
                        paper: _page.paper,
                        twoFingerUndo: prefs.twoFingerUndo,
                        padding: EdgeInsets.fromLTRB(
                          20,
                          12,
                          20,
                          150 + bottomInset,
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: prefs.leftHanded ? 8 : null,
                  right: prefs.leftHanded ? null : 8,
                  top: 0,
                  bottom: 120 + bottomInset,
                  child: Center(
                    child: VerticalSizeSlider(
                      value: _c.size,
                      min: CanvasController.minSize,
                      max: CanvasController.maxSize,
                      enabled: _c.tool != CanvasTool.lasso,
                      onChanged: (v) => _c.size = v,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 28 + bottomInset,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 10,
                    children: [
                      if (_c.picking)
                        _PickBar(controller: _c)
                      else if (_c.selection.isNotEmpty)
                        _SelectionBar(controller: _c),
                      _InkRow(
                        inks: _inks(StudioScope.of(context)),
                        controller: _c,
                      ),
                      _Dock(controller: _c),
                    ],
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.page, required this.controller});

  final SketchPage page;
  final CanvasController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    Widget tile(
      TintaIcons icon,
      String label,
      VoidCallback? onPressed, {
      String? badge,
      bool light = false,
    }) {
      return TileIconButton(
        icon: icon,
        label: label,
        badge: badge,
        background: light ? TintaColors.newsprint : TintaColors.dock,
        foreground: light
            ? TintaColors.studioInk
            : (onPressed == null
                  ? TintaColors.studioDisabled
                  : TintaColors.newsprint),
        onPressed: onPressed,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        spacing: 6,
        children: [
          tile(TintaIcons.back, 'Back', () => Navigator.of(context).maybePop()),
          Expanded(
            child: Semantics(
              button: true,
              hint: 'Rename page',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  final title = await promptText(
                    context,
                    title: 'Rename page',
                    initial: page.title ?? '',
                  );
                  if (title != null && context.mounted) {
                    LibraryScope.of(context).renamePage(page.id, title);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        page.title ?? 'Untitled',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TintaType.body(
                          15,
                          weight: FontWeight.w700,
                          color: TintaColors.newsprint,
                          height: 1.3,
                        ),
                      ),
                      Text(
                        'Saved on device · p.${page.number}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TintaType.mono(
                          11,
                          color: TintaColors.studioMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          tile(TintaIcons.undo, 'Undo', c.canUndo ? c.undo : null),
          tile(TintaIcons.redo, 'Redo', c.canRedo ? c.redo : null),
          tile(
            TintaIcons.layers,
            'Layers',
            () => Navigator.of(context).pushNamed(
              Routes.layers,
              arguments: LayersArgs(controller: c, paper: page.paper),
            ),
            badge: '${c.layers.length}',
          ),
          tile(
            TintaIcons.export,
            'Export',
            () => Navigator.of(context)
                .pushNamed(Routes.export, arguments: ExportArgs(page: page)),
            light: true,
          ),
        ],
      ),
    );
  }
}

class _InkRow extends StatelessWidget {
  const _InkRow({required this.inks, required this.controller});

  final List<(Color, String)> inks;
  final CanvasController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final inking = c.tool != CanvasTool.eraser && c.tool != CanvasTool.lasso;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: TintaColors.dock,
        borderRadius: BorderRadius.circular(TintaRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (color, label) in inks)
            ColorDot(
              color: color,
              label: label,
              selected: inking && c.color == color,
              outline: color == TintaColors.studioInk ? TintaColors.ink2 : null,
              onPressed: () => c.color = color,
            ),
          Semantics(
            button: true,
            label: 'More colors',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.of(context)
                    .pushNamed(Routes.color, arguments: c);
                if (result == colorScreenEyedropper) c.picking = true;
              },
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: TintaColors.dockRaised,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: TintaIcon(
                        TintaIcons.plus,
                        size: 16,
                        strokeWidth: 2.6,
                        color: TintaColors.newsprint,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock({required this.controller});

  final CanvasController controller;

  static const _icons = {
    CanvasTool.pencil: TintaIcons.pencil,
    CanvasTool.ink: TintaIcons.brush,
    CanvasTool.marker: TintaIcons.marker,
    CanvasTool.eraser: TintaIcons.eraser,
    CanvasTool.lasso: TintaIcons.lasso,
  };

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: ToolDock<CanvasTool>(
        tools: [
          for (final t in CanvasTool.values)
            DockTool(id: t, icon: _icons[t]!, label: t.label),
        ],
        selected: controller.tool,
        onSelect: (t) {
          HapticFeedback.selectionClick();
          controller.tool = t;
        },
        trailing: [
          TileIconButton(
            icon: TintaIcons.sliders,
            label: 'Brush settings',
            size: 48,
            radius: TintaRadii.md,
            iconSize: 22,
            strokeWidth: 2,
            background: Colors.transparent,
            foreground: TintaColors.newsprint,
            onPressed: () =>
                Navigator.of(context)
                    .pushNamed(Routes.brushes, arguments: controller),
          ),
        ],
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.controller});

  final CanvasController controller;

  @override
  Widget build(BuildContext context) {
    final n = controller.selection.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      decoration: BoxDecoration(
        color: TintaColors.dock,
        borderRadius: BorderRadius.circular(TintaRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Text(
            '$n ${n == 1 ? 'stroke' : 'strokes'} · drag to move',
            style: TintaType.mono(12, color: TintaColors.studioSubtle),
          ),
          TextButton(
            onPressed: controller.deleteSelection,
            style: TextButton.styleFrom(
              foregroundColor: TintaColors.fluoroOrange,
              minimumSize: const Size(44, 40),
            ),
            child: const Text('Delete'),
          ),
          PillButton(
            label: 'Done',
            variant: PillVariant.light,
            compact: true,
            onPressed: controller.clearSelection,
          ),
        ],
      ),
    );
  }
}

class _PickBar extends StatelessWidget {
  const _PickBar({required this.controller});

  final CanvasController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      decoration: BoxDecoration(
        color: TintaColors.sun,
        borderRadius: BorderRadius.circular(TintaRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          const TintaIcon(
            TintaIcons.eyedropper,
            size: 18,
            color: TintaColors.studioInk,
          ),
          Text(
            'Tap the page to pick a color',
            style: TintaType.body(14, weight: FontWeight.w500),
          ),
          PillButton(
            label: 'Cancel',
            compact: true,
            onPressed: () => controller.picking = false,
          ),
        ],
      ),
    );
  }
}
