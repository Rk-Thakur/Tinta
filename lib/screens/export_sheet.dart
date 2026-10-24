import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../data/library_store.dart';
import '../data/models.dart';
import '../export/exporter.dart';
import '../export/render.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/widgets/paper.dart';
import '../ui/widgets/widgets.dart';

class ExportArgs {
  const ExportArgs({
    required this.page,
    this.replayPages,
    this.format = ExportFormat.png,
    this.speed = 4,
  });

  final SketchPage page;

  /// Pages for the MP4 replay (a whole sketchbook); defaults to [page].
  final List<SketchPage>? replayPages;
  final ExportFormat format;
  final double speed;
}

/// Export bottom sheet: format, resolution, then share or save. All offline.
class ExportSheet extends StatefulWidget {
  const ExportSheet({super.key, required this.args});

  final ExportArgs args;

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  late ExportFormat _format = widget.args.format;
  double _scale = 2;
  bool _transparent = false;
  double? _progress;
  String? _error;
  String? _done;
  Exporter? _exporter;

  SketchPage get _page => widget.args.page;
  List<SketchPage> get _replayPages => widget.args.replayPages ?? [_page];

  bool _available(ExportFormat f) => switch (f) {
    ExportFormat.mp4 => hasReplay(_replayPages),
    ExportFormat.riso => pageInks(_page).isNotEmpty,
    _ => true,
  };

  bool get _transparentApplies =>
      _format == ExportFormat.png || _format == ExportFormat.psd;

  String get _dimensions {
    if (_format == ExportFormat.mp4) {
      final w = 720 * _scale.clamp(1, 2);
      return '${w.round()} × ${(w * _page.aspect / 16).round() * 16} video';
    }
    final s = exportSize(_page, _scale);
    return '${s.width.round()} × ${s.height.round()}';
  }

  Future<File> _make() async {
    final vault = LibraryScope.of(context).vault;
    final dir = vault?.exportsDir ?? Directory.systemTemp;
    final exporter = _exporter = Exporter(dir);
    return switch (_format) {
      ExportFormat.png => exporter.png(
        _page,
        scale: _scale,
        transparent: _transparent,
      ),
      ExportFormat.pdf => exporter.pdf(_page, scale: _scale),
      ExportFormat.psd => exporter.psd(
        _page,
        scale: _scale,
        transparent: _transparent,
      ),
      ExportFormat.riso => exporter.riso(_page, scale: _scale),
      ExportFormat.mp4 => exporter.mp4(
        _replayPages,
        titlePage: _page,
        scale: _scale,
        speed: widget.args.speed,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      ),
    };
  }

