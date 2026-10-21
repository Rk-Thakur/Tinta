import 'dart:math' as math;

import '../data/models.dart';
import 'stroke.dart';

/// One stroke placed on the replay clock.
class ReplayStroke {
  ReplayStroke({
    required this.pageIndex,
    required this.layerIndex,
    required this.stroke,
    required this.start,
    required this.end,
  });

  final int pageIndex;
  final int layerIndex;
  final Stroke stroke;

  /// Replay-clock milliseconds.
  final int start;
  final int end;

  int get firstT => stroke.points.first.t;
}

/// What the page looks like at a point on the replay clock.
class ReplayFrame {
  const ReplayFrame({
    required this.pageIndex,
    required this.layers,
    required this.strokesDone,
    this.live,
    this.liveLayer = -1,
  });

  final int pageIndex;
  final List<PageLayer> layers;
  final int strokesDone;
  final Stroke? live;
  final int liveLayer;
}

/// Replays pages from the timestamps recorded with every point. Pauses longer
/// than [maxGapMs] are shortened so a replay shows drawing, not waiting.
class ReplayTimeline {
  ReplayTimeline(this.pages, {this.maxGapMs = 400}) {
    var clock = 0;
    for (var p = 0; p < pages.length; p++) {
      final page = pages[p];
      final entries = <(int, Stroke)>[
        for (var l = 0; l < page.layers.length; l++)
          for (final s in page.layers[l].strokes)
            if (s.points.isNotEmpty) (l, s),
      ]..sort((a, b) => a.$2.points.first.t.compareTo(b.$2.points.first.t));

      int? lastEnd;
      for (final (layer, s) in entries) {
        final t0 = s.points.first.t;
        final gap = lastEnd == null
            ? 0
            : math.min(maxGapMs, math.max(0, t0 - lastEnd));
        final start = clock + gap;
        // Every stroke gets at least a couple of frames on screen.
        final length = math.max(40, s.points.last.t - t0);
        strokes.add(
          ReplayStroke(
            pageIndex: p,
            layerIndex: layer,
            stroke: s,
            start: start,
            end: start + length,
          ),
        );
        clock = start + length;
        lastEnd = s.points.last.t;
      }
      if (entries.isNotEmpty && p < pages.length - 1) {
        clock += 600; // beat between pages
      }
      _pageEnds.add(clock);
    }
    duration = Duration(milliseconds: clock);
  }

  final List<SketchPage> pages;
  final int maxGapMs;
  final List<ReplayStroke> strokes = [];
  final List<int> _pageEnds = [];
  late final Duration duration;

  bool get isEmpty => strokes.isEmpty;
  int get strokeCount => strokes.length;

  int pageAt(int ms) {
    for (var i = 0; i < _pageEnds.length; i++) {
      if (ms <= _pageEnds[i]) return i;
    }
    return math.max(0, pages.length - 1);
  }

  /// The page at [ms] with every finished stroke and the one in progress.
  ReplayFrame frameAt(int ms) {
    final pageIndex = isEmpty ? 0 : pageAt(ms);
    final page = pages[pageIndex];
    final byLayer = [for (final _ in page.layers) <Stroke>[]];
    Stroke? live;
    var liveLayer = -1;
    var done = 0;
    for (final r in strokes) {
      if (r.pageIndex < pageIndex) {
        done++;
        continue;
      }
      if (r.pageIndex > pageIndex || r.start > ms) break;
      if (r.end <= ms) {
        byLayer[r.layerIndex].add(r.stroke);
        done++;
      } else {
        // Partially drawn: points recorded up to the matching moment.
        final cutoff = r.firstT + (ms - r.start);
        final pts = [
          for (final p in r.stroke.points)
            if (p.t <= cutoff) p,
        ];
        if (pts.isNotEmpty) {
          live = Stroke(
            id: r.stroke.id,
            brush: r.stroke.brush,
            color: r.stroke.color,
            size: r.stroke.size,
            opacity: r.stroke.opacity,
            multiply: r.stroke.multiply,
            presetId: r.stroke.presetId,
            grain: r.stroke.grain,
            smoothing: r.stroke.smoothing,
            points: pts,
          );
          liveLayer = r.layerIndex;
        }
      }
    }
    return ReplayFrame(
      pageIndex: pageIndex,
      layers: [
        for (var i = 0; i < page.layers.length; i++)
          page.layers[i].copyWith(strokes: byLayer[i]),
      ],
      strokesDone: done,
      live: live,
      liveLayer: liveLayer,
    );
  }

  /// Activity per time bucket (0..1), for the scrubber bars.
  List<double> histogram(int buckets) {
    if (isEmpty || duration.inMilliseconds == 0) return List.filled(buckets, 0);
    final counts = List<double>.filled(buckets, 0);
    final total = duration.inMilliseconds;
    for (final r in strokes) {
      for (final p in r.stroke.points) {
        final ms = r.start + (p.t - r.firstT);
        counts[math.min(buckets - 1, ms * buckets ~/ total)] += 1;
      }
    }
    final peak = counts.reduce(math.max);
    return [for (final c in counts) peak == 0 ? 0 : c / peak];
  }
}

String formatClock(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
