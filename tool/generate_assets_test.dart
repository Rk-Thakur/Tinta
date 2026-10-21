// Renders the app icon and launch logo from the design's logo tile.
//
// Run from the project root (not part of the normal test suite):
//   flutter test tool/generate_assets_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _ink = Color(0xFF17171C);
const _orange = Color(0xFFFF5A1F);

/// The squiggle from the design's logo, on a 24-unit grid.
Path _squiggle(double unit) => Path()
  ..moveTo(4 * unit, 17 * unit)
  ..relativeCubicTo(3 * unit, -8 * unit, 6 * unit, -10 * unit, 8 * unit, -6 * unit)
  ..relativeCubicTo(2 * unit, 4 * unit, 4 * unit, 3 * unit, 8 * unit, -5 * unit);

/// Logo tile at [size] px. [radius] 0 gives a full-bleed square (iOS masks
/// its own corners); [squiggleScale] is the squiggle's share of the tile.
Future<List<int>> renderTile(int size, {double radius = 0, double squiggleScale = 0.56}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size.toDouble();
  final bg = Paint()..color = _ink;
  if (radius == 0) {
    canvas.drawRect(Offset.zero & Size(s, s), bg);
  } else {
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & Size(s, s), Radius.circular(radius)), bg);
  }
  final glyph = s * squiggleScale;
  final unit = glyph / 24;
  canvas.translate((s - glyph) / 2, (s - glyph) / 2);
  canvas.drawPath(
    _squiggle(unit),
    Paint()
      ..color = _orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * unit
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true,
  );
  final image = await recorder.endRecording().toImage(size, size);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

Future<void> _write(String path, List<int> bytes) async {
  final f = File(path);
  await f.parent.create(recursive: true);
  await f.writeAsBytes(bytes);
}

void main() {
  test('generate app icons and launch logo', () async {
    // iOS app icons: every entry in the icon set's Contents.json.
    const iconSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final contents = jsonDecode(File('$iconSet/Contents.json').readAsStringSync()) as Map<String, dynamic>;
    final done = <String>{};
    for (final image in (contents['images'] as List).cast<Map<String, dynamic>>()) {
      final name = image['filename'] as String;
      if (!done.add(name)) continue;
      final pt = double.parse((image['size'] as String).split('x').first);
      final scale = double.parse((image['scale'] as String).replaceAll('x', ''));
      await _write('$iconSet/$name', await renderTile((pt * scale).round()));
    }

    // Android legacy launcher icons (pre-adaptive launchers).
    const mipmaps = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final e in mipmaps.entries) {
      await _write(
        'android/app/src/main/res/mipmap-${e.key}/ic_launcher.png',
        await renderTile(e.value, radius: e.value * 0.22),
      );
    }

    // iOS launch screen logo: the rounded tile, 120 pt.
    const launch = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
    await _write('$launch/LaunchImage.png', await renderTile(120, radius: 120 * 0.3125));
    await _write('$launch/LaunchImage@2x.png', await renderTile(240, radius: 240 * 0.3125));
    await _write('$launch/LaunchImage@3x.png', await renderTile(360, radius: 360 * 0.3125));
  });
}
