import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Bytes used on device, by kind, for the Settings "Local vault" card.
class VaultUsage {
  const VaultUsage({
    required this.pages,
    required this.exports,
    required this.studio,
    this.freeBytes,
  });

  final int pages;
  final int exports;
  final int studio;

  /// Free space on the device, when the platform reports it.
  final int? freeBytes;

  int get total => pages + exports + studio;
}

/// Tinta's private folder on the device. Nothing in here is ever uploaded.
///
/// Layout:
///   library.json      sketchbooks + page order
///   pages/{id}.json   one file per page, strokes included
///   studio.json       palettes and "Mine" brushes
///   prefs.json        app settings
///   exports/          files made by Export, kept until shared or cleared
class Vault {
  Vault(this.root);

  final Directory root;

  static const _device = MethodChannel('tinta/device');

  static Future<Vault> open() async {
    final base = await getApplicationSupportDirectory();
    final root = Directory('${base.path}/tinta');
    await Directory('${root.path}/pages').create(recursive: true);
    await Directory('${root.path}/exports').create(recursive: true);
    return Vault(root);
  }

  Directory get exportsDir => Directory('${root.path}/exports');

  File _file(String rel) => File('${root.path}/$rel');
  String pagePath(String id) => 'pages/${_safe(id)}.json';

  static String _safe(String id) =>
      id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  Future<Map<String, Object?>?> readJson(String rel) async {
    final f = _file(rel);
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString()) as Map<String, Object?>;
    } on FormatException {
      // A damaged file is set aside rather than crashing the app.
      await f.rename(
        '${f.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}',
      );
      return null;
    }
  }

  /// Writes via a temp file and rename, so a crash never leaves half a file.
  Future<void> writeJson(String rel, Map<String, Object?> data) async {
    final f = _file(rel);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }

  Future<void> delete(String rel) async {
    final f = _file(rel);
    if (await f.exists()) await f.delete();
  }

  /// Every file in the vault (for backups), as paths relative to [root].
  Future<List<String>> allFiles() async {
    final out = <String>[];
    await for (final e in root.list(recursive: true)) {
      if (e is File &&
          !e.path.endsWith('.tmp') &&
          !e.path.contains('/exports/')) {
        out.add(e.path.substring(root.path.length + 1));
      }
    }
    return out;
  }

  Future<VaultUsage> usage() async {
    Future<int> sizeOf(Directory d) async {
      if (!await d.exists()) return 0;
      var n = 0;
      await for (final e in d.list(recursive: true)) {
        if (e is File) n += await e.length();
      }
      return n;
    }

    Future<int> fileSize(String rel) async {
      final f = _file(rel);
      return await f.exists() ? f.length() : 0;
    }

    final pages =
        await sizeOf(Directory('${root.path}/pages')) +
        await fileSize('library.json');
    final exports = await sizeOf(exportsDir);
    final studio = await fileSize('studio.json') + await fileSize('prefs.json');
    return VaultUsage(
      pages: pages,
      exports: exports,
      studio: studio,
      freeBytes: await freeSpace(),
    );
  }

  Future<void> clearExports() async {
    if (await exportsDir.exists()) await exportsDir.delete(recursive: true);
    await exportsDir.create(recursive: true);
  }

  /// Free bytes on the device's data volume (native channel; null if unknown).
  static Future<int?> freeSpace() async {
    try {
      return await _device.invokeMethod<int>('freeSpace');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

/// "1.2 GB", "840 MB", "12 KB".
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1000 && i < units.length - 1) {
    v /= 1000;
    i++;
  }
  final digits = v >= 100 || i == 0 ? 0 : 1;
  return '${v.toStringAsFixed(digits)} ${units[i]}';
}
