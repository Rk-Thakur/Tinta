import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tinta/data/codec.dart';
import 'package:tinta/data/library_store.dart';
import 'package:tinta/data/models.dart';
import 'package:tinta/data/studio_store.dart';
import 'package:tinta/data/vault.dart';
import 'package:tinta/drawing/brushes.dart';
import 'package:tinta/drawing/replay.dart';
import 'package:tinta/drawing/stroke.dart';
import 'package:tinta/export/render.dart';
import 'package:tinta/services/backup.dart';
import 'package:tinta/services/photo_palette.dart';

import 'fixtures.dart';

Stroke _stroke(
  int id,
  int t0, {
  int points = 5,
  Color color = const Color(0xFF2F4BFF),
  double? pressure,
}) => Stroke(
  id: id,
  brush: BrushKind.ink,
  color: color,
  size: 8,
  opacity: 0.9,
  multiply: true,
  presetId: Brushes.brushPen.id,
  grain: 0.3,
  smoothing: Smoothing.max,
  points: [
    for (var i = 0; i < points; i++)
      StrokePoint(10.0 + i, 20.0 + i, pressure: pressure, t: t0 + i * 10),
  ],
);

SketchPage _page(List<Stroke> strokes) => SketchPage(
  id: 'p1',
  number: 3,
  title: 'Test',
  paper: PaperType.kraft,
  aspect: 1.25,
  riso: true,
  risoInks: const [Color(0xFF2F4BFF), Color(0xFFE8467C)],
  layers: [
    PageLayer(
      id: 'l1',
      name: 'Ink',
      strokes: strokes,
      blend: LayerBlend.multiply,
      opacity: 0.8,
    ),
  ],
);

