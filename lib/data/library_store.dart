import 'dart:async';

import 'package:flutter/widgets.dart';

import 'codec.dart';
import 'models.dart';
import 'seed.dart';
import 'vault.dart';

/// The user's sketchbooks and loose pages. With a [Vault] every change is
/// written to the device (debounced); without one (tests) it lives in memory.
class LibraryStore extends ChangeNotifier {
  LibraryStore._(this._sketchbooks, this._loosePages, this.vault);

  /// In-memory library with the sample content.
  LibraryStore.seeded()
    : this._(List.of(seedSketchbooks), List.of(seedLoosePages), null);

  /// Loads the library from the device, writing the samples on first launch.
  static Future<LibraryStore> open(Vault vault) async {
    final index = await vault.readJson('library.json');
    if (index == null) {
      final store = LibraryStore._(
        List.of(seedSketchbooks),
        List.of(seedLoosePages),
        vault,
      );
      store._dirtyIndex = true;
      store._dirtyPages.addAll(store._allPages.map((p) => p.id));
      await store.flush();
      await store.refreshFreeSpace();
      return store;
    }

    Future<List<SketchPage>> load(List ids) async {
      final pages = <SketchPage>[];
      for (final id in ids.cast<String>()) {
        final j = await vault.readJson(vault.pagePath(id));
        if (j != null) pages.add(Codec.pageFrom(j));
      }
      return pages;
    }

    final books = <Sketchbook>[];
    for (final b in (index['books'] as List? ?? const [])) {
      final j = b as Map<String, Object?>;
      books.add(Codec.bookFrom(j, await load(j['pages'] as List? ?? const [])));
    }
    final loose = await load(index['loose'] as List? ?? const []);
    final store = LibraryStore._(books, loose, vault);
    await store.refreshFreeSpace();
    return store;
  }

  final Vault? vault;
  final List<Sketchbook> _sketchbooks;
  final List<SketchPage> _loosePages;

  List<Sketchbook> get sketchbooks => List.unmodifiable(_sketchbooks);
  List<SketchPage> get loosePages => List.unmodifiable(_loosePages);
  DailyPrompt get dailyPrompt => seedPrompt;

  Iterable<SketchPage> get _allPages => [
    ..._loosePages,
    for (final b in _sketchbooks) ...b.pages,
  ];

  /// Every page, newest first within each group (for the Replays list).
  List<SketchPage> get allPages => _allPages.toList();

  int? _freeBytes;

  /// "1.2 GB free", or null when the platform can't tell.
  String? get freeSpaceLabel =>
      _freeBytes == null ? null : '${formatBytes(_freeBytes!)} free';

  Future<void> refreshFreeSpace() async {
    _freeBytes = await Vault.freeSpace();
    notifyListeners();
  }

  int _nextId = 0;

  /// Adds a fresh page to a sketchbook (as its newest page) or, without a
  /// book, to loose pages. Returns the stored page.
  SketchPage addPage(SketchPage draft, {String? bookId}) {
    final id = 'page-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
    final book = bookId == null ? null : sketchbook(bookId);
    SketchPage make(int number) => SketchPage(
      id: id,
      number: number,
      title: draft.title,
      paper: draft.paper,
      aspect: draft.aspect,
      riso: draft.riso,
      risoInks: draft.risoInks,
      art: draft.art,
      layers: draft.layers,
    );
    final SketchPage page;
    if (book == null) {
      page = make(_loosePages.length + 1);
      _loosePages.insert(0, page);
    } else {
      page = make(book.pageCount + 1);
      _sketchbooks[_sketchbooks.indexOf(book)] = book.copyWith(
        pages: [page, ...book.pages],
      );
    }
    _dirtyIndex = true;
    _dirtyPages.add(id);
    _changed();
    return page;
  }

  /// Saves an edited page wherever it lives.
  void updatePage(SketchPage page) {
    final loose = _loosePages.indexWhere((p) => p.id == page.id);
    if (loose >= 0) {
      _loosePages[loose] = page;
    } else {
      for (var b = 0; b < _sketchbooks.length; b++) {
        final book = _sketchbooks[b];
        final i = book.pages.indexWhere((p) => p.id == page.id);
        if (i >= 0) {
          _sketchbooks[b] = book.copyWith(
            pages: List.of(book.pages)..[i] = page,
          );
          break;
        }
      }
    }
    _dirtyPages.add(page.id);
    _changed();
  }

  // ---- Managing sketchbooks & pages ----------------------------------------

  Sketchbook createSketchbook({
    required String title,
    required CoverDesign cover,
    required PaperType paper,
    required PageFormat format,
  }) {
    final book = Sketchbook(
      id: 'book-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}',
      title: title,
      cover: cover,
      paper: paper,
      format: format,
      pages: const [],
    );
    _sketchbooks.insert(0, book);
    _dirtyIndex = true;
    _changed();
    return book;
  }

