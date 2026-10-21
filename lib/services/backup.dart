import 'dart:io';

import 'package:archive/archive.dart';

import '../data/library_store.dart';
import '../data/vault.dart';

/// Zips the whole vault (pages, library, palettes, settings) into one file
/// the user can keep wherever they like. Exports are not included.
abstract final class Backup {
  static Future<File> create(Vault vault, LibraryStore store) async {
    await store.flush();
    final archive = Archive();
    for (final rel in await vault.allFiles()) {
      final bytes = await File('${vault.root.path}/$rel').readAsBytes();
      archive.add(ArchiveFile.bytes('tinta/$rel', bytes));
    }
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name =
        'tinta-backup-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}.zip';
    final file = File('${vault.exportsDir.path}/$name');
    await file.writeAsBytes(ZipEncoder().encodeBytes(archive), flush: true);
    return file;
  }
}