/// PackBits decoder, to check the encoder round-trips.
Uint8List _unpack(Uint8List data) {
  final out = <int>[];
  var i = 0;
  while (i < data.length) {
    final n = data[i++];
    if (n < 128) {
      out.addAll(data.sublist(i, i + n + 1));
      i += n + 1;
    } else if (n > 128) {
      out.addAll(List.filled(257 - n, data[i++]));
    }
  }
  return Uint8List.fromList(out);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('codec', () {
    test('pages round-trip, with and without stylus pressure', () {
      final page = _page([_stroke(1, 0), _stroke(2, 100, pressure: 0.7)]);
      final back = Codec.pageFrom(Codec.page(page));
      expect(back.title, 'Test');
      expect(back.paper, PaperType.kraft);
      expect(back.aspect, 1.25);
      expect(back.risoInks, page.risoInks);
      final l = back.layers.single;
      expect(l.blend, LayerBlend.multiply);
      expect(l.opacity, 0.8);
      final a = l.strokes[0];
      expect(a.presetId, Brushes.brushPen.id);
      expect(a.smoothing, Smoothing.max);
      expect(a.multiply, isTrue);
      expect(a.points.first.pressure, isNull);
      expect(a.points.last.t, 40);
      expect(l.strokes[1].points.first.pressure, 0.7);
    });

    test('user brushes round-trip', () {
      final mine = Brushes.charcoal.copyAsMine(
        id: 'mine-1',
        size: 12,
        opacity: 0.5,
        grain: 0.9,
        smoothing: Smoothing.off,
      );
      final back = Codec.presetFrom(Codec.preset(mine));
      expect(back.category, BrushCategory.mine);
      expect(back.grain, 0.9);
      expect(back.smoothing, Smoothing.off);
    });
  });

  group('PSD', () {
    test('PackBits round-trips runs and literals', () {
      final data = Uint8List.fromList([
        ...List.filled(300, 0),
        1,
        2,
        3,
        4,
        ...List.filled(5, 9),
        7,
        8,
      ]);
      expect(_unpack(packBits(data)), data);
    });

    test('writes a structurally valid file', () {
      const w = 8, h = 4;
      final layer = Uint8List(w * h * 4)..fillRange(0, 16, 255);
      final bytes = writePsd(
        width: w,
        height: h,
        layers: [
          PsdLayer(
            name: 'Line art',
            rgba: layer,
            blend: LayerBlend.multiply,
            opacity: 0.5,
          ),
        ],
        composite: Uint8List(w * h * 4),
      );
      final d = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '8BPS');
      expect(d.getUint32(14), h);
      expect(d.getUint32(18), w);
      // Skip header (26), color mode (4), resources (4): layer section length.
      final layerSection = d.getUint32(34);
      final layerInfo = d.getUint32(38);
      expect(layerSection, layerInfo + 8);
      expect(d.getInt16(42), 1); // one layer
      // Composite follows the layer section: compression = RLE.
      expect(d.getUint16(38 + layerSection), 1);
      expect(
        String.fromCharCodes(
          bytes.sublist(44 + 16 + 2 + 4 * 6, 44 + 16 + 2 + 4 * 6 + 4),
        ),
        '8BIM',
      );
    });
  });

  group('replay', () {
    test('long pauses are shortened and strokes play in time order', () {
      final page = _page([_stroke(2, 60000), _stroke(1, 0)]);
      final tl = ReplayTimeline([page], maxGapMs: 400);
      expect(tl.strokeCount, 2);
      expect(tl.strokes.first.stroke.id, 1);
      expect(tl.strokes[1].start - tl.strokes[0].end, 400);
      expect(tl.duration.inMilliseconds, lessThan(1000));
    });

    test('frames show finished strokes plus the one in progress', () {
      final tl = ReplayTimeline([
        _page([_stroke(1, 0), _stroke(2, 100)]),
      ]);
      final mid = tl.frameAt(tl.strokes[1].start + 15);
      expect(mid.strokesDone, 1);
      expect(mid.layers.single.strokes.single.id, 1);
      expect(mid.live!.points.length, 2);
      final end = tl.frameAt(tl.duration.inMilliseconds);
      expect(end.strokesDone, 2);
      expect(end.live, isNull);
    });

    test('pages without strokes have nothing to replay', () {
      expect(
        ReplayTimeline([
          const SketchPage(id: 'x', number: 1, paper: PaperType.smooth),
        ]).isEmpty,
        isTrue,
      );
    });
  });

  group('separations', () {
    test('one black sheet per ink; erasers apply to every sheet', () {
      final eraser = Stroke(
        id: 9,
        brush: BrushKind.eraser,
        color: const Color(0xFF000000),
        size: 10,
        points: const [StrokePoint(0, 0)],
      );
      final page = _page([
        _stroke(1, 0),
        _stroke(2, 0, color: const Color(0xFFE8467C)),
        eraser,
      ]);
      expect(pageInks(page), page.risoInks);
      final blue = separationFor(
        page,
        const Color(0xFF2F4BFF),
      ).layers.single.strokes;
      expect(blue.map((s) => s.id), [1, 9]);
      expect(blue.first.color, const Color(0xFF000000));
    });
  });

  test('photo palette finds the dominant colors', () {
    final rgba = Uint8List(100 * 4);
    for (var i = 0; i < 100; i++) {
      final red = i < 70;
      rgba.setAll(i * 4, red ? [220, 30, 30, 255] : [20, 40, 200, 255]);
    }
    final colors = PhotoPalette.extract(rgba, count: 3);
    expect(colors, hasLength(2));
    expect(colors.first.r, greaterThan(0.8));
    expect(colors.last.b, greaterThan(0.7));
  });

  test('library saves to the vault and loads back', () async {
    final dir = await Directory.systemTemp.createTemp('tinta-vault');
    addTearDown(() => dir.delete(recursive: true));
    await Directory('${dir.path}/pages').create();
    await Directory('${dir.path}/exports').create();
    final vault = Vault(dir);

    final store = await LibraryStore.open(vault); // first launch: empty
    expect(store.sketchbooks, isEmpty);
    final book = store.createSketchbook(
      title: 'Travel',
      cover: const CoverDesign(
        color: Color(0xFF2F4BFF),
        band: Color(0xFF17171C),
        motif: CoverMotif.dot,
      ),
      paper: PaperType.smooth,
      format: PageFormat.a5,
    );
    final page = store.addPage(
      SketchPage(
        id: '',
        number: 0,
        paper: PaperType.night,
        layers: [
          PageLayer(id: 'l1', name: 'Line art', strokes: [_stroke(1, 0)]),
        ],
      ),
      bookId: book.id,
    );
    await store.flush();

    final again = await LibraryStore.open(vault);
    expect(
      again.sketchbooks.map((b) => b.title),
      store.sketchbooks.map((b) => b.title),
    );
    final loaded = again.page(page.id)!;
    expect(loaded.paper, PaperType.night);
    expect(loaded.layers.single.strokes.single.points, hasLength(5));
    expect(again.sketchbook(book.id)!.pages.first.id, page.id);
    expect(again.loosePages, hasLength(store.loosePages.length));

    final usage = await vault.usage();
    expect(usage.pages, greaterThan(0));
  });

  group('library management', () {
    test('create, rename and recover a sketchbook', () {
      final store = fixtureLibrary();
      final book = store.createSketchbook(
        title: 'Summer',
        cover: const CoverDesign(
          color: Color(0xFF2E9E6A),
          band: Color(0xFF17171C),
          motif: CoverMotif.wordmark,
        ),
        paper: PaperType.kraft,
        format: PageFormat.square,
      );
      expect(store.sketchbooks.first.id, book.id);
      store.updateSketchbook(book.id, title: 'Summer 26');
      expect(store.sketchbook(book.id)!.title, 'Summer 26');
      expect(store.sketchbook(book.id)!.paper, PaperType.kraft);
    });

    test('move a page between a book and loose pages', () {
      final store = fixtureLibrary();
      final loose = store.loosePages.first;
      final book = store.sketchbooks.first;
      final before = book.pageCount;
      store.movePage(loose.id, bookId: book.id);
      expect(store.loosePages.any((p) => p.id == loose.id), isFalse);
      expect(store.sketchbook(book.id)!.pages.first.id, loose.id);
      expect(store.sketchbook(book.id)!.pages.first.number, before + 1);
      store.movePage(loose.id);
      expect(store.loosePages.first.id, loose.id);
      expect(store.sketchbook(book.id)!.pageCount, before);
    });

    test('duplicate and delete pages; delete a whole book', () {
      final store = fixtureLibrary();
      final book = store.sketchbooks.first;
      final original = book.pages.first;
      final copy = store.duplicatePage(original.id);
      expect(copy.title, '${original.title} copy');
      expect(store.bookOf(copy.id)!.id, book.id);
      store.deletePage(copy.id);
      expect(store.page(copy.id), isNull);
      store.deleteSketchbook(book.id);
      expect(store.sketchbook(book.id), isNull);
      expect(store.page(original.id), isNull);
    });

    test('deleted pages are removed from the vault', () async {
      final dir = await Directory.systemTemp.createTemp('tinta-vault');
      addTearDown(() => dir.delete(recursive: true));
      await Directory('${dir.path}/pages').create();
      await Directory('${dir.path}/exports').create();
      final vault = Vault(dir);
      final store = await LibraryStore.open(vault);
      final book = store.createSketchbook(
        title: 'Doomed',
        cover: const CoverDesign(
          color: Color(0xFF2F4BFF),
          band: Color(0xFF17171C),
          motif: CoverMotif.dot,
        ),
        paper: PaperType.smooth,
        format: PageFormat.a5,
      );
      final page = store.addPage(fixturePage('', 0), bookId: book.id);
      await store.flush();
      final file = File('${dir.path}/${vault.pagePath(page.id)}');
      expect(file.existsSync(), isTrue);
      store.deleteSketchbook(book.id);
      await store.flush();
      expect(file.existsSync(), isFalse);
      final again = await LibraryStore.open(vault);
      expect(again.sketchbook(book.id), isNull);
    });
  });

  group('real stats', () {
    test('active time merges close strokes and ignores long pauses', () {
      final page = _page([
        _stroke(1, 0),
        _stroke(2, 10000),
        _stroke(3, 120000),
      ]);
      // 0–40, 10000–10040 merge (gap 10 s) = 10 040 ms; 120000–120040 = 40 ms.
      expect(page.activeTime().inMilliseconds, 10080);
    });

    test('streak counts consecutive days ending today or yesterday', () {
      final now = DateTime(2026, 10, 21, 9);
      String d(int ago) => dayKey(DateTime(2026, 10, 21 - ago));
      Sketchbook book(List<String> days) => Sketchbook(
        id: 'b',
        title: 'B',
        cover: const CoverDesign(
          color: Color(0xFF000000),
          band: Color(0xFF000000),
          motif: CoverMotif.dot,
        ),
        paper: PaperType.smooth,
        format: PageFormat.a5,
        pages: [
          SketchPage(
            id: 'p',
            number: 1,
            paper: PaperType.smooth,
            drawnDays: days,
          ),
        ],
      );
      expect(book([d(0), d(1), d(2), d(4)]).streakDays(now: now), 3);
      expect(
        book([d(1), d(2)]).streakDays(now: now),
        2,
      ); // not lost before today's session
      expect(book([d(2)]).streakDays(now: now), 0);
    });
  });

  test('old sample content is removed unless it was drawn on', () async {
    final dir = await Directory.systemTemp.createTemp('tinta-vault');
    addTearDown(() => dir.delete(recursive: true));
    await Directory('${dir.path}/pages').create();
    await Directory('${dir.path}/exports').create();
    final vault = Vault(dir);
    // What an earlier build left behind: a sample book with one page the
    // user drew on, an untouched sample book and an untouched sample page.
    const cover = CoverDesign(
      color: Color(0xFF000000),
      band: Color(0xFF000000),
      motif: CoverMotif.dot,
    );
    final drawn = _page([_stroke(1, 0)]);
    const blank = SketchPage(
      id: 'morning-p1',
      number: 1,
      paper: PaperType.toned,
    );
    const blankLoose = SketchPage(
      id: 'loose-1',
      number: 1,
      paper: PaperType.smooth,
    );
    for (final p in [drawn, blank, blankLoose]) {
      await vault.writeJson(vault.pagePath(p.id), Codec.page(p));
    }
    await vault.writeJson('library.json', {
      'v': 1,
      'books': [
        Codec.book(
          Sketchbook(
            id: 'morning',
            title: 'Morning studies',
            cover: cover,
            paper: PaperType.toned,
            format: PageFormat.a5,
            pages: [drawn, blank],
          ),
        ),
        Codec.book(
          const Sketchbook(
            id: 'travel',
            title: 'Travel journal',
            cover: cover,
            paper: PaperType.toned,
            format: PageFormat.a5,
            pages: [],
          ),
        ),
      ],
      'loose': ['loose-1'],
    });

    final store = await LibraryStore.open(vault);
    expect(store.sketchbooks.map((b) => b.id), ['morning']);
    expect(store.sketchbook('morning')!.pages.map((p) => p.id), [drawn.id]);
    expect(store.loosePages, isEmpty);
    expect(
      File('${dir.path}/${vault.pagePath('morning-p1')}').existsSync(),
      isFalse,
    );
  });

  test(
    'backup then restore brings the library back; junk zips are refused',
    () async {
      final dir = await Directory.systemTemp.createTemp('tinta-vault');
      addTearDown(() => dir.delete(recursive: true));
      await Directory('${dir.path}/pages').create();
      await Directory('${dir.path}/exports').create();
      final vault = Vault(dir);
      final library = await LibraryStore.open(vault);
      final studio = StudioStore(vault: vault);
      const cover = CoverDesign(
        color: Color(0xFF2F4BFF),
        band: Color(0xFF17171C),
        motif: CoverMotif.dot,
      );
      final book = library.createSketchbook(
        title: 'Keep me',
        cover: cover,
        paper: PaperType.smooth,
        format: PageFormat.a5,
      );
      final page = library.addPage(
        fixturePage('', 0, title: 'Hands'),
        bookId: book.id,
      );
      studio.addPalette('From photo', const [
        Color(0xFF112233),
        Color(0xFF445566),
      ]);
      final backup = await Backup.create(vault, library);

      // Change everything after the backup.
      library.deleteSketchbook(book.id);
      library.createSketchbook(
        title: 'New stuff',
        cover: cover,
        paper: PaperType.kraft,
        format: PageFormat.a4,
      );
      await library.flush();

      final result = await Backup.restore(backup, vault, library, studio);
      expect(result.sketchbooks, 1);
      expect(library.sketchbooks.single.title, 'Keep me');
      expect(library.page(page.id)!.title, 'Hands');
      expect(studio.palettes.last.name, 'From photo');
      expect(result.safetyBackup.existsSync(), isTrue);

      final junk = File('${dir.path}/junk.zip')
        ..writeAsBytesSync(
          ZipEncoder().encodeBytes(
            Archive()..add(ArchiveFile.string('notes.txt', 'hi')),
          ),
        );
      expect(
        () => Backup.restore(junk, vault, library, studio),
        throwsA(isA<BackupFormatException>()),
      );
      expect(library.sketchbooks.single.title, 'Keep me'); // untouched
    },
  );
}
