import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/routes.dart';
import '../data/library_store.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/art.dart';
import '../ui/widgets/paper.dart';
import '../ui/format.dart';
import '../ui/widgets/widgets.dart';
import 'library_screen.dart';
import 'page_actions.dart';

enum _View { pages, flip }

class SketchbookScreen extends StatefulWidget {
  const SketchbookScreen({super.key, required this.bookId});

  final String bookId;

  @override
  State<SketchbookScreen> createState() => _SketchbookScreenState();
}

class _SketchbookScreenState extends State<SketchbookScreen> {
  _View _view = _View.pages;

  @override
  Widget build(BuildContext context) {
    final book = LibraryScope.of(context).sketchbook(widget.bookId);
    if (book == null) {
      return const Scaffold(
        body: Center(child: Text('This sketchbook is gone.')),
      );
    }
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(book: book)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                TintaSpace.gutter,
                16,
                TintaSpace.gutter,
                12,
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  SegmentedPills<_View>(
                    options: _View.values,
                    value: _view,
                    dense: true,
                    labelOf: (v) => v == _View.pages ? 'Pages' : 'Flip‑through',
                    onChanged: (v) => setState(() => _view = v),
                  ),
                  _ReplayButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .pushNamed(Routes.replay, arguments: book.id),
                  ),
                ],
              ),
            ),
          ),
          if (_view == _View.pages)
            _PagesGrid(book: book)
          else
            SliverFillRemaining(
              hasScrollBody: false,
              child: _FlipThrough(book: book),
            ),
          SliverToBoxAdapter(
            child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.book});

  final Sketchbook book;

  @override
  Widget build(BuildContext context) {
    final bg = book.cover.color;
    final darkBg = bg.computeLuminance() < 0.25;
    final fg = darkBg ? Colors.white : TintaInk.studioInk;
    final accent = book.cover.motif == CoverMotif.dot
        ? book.cover.motifColor
        : book.cover.band;
    final statBg = bg.computeLuminance() < 0.05
        ? TintaColors.dockRaised
        : TintaInk.studioInk;
    final top = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkBg ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(color: bg),
        child: Stack(
          children: [
            Positioned(
              right: -60,
              top: -20,
              width: 220,
              height: 220,
              child: ArtView(
                Artwork(const Size(220, 220), [
                  ArtCircle(110, 110, 100, fill: accent, opacity: 0.9),
                ]),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                TintaSpace.gutter,
                top + 8,
                TintaSpace.gutter,
                22,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TileIconButton(
                        icon: TintaIcons.back,
                        label: 'Back to library',
                        radius: 22,
                        background: fg.withValues(alpha: 0.18),
                        foreground: fg,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      TileIconButton(
                        icon: TintaIcons.more,
                        label: 'More options',
                        radius: 22,
                        background: TintaInk.studioInk,
                        foreground: Colors.white,
                        onPressed: () => _showOptions(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SKETCHBOOK · ${book.format.label} · ${book.paper.label} paper'
                        .toUpperCase(),
                    style: TintaType.mono(
                      11,
                      color: fg,
                    ).copyWith(letterSpacing: 1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    book.title,
                    style: TintaType.display(36, color: fg).copyWith(height: 1),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Stat(
                        value: '${book.drawnCount}',
                        label: book.drawnCount == 1 ? 'page' : 'pages',
                        background: statBg,
                      ),
                      _Stat(
                        value: formatDrawn(book.timeDrawn),
                        label: 'drawn',
                        background: statBg,
                      ),
                      _Stat(
                        value:
                            '${book.streakDays()} ${book.streakDays() == 1 ? 'day' : 'days'}',
                        label: 'streak',
                        background: statBg,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) =>
      showBookActions(context, book, popAfterDelete: true);
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.background,
  });

  final String value;
  final String label;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(TintaRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TintaType.mono(
              16,
              weight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TintaType.body(
              11,
              color: TintaColors.studioSubtle,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplayButton extends StatelessWidget {
  const _ReplayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: TintaIcon(
        TintaIcons.play,
        size: 16,
        strokeWidth: 2.2,
        color: TintaColors.studioInk,
      ),
      label: const Text('Replay book'),
      style: OutlinedButton.styleFrom(
        foregroundColor: TintaColors.studioInk,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        side: BorderSide(color: TintaColors.studioInk, width: 1.5),
        shape: const StadiumBorder(),
        textStyle: TintaType.body(13, weight: FontWeight.w700),
      ),
    );
  }
}

class _PagesGrid extends StatelessWidget {
  const _PagesGrid({required this.book});

  final Sketchbook book;

  @override
  Widget build(BuildContext context) {
    final pages = book.drawnPages;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: TintaSpace.gutter),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          mainAxisExtent: 196 + 6 + 20,
        ),
        itemCount: pages.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return _TurnPageTile(bookId: book.id);
          final page = pages[i - 1];
          return _PageCell(book: book, page: page);
        },
      ),
    );
  }
}

class _PageCell extends StatelessWidget {
  const _PageCell({required this.book, required this.page});

  final Sketchbook book;
  final SketchPage page;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${page.title ?? 'Untitled'}, page ${page.number}',
      excludeSemantics: true,
      child: GestureDetector(
        onLongPress: () => showPageActions(context, page),
        onTap: () => Navigator.of(context).pushNamed(
          Routes.canvas,
          arguments: CanvasArgs.page(page, bookId: book.id),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: PageThumb(page: page)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    page.title ?? 'Untitled',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TintaType.body(
                      13,
                      weight: page.title == null
                          ? FontWeight.w400
                          : FontWeight.w700,
                      color: page.title == null
                          ? TintaColors.ink2
                          : TintaColors.studioInk,
                      height: 1.2,
                    ),
                  ),
                ),
                Text(
                  'p.${page.number}',
                  style: TintaType.mono(13, color: TintaColors.ink2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TurnPageTile extends StatelessWidget {
  const _TurnPageTile({required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(TintaRadii.sm),
          onTap: () =>
              Navigator.of(context)
                  .pushNamed(Routes.newCanvas, arguments: bookId),
          child: CustomPaint(
            painter: const _DashedBorder(),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TintaIcon(
                    TintaIcons.plus,
                    size: 24,
                    strokeWidth: 2.2,
                    color: TintaColors.ink2,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Turn the page',
                    style: TintaType.body(
                      14,
                      weight: FontWeight.w500,
                      color: TintaColors.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder();

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      const Radius.circular(TintaRadii.sm),
    );
    final paint = Paint()
      ..color = TintaColors.studioDisabled
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FlipThrough extends StatefulWidget {
  const _FlipThrough({required this.book});

  final Sketchbook book;

  @override
  State<_FlipThrough> createState() => _FlipThroughState();
}

class _FlipThroughState extends State<_FlipThrough> {
  final _controller = PageController(viewportFraction: 0.82);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.book.drawnPages;
    if (pages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          'No pages yet. Turn the page to start.',
          textAlign: TextAlign.center,
          style: TintaType.body13,
        ),
      );
    }
    final page = pages[_index.clamp(0, pages.length - 1)];
    return Column(
      children: [
        SizedBox(
          height: 440,
          child: PageView.builder(
            controller: _controller,
            itemCount: pages.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pushNamed(
                  Routes.canvas,
                  arguments: CanvasArgs.page(pages[i], bookId: widget.book.id),
                ),
                child: PageThumb(page: pages[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          page.title ?? 'Untitled',
          style: TintaType.body(15, weight: FontWeight.w700),
        ),
        Text(
          'p.${page.number} of ${pages.length}',
          style: TintaType.mono(12, color: TintaColors.ink2),
        ),
      ],
    );
  }
}
