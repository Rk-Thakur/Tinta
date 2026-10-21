import 'dart:io';

import 'package:archive/archive.dart';

import '../data/library_store.dart';
import '../data/studio_store.dart';
import '../data/vault.dart';

class RestoreResult {
  const RestoreResult({
    required this.sketchbooks,
    required this.pages,
    required this.safetyBackup,
  });

  final int sketchbooks;
  final int pages;

  /// A backup of what was on the device just before the restore.
  final File safetyBackup;
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Zips the whole vault (pages, library, palettes, settings) into one file
/// the user can keep wherever they like. Exports are not included.
abstract final class Backup {
  static Future<File> create(
    Vault vault,
    LibraryStore store, {
    String prefix = 'tinta-backup',
  }) async {
    await store.flush();
    final archive = Archive();
    for (final rel in await vault.allFiles()) {
      final bytes = await File('${vault.root.path}/$rel').readAsBytes();
      archive.add(ArchiveFile.bytes('tinta/$rel', bytes));
    }
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name =
        '$prefix-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}.zip';
    final file = File('${vault.exportsDir.path}/$name');
    await file.writeAsBytes(ZipEncoder().encodeBytes(archive), flush: true);
    return file;
  }

  /// Only these files are ever written back from a backup.
  static final _allowed = RegExp(
    r'^(library\.json|studio\.json|pages/[A-Za-z0-9_-]+\.json)$',
  );

  /// Replaces this device's library, pages, palettes and brushes with the
  /// backup's. Device settings (reminder, dock side) are kept. The current
  /// state is saved to a safety backup first.
  static Future<RestoreResult> restore(
    File zip,
    Vault vault,
    LibraryStore library,
    StudioStore studio,
  ) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    } catch (_) {
      throw const BackupFormatException(
        'That file isn’t a Tinta backup (it couldn’t be opened as a zip).',
      );
    }

    final files = <String, List<int>>{};
    for (final entry in archive) {
      if (!entry.isFile || !entry.name.startsWith('tinta/')) continue;
      final rel = entry.name.substring('tinta/'.length);
      if (_allowed.hasMatch(rel)) files[rel] = entry.content;
    }
    if (!files.containsKey('library.json')) {
      throw const BackupFormatException(
        'That file isn’t a Tinta backup (no library inside).',
      );
    }

    final safety = await create(vault, library, prefix: 'tinta-before-restore');

    final pagesDir = Directory('${vault.root.path}/pages');
    if (await pagesDir.exists()) await pagesDir.delete(recursive: true);
    await pagesDir.create(recursive: true);
    final studioFile = File('${vault.root.path}/studio.json');
    if (await studioFile.exists()) await studioFile.delete();
    for (final e in files.entries) {
      await File('${vault.root.path}/${e.key}')
          .writeAsBytes(e.value, flush: true);
    }

    await library.reload();
    await studio.reload();
    return RestoreResult(
      sketchbooks: library.sketchbooks.length,
      pages: library.allPages.length,
      safetyBackup: safety,
    );
  }
}
