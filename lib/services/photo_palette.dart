import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

/// Picks a photo and extracts its main colors, entirely on device.
abstract final class PhotoPalette {
  /// Returns null when the user cancels the picker.
  static Future<List<ui.Color>?> pick({int count = 5}) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 160,
      maxHeight: 160,
    );
    if (file == null) return null;
    final codec = await ui.instantiateImageCodec(
      await file.readAsBytes(),
      targetWidth: 96,
    );
    final image = (await codec.getNextFrame()).image;
    final data = (await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!.buffer.asUint8List();
    image.dispose();
    return extract(data, count: count);
  }

  /// k-means over RGB pixels; most common colors first, near-duplicates merged.
  static List<ui.Color> extract(
    Uint8List rgba, {
    int count = 5,
    int iterations = 12,
  }) {
    final pixels = <List<double>>[];
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      if (rgba[i + 3] < 128) continue; // skip transparent
      pixels.add([
        rgba[i].toDouble(),
        rgba[i + 1].toDouble(),
        rgba[i + 2].toDouble(),
      ]);
    }
    if (pixels.isEmpty) return const [];

    // Deterministic spread-out seeds (k-means++ style, fixed RNG).
    final rng = math.Random(42);
    final centers = <List<double>>[pixels[rng.nextInt(pixels.length)]];
    while (centers.length < count && centers.length < pixels.length) {
      var best = pixels.first;
      var bestD = -1.0;
      for (var s = 0; s < 64; s++) {
        final p = pixels[rng.nextInt(pixels.length)];
        final d = centers.map((c) => _dist(p, c)).reduce(math.min);
        if (d > bestD) {
          bestD = d;
          best = p;
        }
      }
      centers.add(List.of(best));
    }

    var sizes = List<int>.filled(centers.length, 0);
    for (var it = 0; it < iterations; it++) {
      final sums = [
        for (final _ in centers) [0.0, 0.0, 0.0],
      ];
      sizes = List<int>.filled(centers.length, 0);
      for (final p in pixels) {
        var k = 0;
        var kd = double.infinity;
        for (var c = 0; c < centers.length; c++) {
          final d = _dist(p, centers[c]);
          if (d < kd) {
            kd = d;
            k = c;
          }
        }
        sums[k][0] += p[0];
        sums[k][1] += p[1];
        sums[k][2] += p[2];
        sizes[k]++;
      }
      for (var c = 0; c < centers.length; c++) {
        if (sizes[c] == 0) continue;
        centers[c] = [
          sums[c][0] / sizes[c],
          sums[c][1] / sizes[c],
          sums[c][2] / sizes[c],
        ];
      }
    }

    final order = List.generate(centers.length, (i) => i)
      ..sort((a, b) => sizes[b].compareTo(sizes[a]));
    final out = <List<double>>[];
    for (final i in order) {
      if (sizes[i] == 0) continue;
      if (out.any((c) => _dist(c, centers[i]) < 24 * 24)) continue;
      out.add(centers[i]);
    }
    return [
      for (final c in out)
        ui.Color.fromARGB(255, c[0].round(), c[1].round(), c[2].round()),
    ];
  }

  static double _dist(List<double> a, List<double> b) {
    final dr = a[0] - b[0], dg = a[1] - b[1], db = a[2] - b[2];
    return dr * dr + dg * dg + db * db;
  }
}
