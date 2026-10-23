// Renders the app icons, launch logo and Android adaptive layers from the
// Misprint "t" (lib/ui/logo.dart).
//
// Run from the project root (not part of the normal test suite):
//   flutter test tool/generate_assets_test.dart
// Set PREVIEW=<dir> to also write a preview sheet of every variant.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinta/theme/tokens.dart';
import 'package:tinta/ui/logo.dart';

/// Icon tile: background + mark. [markHeight] is the mark's share of the tile.
Future<List<int>> renderIcon(
  int size,
  LogoStyle style, {
  Color? background,
  double radius = 0,
  double markHeight = 0.6,
  bool transparent = false,
  Color markColor = TintaInk.studioInk,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size.toDouble();
  final bg = background ??
      switch (style) {
        LogoStyle.studio || LogoStyle.small => TintaInk.studioInk,
        LogoStyle.sun => TintaColors.sun,
        _ => TintaInk.newsprint,
      };
  if (!transparent) {
    final paint = Paint()..color = bg;
    if (radius == 0) {
      canvas.drawRect(Offset.zero & Size(s, s), paint);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & Size(s, s), Radius.circular(radius)), paint);
    }
  }
  final h = s * markHeight;
  paintLogoMark(canvas, Rect.fromCenter(center: Offset(s / 2, s / 2), width: s * 0.9, height: h), style, color: markColor);
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
    // iOS: every size in the icon set. Below 48px the mark is one ink.
    const iconSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final contents = jsonDecode(File('$iconSet/Contents.json').readAsStringSync()) as Map<String, dynamic>;
    final done = <String>{};
    for (final image in (contents['images'] as List).cast<Map<String, dynamic>>()) {
      final name = image['filename'] as String?;
      if (name == null || !done.add(name)) continue;
      final appearance = (image['appearances'] as List?)?.cast<Map<String, dynamic>>().firstOrNull?['value'];
      final pt = double.parse((image['size'] as String).split('x').first);
      final scale = double.parse((image['scale'] as String? ?? '1x').replaceAll('x', ''));
      final px = (pt * scale).round();
      final style = appearance == 'dark' ? LogoStyle.studio : (px < 48 ? LogoStyle.small : LogoStyle.paper);
      await _write('$iconSet/$name', await renderIcon(px, style, markHeight: px < 48 ? 0.66 : 0.6));
    }

    // Android legacy launcher icons.
    const mipmaps = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final e in mipmaps.entries) {
      await _write(
        'android/app/src/main/res/mipmap-${e.key}/ic_launcher.png',
        await renderIcon(e.value, LogoStyle.paper, radius: e.value * 0.22),
      );
    }
    // Android adaptive layers: 108dp canvas, mark inside the 66dp safe zone.
    const adaptive = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432};
    for (final e in adaptive.entries) {
      await _write(
        'android/app/src/main/res/mipmap-${e.key}/ic_launcher_foreground.png',
        await renderIcon(e.value, LogoStyle.paper, transparent: true, markHeight: 0.42),
      );
      await _write(
        'android/app/src/main/res/mipmap-${e.key}/ic_launcher_monochrome.png',
        await renderIcon(e.value, LogoStyle.oneColor, transparent: true, markHeight: 0.42, markColor: const Color(0xFFFFFFFF)),
      );
    }

    // iOS launch screen: the mark on the newsprint ground (120pt).
    const launch = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
    for (final (name, px) in [('LaunchImage.png', 120), ('LaunchImage@2x.png', 240), ('LaunchImage@3x.png', 360)]) {
      await _write('$launch/$name', await renderIcon(px, LogoStyle.paper, transparent: true, markHeight: 0.9));
    }

    // Optional preview sheet of every variant.
    final preview = Platform.environment['PREVIEW'];
    if (preview != null) {
      for (final (name, style) in [
        ('paper', LogoStyle.paper),
        ('studio', LogoStyle.studio),
        ('sun', LogoStyle.sun),
        ('small', LogoStyle.small),
      ]) {
        await _write('$preview/icon-$name.png', await renderIcon(512, style, radius: 512 * 0.22));
      }
      await _write('$preview/icon-small-40.png', await renderIcon(40, LogoStyle.small, radius: 9, markHeight: 0.66));
    }
  });
}
