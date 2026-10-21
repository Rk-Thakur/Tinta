import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../app/routes.dart';
import '../data/library_store.dart';
import '../data/models.dart';
import '../drawing/replay.dart';
import '../drawing/stroke_renderer.dart';
import '../export/exporter.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/widgets/paper.dart';
import '../ui/widgets/widgets.dart';
import 'export_sheet.dart';

class ReplayArgs {
  const ReplayArgs({required this.pages, required this.title});

  /// Played in order.
  final List<SketchPage> pages;
  final String title;
}

/// Stroke-by-stroke replay with a scrubber, speeds and "branch from here".
class ReplayScreen extends StatefulWidget {
  const ReplayScreen({super.key, required this.args});

  final ReplayArgs args;

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen>
    with SingleTickerProviderStateMixin {
  late final ReplayTimeline _timeline = ReplayTimeline(widget.args.pages);
  late final Ticker _ticker = createTicker(_tick);
  late final List<double> _bars = _timeline.histogram(40);
  double _ms = 0;
  double _speed = 4;
  Duration? _last;

  int get _total => _timeline.duration.inMilliseconds;
  bool get _playing => _ticker.isActive;

  @override
  void initState() {
    super.initState();
    if (!_timeline.isEmpty) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = _last == null ? 0 : (elapsed - _last!).inMicroseconds / 1000;
    _last = elapsed;
    setState(() => _ms = (_ms + dt * _speed).clamp(0, _total.toDouble()));
    if (_ms >= _total) _pause();
  }

  void _pause() {
    _ticker.stop();
    _last = null;
    setState(() {});
  }

  void _play() {
    if (_ms >= _total) _ms = 0;
    _last = null;
    _ticker.start();
    setState(() {});
  }

  void _seek(double fraction) =>
      setState(() => _ms = (fraction.clamp(0.0, 1.0) * _total));

  void _branch(ReplayFrame frame) {
    final store = LibraryScope.of(context);
    final source = widget.args.pages[frame.pageIndex];
    final book = store.bookOf(source.id);
    final page = store.addPage(
      SketchPage(
        id: '',
        number: 0,
        title: '${source.title ?? 'Untitled'} · branch',
        paper: source.paper,
        aspect: source.aspect,
        riso: source.riso,
        risoInks: source.risoInks,
        layers: frame.layers,
      ),
      bookId: book?.id,
    );
    Navigator.of(context).pushReplacementNamed(
      Routes.canvas,
      arguments: CanvasArgs.page(page, bookId: book?.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empty = _timeline.isEmpty;
    final frame = _timeline.frameAt(_ms.round());
    final page = widget.args.pages[frame.pageIndex];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: TintaColors.studioInk,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                Row(
                  spacing: 10,
                  children: [
                    TileIconButton(
                      icon: TintaIcons.back,
                      label: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text(
                        'Replay',
                        style: TintaType.display(
                          26,
                          color: TintaColors.newsprint,
                        ),
                      ),
                    ),
                    if (!empty)
                      Text(
                        '${_timeline.strokeCount} strokes · ${formatClock(_timeline.duration)}',
                        style: TintaType.mono(
                          12,
                          color: TintaColors.studioSubtle,
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: empty
                      ? _EmptyReplay(title: widget.args.title)
                      : Center(
                          child: AspectRatio(
                            aspectRatio: 1 / page.aspect,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Semantics(
                                    image: true,
                                    label:
                                        '${widget.args.title} replaying, '
                                        '${_total == 0 ? 0 : (_ms / _total * 100).round()} percent',
                                    child: CustomPaint(
                                      painter: _FramePainter(page, frame),
                                    ),
                                  ),
                                  Positioned(
                                    left: 12,
                                    bottom: 12,
                                    child: Container(
                                      height: 28,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: TintaColors.studioInk,
                                        borderRadius: BorderRadius.circular(
                                          TintaRadii.pill,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'stroke ${frame.strokesDone} / ${_timeline.strokeCount}'
                                        '${widget.args.pages.length > 1 ? ' · p.${page.number}' : ''}',
                                        style: TintaType.mono(
                                          11,
                                          color: TintaColors.newsprint,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
                if (!empty) ...[
                  _Scrubber(
                    bars: _bars,
                    progress: _total == 0 ? 0 : _ms / _total,
                    onSeek: _seek,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatClock(Duration(milliseconds: _ms.round())),
                        style: TintaType.mono(
                          11,
                          color: TintaColors.studioSubtle,
                        ),
                      ),
                      Text(
                        formatClock(_timeline.duration),
                        style: TintaType.mono(
                          11,
                          color: TintaColors.studioSubtle,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SegmentedPills<double>(
                        options: const [1, 4, 16],
                        value: _speed,
                        tone: ControlTone.studio,
                        labelOf: (v) => '${v.round()}×',
                        onChanged: (v) => setState(() => _speed = v),
                      ),
                      TileIconButton(
                        icon: _playing ? TintaIcons.pause : TintaIcons.play,
                        label: _playing ? 'Pause' : 'Play',
                        size: 64,
                        radius: 24,
                        iconSize: 26,
                        background: TintaColors.sun,
                        foreground: TintaColors.studioInk,
                        onPressed: _playing ? _pause : _play,
                      ),
                    ],
                  ),
                  Row(
                    spacing: 10,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: frame.strokesDone == 0
                                ? null
                                : () => _branch(frame),
                            icon: const TintaIcon(
                              TintaIcons.branch,
                              size: 18,
                              strokeWidth: 2.2,
                              color: TintaColors.newsprint,
                            ),
                            label: const Text('Branch from here'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: TintaColors.newsprint,
                              side: const BorderSide(
                                color: TintaColors.newsprint,
                                width: 1.5,
                              ),
                              shape: const StadiumBorder(),
                              textStyle: TintaType.body(
                                15,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: PillButton(
                            label: 'Save as video',
                            variant: PillVariant.light,
                            expand: true,
                            onPressed: () {
                              _pause();
                              Navigator.of(context).pushNamed(
                                Routes.export,
                                arguments: ExportArgs(
                                  page: page,
                                  replayPages: widget.args.pages,
                                  format: ExportFormat.mp4,
                                  speed: _speed,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.page, this.frame);

  final SketchPage page;
  final ReplayFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / page.size.width);
    paintPaper(canvas, page.size, page.paper);
    StrokeRenderer.paintLayers(
      canvas,
      page.size,
      frame.layers,
      live: frame.live,
      liveLayer: frame.liveLayer,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => true;
}

class _Scrubber extends StatelessWidget {
  const _Scrubber({
    required this.bars,
    required this.progress,
    required this.onSeek,
  });

  final List<double> bars;
  final double progress;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void seek(Offset p) => onSeek(p.dx / constraints.maxWidth);
        final next = (progress + 0.05).clamp(0.0, 1.0);
        final previous = (progress - 0.05).clamp(0.0, 1.0);
        return Semantics(
          slider: true,
          label: 'Replay position',
          value: '${(progress * 100).round()}%',
          increasedValue: '${(next * 100).round()}%',
          decreasedValue: '${(previous * 100).round()}%',
          onIncrease: () => onSeek(next),
          onDecrease: () => onSeek(previous),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => seek(d.localPosition),
            onHorizontalDragUpdate: (d) => seek(d.localPosition),
            child: SizedBox(
              height: 44,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 3,
                children: [
                  for (var i = 0; i < bars.length; i++)
                    Expanded(
                      child: Container(
                        height: 6 + bars[i] * 34,
                        decoration: BoxDecoration(
                          color: (i + 0.5) / bars.length <= progress
                              ? TintaColors.sun
                              : TintaColors.dockRaised,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyReplay extends StatelessWidget {
  const _EmptyReplay({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          const TintaIcon(
            TintaIcons.clock,
            size: 40,
            color: TintaColors.studioMuted,
          ),
          Text(
            'Nothing to replay yet',
            style: TintaType.display(
              22,
              weight: FontWeight.w600,
              color: TintaColors.newsprint,
            ),
          ),
          Text(
            'Tinta records every stroke as you draw. Once “$title” has some, you can play it back here.',
            textAlign: TextAlign.center,
            style: TintaType.body(14, color: TintaColors.studioMuted),
          ),
        ],
      ),
    );
  }
}

/// Every page that has strokes, newest first. Opened from the main nav.
class ReplaysScreen extends StatelessWidget {
  const ReplaysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = LibraryScope.of(context);
    final pages = [
      for (final p in store.allPages)
        if (hasReplay([p])) p,
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              spacing: 10,
              children: [
                TileIconButton(
                  icon: TintaIcons.back,
                  label: 'Back to library',
                  background: TintaColors.surface,
                  foreground: TintaColors.studioInk,
                  borderColor: TintaColors.line,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Text('Replays', style: TintaType.display28),
              ],
            ),
            const SizedBox(height: 16),
            if (pages.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  'Draw on any page and its replay appears here.',
                  textAlign: TextAlign.center,
                  style: TintaType.body15.copyWith(color: TintaColors.ink2),
                ),
              ),
            for (final p in pages)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReplayRow(page: p, book: store.bookOf(p.id)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReplayRow extends StatelessWidget {
  const _ReplayRow({required this.page, required this.book});

  final SketchPage page;
  final Sketchbook? book;

  @override
  Widget build(BuildContext context) {
    final timeline = ReplayTimeline([page]);
    return Material(
      color: TintaColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TintaRadii.md),
        side: const BorderSide(color: TintaColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context).pushNamed(Routes.replay, arguments: page),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            spacing: 12,
            children: [
              SizedBox(width: 56, height: 72, child: PageThumb(page: page)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      page.title ?? 'Untitled',
                      style: TintaType.body(
                        15,
                        weight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    Text(
                      book == null
                          ? 'Loose page'
                          : '${book!.title} · p.${page.number}',
                      style: TintaType.body13,
                    ),
                    Text(
                      '${timeline.strokeCount} strokes · ${formatClock(timeline.duration)}',
                      style: TintaType.mono(11, color: TintaColors.ink2),
                    ),
                  ],
                ),
              ),
              const TintaIcon(
                TintaIcons.play,
                size: 20,
                color: TintaColors.studioInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
