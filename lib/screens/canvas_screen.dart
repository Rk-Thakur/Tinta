import 'dart:async';

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
import '../ui/widgets/color_picker.dart';
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
  final _viewport = PageViewport();

  /// Focus mode: rail and dock slide away while ink is going down, and
  /// come back shortly after the pen lifts (not between quick strokes).
  bool _chromeHidden = false;
  Timer? _showChromeTimer;
  static const _showChromeDelay = Duration(milliseconds: 700);

  void _onControllerChanged() {
    if (_c.isInking) {
      _showChromeTimer?.cancel();
      if (!_chromeHidden) setState(() => _chromeHidden = true);
    } else if (_chromeHidden && !(_showChromeTimer?.isActive ?? false)) {
      _showChromeTimer = Timer(_showChromeDelay, () {
        if (mounted && !_c.isInking) setState(() => _chromeHidden = false);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    _store = LibraryScope.of(context);
    // The page always exists before the canvas opens (creating one here,
    // mid-build, would rebuild the library during build).
    final args = widget.args;
    _page = _store.page(args.page.id) ?? args.page;
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
    _controller!.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _showChromeTimer?.cancel();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _viewport.dispose();
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
            builder: (context, _) {
              // The page fills the screen from just under the status bar to
              // just above the home indicator. Top bar, rail and dock float
              // over its edges and slide away while ink goes down.
              final topInset = MediaQuery.paddingOf(context).top;
              final pageTop = topInset + 8;
              final pageBottom = 16 + bottomInset;
              final topBarSpace = topInset + 64;
              final dockSpace = 92 + bottomInset;
              final railLeft = prefs.leftHanded;
              final hidden = _chromeHidden;
              return Stack(
                children: [
                  Positioned.fill(
                    child: PageCanvas(
                      controller: _c,
                      paper: _page.paper,
                      twoFingerUndo: prefs.twoFingerUndo,
                      viewport: _viewport,
                      padding: EdgeInsets.fromLTRB(12, pageTop, 12, pageBottom),
                    ),
                  ),
                  // Top bar.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: _SlideAway(
                      hidden: hidden,
                      offset: const Offset(0, -1.4),
                      child: SafeArea(
                        bottom: false,
                        child: _TopBar(
                          page: _store.page(_page.id) ?? _page,
                          controller: _c,
                        ),
                      ),
                    ),
                  ),
                  // Size rail with the inks right below it.
                  Positioned(
                    left: railLeft ? 6 : null,
                    right: railLeft ? null : 6,
                    top: topBarSpace,
                    bottom: dockSpace,
                    child: _SlideAway(
                      hidden: hidden,
                      offset: Offset(railLeft ? -1.4 : 1.4, 0),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 10,
                            children: [
                              VerticalSizeSlider(
                                value: _c.size,
                                min: CanvasController.minSize,
                                max: CanvasController.maxSize,
                                enabled: _c.tool != CanvasTool.lasso,
                                onChanged: (v) => _c.size = v,
                              ),
                              _InkRow(
                                inks: _inks(StudioScope.of(context)),
                                controller: _c,
                                vertical: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: topBarSpace + 6,
                    left: railLeft ? null : 20,
                    right: railLeft ? 20 : null,
                    child: _ZoomChip(viewport: _viewport),
                  ),
                  // Dock (and the lasso / eyedropper bars above it).
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 20 + bottomInset,
                    child: _SlideAway(
                      hidden: hidden,
                      offset: const Offset(0, 1.6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 10,
                        children: [
                          if (_c.picking)
                            _PickBar(controller: _c)
                          else if (_c.selection.isNotEmpty)
                            _SelectionBar(controller: _c),
                          _Dock(controller: _c),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
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
  const _InkRow({
    required this.inks,
    required this.controller,
    this.vertical = false,
  });

  final List<(Color, String)> inks;
  final CanvasController controller;

  /// A column under the size rail (studio layout) or a row.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final inking = c.tool != CanvasTool.eraser && c.tool != CanvasTool.lasso;
    return Container(
      padding: vertical
          ? const EdgeInsets.symmetric(vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: TintaColors.dock,
        borderRadius: BorderRadius.circular(TintaRadii.pill),
      ),
      child: Flex(
        direction: vertical ? Axis.vertical : Axis.horizontal,
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

/// "250%" when zoomed in or out; tap to fit the page again.
class _ZoomChip extends StatelessWidget {
  const _ZoomChip({required this.viewport});

  final PageViewport viewport;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewport,
      builder: (context, _) {
        // Only present while zoomed, so screen readers don't hear a hidden button.
        if (viewport.isFitted) return const SizedBox.shrink();
        return Semantics(
          button: true,
          label: 'Zoom ${(viewport.zoom * 100).round()} percent. Fit page',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: viewport.reset,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: TintaColors.dock,
                borderRadius: BorderRadius.circular(TintaRadii.pill),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  '${(viewport.zoom * 100).round()}% · Fit',
                  style: TintaType.mono(12, color: TintaColors.newsprint),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Slides [child] off by [offset] (in its own sizes) and ignores touches
/// while [hidden].
class _SlideAway extends StatelessWidget {
  const _SlideAway({
    required this.hidden,
    required this.offset,
    required this.child,
  });

  final bool hidden;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: hidden,
      child: AnimatedSlide(
        offset: hidden ? offset : Offset.zero,
        duration: Duration(milliseconds: hidden ? 160 : 240),
        curve: hidden ? Curves.easeIn : Curves.easeOutCubic,
        child: ExcludeSemantics(excluding: hidden, child: child),
      ),
    );
  }
}
