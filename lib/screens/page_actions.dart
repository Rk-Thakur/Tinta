import 'package:flutter/material.dart';

import '../data/library_store.dart';
import '../data/models.dart';
import '../ui/icons.dart';
import '../ui/widgets/dialogs.dart';

/// Long-press menu for a page: rename, duplicate, move, delete.
Future<void> showPageActions(BuildContext context, SketchPage page) {
  final store = LibraryScope.of(context);
  final book = store.bookOf(page.id);
  final name = page.title ?? 'Untitled';
  return showActionSheet(
    context,
    title: name,
    subtitle: book == null ? 'Loose page' : '${book.title} · p.${page.number}',
    actions: [
      SheetAction('Rename', TintaIcons.pencil, () async {
        final title = await promptText(
          context,
          title: 'Rename page',
          initial: page.title ?? '',
        );
        if (title != null) store.renamePage(page.id, title);
      }),
      SheetAction(
        'Duplicate',
        TintaIcons.layers,
        () => store.duplicatePage(page.id),
      ),
      SheetAction(
        'Move to…',
        TintaIcons.book,
        () => _move(context, store, page, book),
      ),
      SheetAction('Delete page', TintaIcons.close, destructive: true, () async {
        final ok = await confirmAction(
          context,
          title: 'Delete “$name”?',
          message: 'The page and its replay are removed from this device. This can’t be undone.',
          confirmLabel: 'Delete',
        );
        if (ok) store.deletePage(page.id);
      }),
    ],
  );
}

void _move(
  BuildContext context,
  LibraryStore store,
  SketchPage page,
  Sketchbook? from,
) {
  showActionSheet(
    context,
    title: 'Move to',
    actions: [
      if (from != null)
        SheetAction(
          'Loose pages',
          TintaIcons.grid,
          () => store.movePage(page.id),
        ),
      for (final b in store.sketchbooks)
        if (b.id != from?.id)
          SheetAction(
            b.title,
            TintaIcons.book,
            () => store.movePage(page.id, bookId: b.id),
          ),
    ],
  );
}