  Future<void> _run(Future<void> Function(File file) deliver) async {
    // MP4 reports real progress; other formats show an indeterminate bar (-1).
    setState(() {
      _progress = _format == ExportFormat.mp4 ? 0 : -1;
      _error = null;
      _done = null;
    });
    try {
      final file = await _make();
      if (!mounted) return;
      await deliver(file);
    } on ExportCancelled {
      if (mounted) setState(() => _done = 'Export cancelled.');
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError ? e.message : 'Export failed: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _progress = null);
        LibraryScope.of(context).refreshFreeSpace();
      }
    }
  }

  Future<void> _share(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    await _run((file) async {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], sharePositionOrigin: origin),
      );
    });
  }

  Future<void> _save(BuildContext buttonContext) async {
    if (!_format.photosCompatible) return _share(buttonContext);
    await _run((file) async {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        setState(
          () => _error = 'Tinta needs permission to add to Photos. You can allow it in Settings.',
        );
        return;
      }
      if (_format == ExportFormat.mp4) {
        await Gal.putVideo(file.path);
      } else {
        await Gal.putImage(file.path);
      }
      setState(() => _done = 'Saved to Photos.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final working = _progress != null;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: TintaColors.studioMuted,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              spacing: 14,
              children: [
                SizedBox(width: 72, height: 92, child: PageThumb(page: _page)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Export', style: TintaType.display(26)),
                      Text(
                        '${_page.title ?? 'Untitled'} · $_dimensions',
                        maxLines: 2,
                        style: TintaType.body(
                          14,
                          color: TintaColors.ink2,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                TileIconButton(
                  icon: TintaIcons.close,
                  label: 'Close',
                  radius: 22,
                  iconSize: 18,
                  strokeWidth: 2.4,
                  background: TintaColors.segmentTrack,
                  foreground: TintaColors.studioInk,
                  onPressed: working ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'FORMAT',
              style: TintaType.mono(
                11,
                color: TintaColors.ink2,
              ).copyWith(letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            // Design grid: PNG · PDF · PSD, then MP4 beside a double-width riso tile.
            Row(
              spacing: 10,
              children: [
                for (final f in [
                  ExportFormat.png,
                  ExportFormat.pdf,
                  ExportFormat.psd,
                ])
                  Expanded(
                    child: SizedBox(
                      height: 76,
                      child: _FormatTile(
                        format: f,
                        selected: _format == f,
                        enabled: _available(f) && !working,
                        onTap: () => setState(() => _format = f),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 76,
                    child: _FormatTile(
                      format: ExportFormat.mp4,
                      selected: _format == ExportFormat.mp4,
                      enabled: _available(ExportFormat.mp4) && !working,
                      onTap: () => setState(() => _format = ExportFormat.mp4),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _RisoTile(
                    selected: _format == ExportFormat.riso,
                    enabled: _available(ExportFormat.riso) && !working,
                    inks: pageInks(_page),
                    onTap: () => setState(() => _format = ExportFormat.riso),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: TintaColors.surface,
                border: Border.all(color: TintaColors.line),
                borderRadius: BorderRadius.circular(TintaRadii.md),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Resolution', style: TintaType.body(15)),
                        ),
                        SegmentedPills<double>(
                          options: _format == ExportFormat.mp4
                              ? const [1, 1.5, 2]
                              : const [1, 2, 4],
                          value: _format == ExportFormat.mp4
                              ? _scale.clamp(1, 2)
                              : _scale,
                          dense: true,
                          labelOf: (v) =>
                              '${v == v.roundToDouble() ? v.round() : v}×',
                          onChanged: (v) => setState(() => _scale = v),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: TintaColors.hairline),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Opacity(
                      opacity: _transparentApplies ? 1 : 0.4,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Transparent paper',
                              style: TintaType.body(15),
                            ),
                          ),
                          TintaSwitch(
                            value: _transparent && _transparentApplies,
                            onChanged: (v) {
                              if (_transparentApplies) {
                                setState(() => _transparent = v);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (working) ...[
              _Progress(
                value: _progress! < 0 ? null : _progress,
                onCancel: _format == ExportFormat.mp4
                    ? () => _exporter?.cancel()
                    : null,
              ),
              const SizedBox(height: 12),
            ] else
              Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: Builder(
                      builder: (b) => PillButton(
                        label: 'Share',
                        variant: PillVariant.outline,
                        expand: true,
                        onPressed: () => _share(b),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (b) => PillButton(
                        label: _format.photosCompatible
                            ? 'Save to Photos'
                            : 'Save to Files',
                        expand: true,
                        onPressed: () => _save(b),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Text(
              _error ?? _done ?? 'Both work without an internet connection.',
              textAlign: TextAlign.center,
              style: TintaType.body(
                12,
                color: _error != null
                    ? const Color(0xFFB3261E)
                    : TintaColors.ink2,
                weight: _error != null || _done != null
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.format,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ExportFormat format;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '${format.label}, ${format.subtitle}',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || selected ? 1 : 0.4,
        child: Material(
          color: TintaColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TintaRadii.md),
            side: BorderSide(
              color: selected ? TintaColors.risoBlue : TintaColors.line,
              width: selected ? 3 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 2,
              children: [
                Text(
                  format.label,
                  style: TintaType.mono(15, weight: FontWeight.w600),
                ),
                Text(
                  format.subtitle,
                  style: TintaType.body(
                    12,
                    color: TintaColors.ink2,
                    height: 1.2,
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

class _RisoTile extends StatelessWidget {
  const _RisoTile({
    required this.selected,
    required this.enabled,
    required this.inks,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final List<Color> inks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shown = inks.isEmpty
        ? [TintaInk.risoBlue, TintaInk.fluoroOrange]
        : inks.take(4).toList();
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: 'Riso separations, one sheet per ink',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || selected ? 1 : 0.4,
        child: Material(
          color: TintaColors.sun,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TintaRadii.md),
            side: selected
                ? BorderSide(color: TintaColors.risoBlue, width: 3)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            // Ink on sun in every theme.
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: TintaInk.studioInk),
              child: SizedBox(
                height: 76,
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 22 + 14.0 * (shown.length - 1),
                      height: 22,
                      child: Stack(
                        children: [
                          for (var i = 0; i < shown.length; i++)
                            Positioned(
                              left: 14.0 * i,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: shown[i],
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Riso separations',
                            style: TintaType.body(
                              14,
                              weight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          Text(
                            inks.isEmpty
                                ? 'Draw something first'
                                : '${inks.length} ${inks.length == 1 ? 'sheet' : 'sheets'}, one per ink',
                            style: TintaType.body(12, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value, this.onCancel});

  final double? value;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text(
                value == null
                    ? 'Preparing file…'
                    : 'Rendering video… ${(value! * 100).round()}%',
                style: TintaType.body(14, weight: FontWeight.w500),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: value == null ? null : math.max(0.02, value!),
                  minHeight: 6,
                  color: TintaColors.studioInk,
                  backgroundColor: TintaColors.line,
                ),
              ),
            ],
          ),
        ),
        if (onCancel != null)
          PillButton(
            label: 'Cancel',
            variant: PillVariant.outline,
            compact: true,
            onPressed: onCancel,
          ),
      ],
    );
  }
}