  void updateSketchbook(String id, {String? title, CoverDesign? cover}) {
    final i = _sketchbooks.indexWhere((b) => b.id == id);
    if (i < 0) return;
    _sketchbooks[i] = _sketchbooks[i].copyWith(title: title, cover: cover);
    _dirtyIndex = true;
    _changed();
  }

  /// Deletes a sketchbook and every page in it.
  void deleteSketchbook(String id) {
    final i = _sketchbooks.indexWhere((b) => b.id == id);
    if (i < 0) return;
    _dirtyPages.addAll(_sketchbooks[i].pages.map((p) => p.id));
    _sketchbooks.removeAt(i);
    _dirtyIndex = true;
    _changed();
  }

  void renamePage(String id, String title) {
    final p = page(id);
    if (p != null) updatePage(p.copyWith(title: title));
  }

  void deletePage(String id) {
    if (_removePage(id) == null) return;
    _dirtyPages.add(id);
    _dirtyIndex = true;
    _changed();
  }

  /// Moves a page into a sketchbook (as its newest page) or, with a null
  /// [bookId], to loose pages.
  void movePage(String id, {String? bookId}) {
    // Already there: nothing to do.
    if (bookOf(id)?.id == bookId && page(id) != null) return;
    final removed = _removePage(id);
    if (removed == null) return;
    final book = bookId == null ? null : sketchbook(bookId);
    if (book == null) {
      _loosePages.insert(0, removed.copyWith(number: _loosePages.length + 1));
    } else {
      final moved = removed.copyWith(number: book.pageCount + 1);
      _sketchbooks[_sketchbooks.indexOf(book)] = book.copyWith(
        pages: [moved, ...book.pages],
      );
    }
    _dirtyPages.add(id);
    _dirtyIndex = true;
    _changed();
  }

  /// Copies a page next to the original.
  SketchPage duplicatePage(String id) {
    final p = page(id)!;
    return addPage(
      SketchPage(
        id: '',
        number: 0,
        title: '${p.title ?? 'Untitled'} copy',
        paper: p.paper,
        aspect: p.aspect,
        riso: p.riso,
        risoInks: p.risoInks,
        art: p.art,
        layers: p.layers,
      ),
      bookId: bookOf(id)?.id,
    );
  }

  SketchPage? _removePage(String id) {
    final loose = _loosePages.indexWhere((p) => p.id == id);
    if (loose >= 0) return _loosePages.removeAt(loose);
    for (var b = 0; b < _sketchbooks.length; b++) {
      final book = _sketchbooks[b];
      final i = book.pages.indexWhere((p) => p.id == id);
      if (i >= 0) {
        final removed = book.pages[i];
        _sketchbooks[b] = book.copyWith(
          pages: List.of(book.pages)..removeAt(i),
        );
        return removed;
      }
    }
    return null;
  }

  /// Latest stored version of a page, or null if it's gone.
  SketchPage? page(String id) {
    for (final p in _allPages) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// The sketchbook a page belongs to (null for loose pages).
  Sketchbook? bookOf(String pageId) {
    for (final b in _sketchbooks) {
      if (b.pages.any((p) => p.id == pageId)) return b;
    }
    return null;
  }

  Sketchbook? sketchbook(String id) {
    for (final b in _sketchbooks) {
      if (b.id == id) return b;
    }
    return null;
  }

  // ---- Persistence ---------------------------------------------------------

  final Set<String> _dirtyPages = {};
  bool _dirtyIndex = false;
  Timer? _saveTimer;
  Future<void>? _flushing;

  void _changed() {
    notifyListeners();
    if (vault == null) {
      _dirtyPages.clear();
      _dirtyIndex = false;
      return;
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), flush);
  }

  /// Writes pending changes now (also called when the app goes to background).
  Future<void> flush() async {
    _saveTimer?.cancel();
    final v = vault;
    if (v == null) return;
    // Serialize flushes so files are never written concurrently.
    while (_flushing != null) {
      await _flushing;
    }
    final pages = Set.of(_dirtyPages);
    final index = _dirtyIndex;
    _dirtyPages.clear();
    _dirtyIndex = false;
    if (pages.isEmpty && !index) return;
    final done = () async {
      for (final id in pages) {
        final p = page(id);
        // A dirty id that no longer exists was deleted: remove its file.
        if (p != null) {
          await v.writeJson(v.pagePath(id), Codec.page(p));
        } else {
          await v.delete(v.pagePath(id));
        }
      }
      if (index) {
        await v.writeJson('library.json', {
          'v': Codec.version,
          'books': [for (final b in _sketchbooks) Codec.book(b)],
          'loose': [for (final p in _loosePages) p.id],
        });
      }
    }();
    _flushing = done;
    try {
      await done;
    } finally {
      _flushing = null;
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}

/// Makes the [LibraryStore] available below it in the tree.
class LibraryScope extends InheritedNotifier<LibraryStore> {
  const LibraryScope({
    super.key,
    required LibraryStore store,
    required super.child,
  }) : super(notifier: store);

  static LibraryStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LibraryScope>()!.notifier!;
}
