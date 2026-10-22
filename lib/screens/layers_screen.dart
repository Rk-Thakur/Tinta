import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../drawing/canvas_controller.dart';
import '../drawing/stroke.dart';
import '../drawing/stroke_renderer.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/widgets/paper.dart';
import '../ui/widgets/dialogs.dart';
import '../ui/widgets/widgets.dart';

class LayersArgs {
  const LayersArgs({required this.controller, required this.paper});
  final CanvasController controller;
  final PaperType paper;
}

/// Layer stack for the open page. Shown top layer first; paper sits at the
/// bottom, locked. Every change is a single undo step on the canvas.
class LayersScreen extends StatelessWidget {
  const LayersScreen({super.key, required this.args});

  final LayersArgs args;

  @override
  Widget build(BuildContext context) {
    final c = args.controller;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: TintaColors.studioInk,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              final layers = c.layers;
              final n = layers.length;
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      spacing: 10,
                      children: [
                        TileIconButton(
                          icon: TintaIcons.back,
                          label: 'Back to canvas',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        Expanded(
                          child: Text(
                            'Layers',
                            style: TintaType.display(
                              28,
                              color: TintaColors.newsprint,
                            ),
                          ),
                        ),
                        TileIconButton(
                          icon: TintaIcons.plus,
                          label: 'Add layer',
                          strokeWidth: 2.6,
                          background: TintaColors.fluoroOrange,
                          foreground: TintaColors.studioInk,
                          onPressed: c.addLayer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Hold and drag to reorder. Swipe left to merge down.',
                      style: TintaType.body(14, color: TintaColors.studioMuted),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: n,
                        proxyDecorator: (child, _, _) =>
                            Material(color: Colors.transparent, child: child),
                        // Display is top-first; the stack is bottom-first.
                        onReorderItem: (from, to) =>
                            c.moveLayer(n - 1 - from, n - 1 - to),
                        footer: _PaperRow(paper: args.paper),
                        itemBuilder: (context, i) {
                          final index = n - 1 - i;
                          final layer = layers[index];
                          return Padding(
                            key: ValueKey(layer.id),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _LayerRow(
                              index: index,
                              displayIndex: i,
                              layer: layer,
                              paper: args.paper,
                              pageSize: c.pageSize,
                              active: index == c.activeLayer,
                              onTap: () => c.activeLayer = index,
                              onToggle: () => c.updateLayer(
                                index,
                                layer.copyWith(visible: !layer.visible),
                              ),
                              onMergeDown: index > 0
                                  ? () => c.mergeDown(index)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LayerPanel(controller: c),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.index,
    required this.displayIndex,
    required this.layer,
    required this.paper,
    required this.pageSize,
    required this.active,
    required this.onTap,
    required this.onToggle,
    required this.onMergeDown,
  });

  final int index;
  final int displayIndex;
  final PageLayer layer;
  final PaperType paper;
  final Size pageSize;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback? onMergeDown;

  @override
  Widget build(BuildContext context) {
    final row = Material(
      color: active ? TintaColors.risoBlue : TintaColors.dock,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            spacing: 12,
            children: [
              Opacity(
                opacity: layer.visible ? 1 : 0.45,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 60,
                    height: 76,
                    child: CustomPaint(
                      painter: _LayerThumb(layer, paper, pageSize),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: active,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        layer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TintaType.body(
                          16,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        '${layer.blend.label} · ${(layer.opacity * 100).round()}%${layer.visible ? '' : ' · hidden'}',
                        style: TintaType.mono(
                          11,
                          color: active
                              ? Colors.white
                              : TintaColors.studioSubtle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TileIconButton(
                icon: layer.visible ? TintaIcons.eye : TintaIcons.eyeOff,
                label: '${layer.visible ? 'Hide' : 'Show'} ${layer.name}',
                strokeWidth: 2,
                background: active
                    ? const Color(0x40000000)
                    : TintaColors.dockRaised,
                foreground: active ? Colors.white : TintaColors.newsprint,
                onPressed: onToggle,
              ),
              ReorderableDragStartListener(
                index: displayIndex,
                child: Semantics(
                  label: 'Reorder ${layer.name}',
                  child: const SizedBox(
                    width: 28,
                    height: 44,
                    child: Center(
                      child: TintaIcon(
                        TintaIcons.dragHandle,
                        size: 18,
                        color: TintaColors.studioMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onMergeDown == null) return row;
    return Dismissible(
      key: ValueKey('merge-${layer.id}'),
      direction: DismissDirection.endToStart,
      // Merge happens here; the row itself never dismisses (the stack rebuilds).
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        onMergeDown!();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: TintaColors.sun,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Merge down',
          style: TintaType.body(
            14,
            weight: FontWeight.w700,
            color: TintaColors.studioInk,
          ),
        ),
      ),
      child: row,
    );
  }
}

class _LayerThumb extends CustomPainter {
  _LayerThumb(this.layer, this.paper, this.pageSize);

  final PageLayer layer;
  final PaperType paper;
  final Size pageSize;

  @override
  void paint(Canvas canvas, Size size) {
    paintPaper(canvas, size, paper);
    final fitted = applyBoxFit(BoxFit.contain, pageSize, size).destination;
    final dst = Alignment.center.inscribe(fitted, Offset.zero & size);
    canvas.translate(dst.left, dst.top);
    canvas.scale(dst.width / pageSize.width);
    StrokeRenderer.paintLayers(canvas, pageSize, [
      layer.copyWith(visible: true, opacity: 1),
    ]);
  }

  @override
  bool shouldRepaint(_LayerThumb old) =>
      old.layer != layer || old.paper != paper;
}

class _PaperRow extends StatelessWidget {
  const _PaperRow({required this.paper});

  final PaperType paper;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.75,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: TintaColors.dock,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          spacing: 12,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 60,
                height: 76,
                child: PaperSurface(paper: paper),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    'Paper · ${paper.label}',
                    style: TintaType.body(
                      16,
                      weight: FontWeight.w700,
                      color: TintaColors.newsprint,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'Locked',
                    style: TintaType.mono(11, color: TintaColors.studioSubtle),
                  ),
                ],
              ),
            ),
            const SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: TintaIcon(
                  TintaIcons.lock,
                  size: 20,
                  color: TintaColors.studioSubtle,
                  semanticLabel: 'Locked',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerPanel extends StatelessWidget {
  const _LayerPanel({required this.controller});

  final CanvasController controller;

  Future<void> _rename(BuildContext context, int i, PageLayer layer) async {
    final name = await promptText(
      context,
      title: 'Rename layer',
      initial: layer.name,
      hint: 'Layer name',
    );
    if (name != null && name != layer.name) {
      controller.updateLayer(i, layer.copyWith(name: name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final i = c.activeLayer;
    final layer = c.layers[i];

    Widget action(
      String label,
      VoidCallback? onPressed, {
      Color color = TintaColors.newsprint,
    }) => Expanded(
      child: SizedBox(
        height: 44,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: TintaColors.dockRaised,
            foregroundColor: color,
            disabledForegroundColor: TintaColors.studioDisabled,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TintaRadii.sm),
            ),
            textStyle: TintaType.body(14),
          ),
          child: Text(label),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TintaColors.dock,
        borderRadius: BorderRadius.circular(TintaRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  layer.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TintaType.label(color: TintaColors.studioSubtle),
                ),
              ),
              TextButton(
                onPressed: () => _rename(context, i, layer),
                style: TextButton.styleFrom(
                  foregroundColor: TintaColors.sun,
                  minimumSize: const Size(44, 32),
                ),
                child: const Text('Rename'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in LayerBlend.values)
                TintaChip(
                  label: b.label,
                  tone: ChipTone.studio,
                  height: 34,
                  selected: layer.blend == b,
                  onTap: () => c.updateLayer(i, layer.copyWith(blend: b)),
                ),
            ],
          ),
          Row(
            spacing: 12,
            children: [
              Text(
                'Opacity',
                style: TintaType.body(14, color: TintaColors.newsprint),
              ),
              Expanded(
                child: Listener(
                  onPointerUp: (_) => c.commitPending(),
                  onPointerCancel: (_) => c.commitPending(),
                  child: TintaSlider(
                    value: layer.opacity,
                    min: 0.05,
                    tone: ControlTone.studio,
                    label: 'Layer opacity',
                    onChanged: (v) =>
                        c.previewLayer(i, layer.copyWith(opacity: v)),
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${(layer.opacity * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: TintaType.mono(12, color: TintaColors.newsprint),
                ),
              ),
            ],
          ),
          Row(
            spacing: 8,
            children: [
              action('Duplicate', () => c.duplicateLayer(i)),
              action('Merge down', i > 0 ? () => c.mergeDown(i) : null),
              action(
                'Delete',
                c.layers.length > 1 ? () => c.deleteLayer(i) : null,
                color: const Color(0xFFFF8A5E),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
