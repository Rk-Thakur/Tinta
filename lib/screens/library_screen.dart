import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../data/library_store.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/widgets/main_nav.dart';
import '../ui/widgets/paper.dart';
import '../ui/format.dart';
import '../ui/widgets/dialogs.dart';
import '../ui/widgets/widgets.dart';
import 'page_actions.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _searching = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = LibraryScope.of(context);
    final books = store.sketchbooks
        .where(
          (b) => b.title.toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList();

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.only(
                top: 8,
                bottom: MainNav.height + MainNav.bottomOffset(context) + 20,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TintaSpace.gutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: OnDeviceBadge(
                              text: store.freeSpaceLabel == null
                                  ? 'On device'
                                  : 'On device · ${store.freeSpaceLabel}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          TileIconButton(
                            icon: _searching
                                ? TintaIcons.close
                                : TintaIcons.search,
                            label: _searching ? 'Close search' : 'Search',
                            radius: 22,
                            iconSize: 20,
                            strokeWidth: 2,
                            background: TintaColors.surface,
                            foreground: TintaColors.studioInk,
                            borderColor: TintaColors.line,
                            onPressed: () => setState(() {
                              _searching = !_searching;
                              _query = '';
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (_searching)
                        _SearchField(
                          onChanged: (q) => setState(() => _query = q),
                        )
                      else
                        Text(
                          'Your studio',
                          style: TintaType.display34.copyWith(height: 1),
                        ),
                      const SizedBox(height: 18),
                      if (!_searching) _PromptCard(prompt: store.dailyPrompt),
                    ],
                  ),
                ),
                _SectionHeader(
                  title: 'Sketchbooks',
                  padding: const EdgeInsets.fromLTRB(
                    TintaSpace.gutter,
                    24,
                    TintaSpace.gutter,
                    10,
                  ),
                  trailing: TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(Routes.sketchbooks),
                    style: TextButton.styleFrom(
                      foregroundColor: TintaColors.risoBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(44, 44),
                      textStyle: TintaType.body(14, weight: FontWeight.w500),
                    ),
                    child: const Text('See all'),
                  ),
                ),
                SizedBox(
                  height: 230,
                  child: books.isEmpty && _searching
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TintaSpace.gutter,
                          ),
                          child: Text(
                            'No sketchbooks match “$_query”.',
                            style: TintaType.body13,
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(
                            TintaSpace.gutter,
                            4,
                            TintaSpace.gutter,
                            8,
                          ),
                          itemCount: books.length + (_searching ? 0 : 1),
                          separatorBuilder: (_, _) => const SizedBox(width: 14),
                          itemBuilder: (context, i) => i == books.length
                              ? const NewBookTile()
                              : BookTile(book: books[i]),
                        ),
                ),
                if (!_searching) ...[
                  _SectionHeader(
                    title: 'Loose pages',
                    padding: const EdgeInsets.fromLTRB(
                      TintaSpace.gutter,
                      16,
                      TintaSpace.gutter,
                      10,
                    ),
                    trailing: Text(
                      'Recent',
                      style: TintaType.mono(12, color: TintaColors.ink2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TintaSpace.gutter,
                    ),
                    child: store.drawnLoosePages.isEmpty
                        ? Text(
                            'Pages you start with + land here until you move them into a sketchbook.',
                            style: TintaType.body13,
                          )
                        : GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: 104,
                            children: [
                              for (final p in store.drawnLoosePages)
                                _LoosePageCard(page: p),
                            ],
                          ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: MainNav.margin,
            right: MainNav.margin,
            bottom: MainNav.bottomOffset(context),
            child: const MainNav(current: MainTab.library),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: true,
      onChanged: onChanged,
      style: TintaType.body(17),
      decoration: InputDecoration(
        hintText: 'Search sketchbooks',
        hintStyle: TintaType.body(17, color: TintaColors.ink2),
        filled: true,
        fillColor: TintaColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TintaRadii.md),
          borderSide: const BorderSide(color: TintaColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TintaRadii.md),
          borderSide: const BorderSide(color: TintaColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TintaRadii.md),
          borderSide: const BorderSide(color: TintaColors.studioInk, width: 2),
        ),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.prompt});

  final DailyPrompt prompt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      decoration: BoxDecoration(
        color: TintaColors.sun,
        borderRadius: BorderRadius.circular(TintaRadii.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAILY PROMPT · ${prompt.minutes} MIN',
                  style: TintaType.mono(
                    11,
                    color: TintaColors.studioInk,
                  ).copyWith(letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  prompt.text,
                  style: TintaType.display(
                    20,
                    weight: FontWeight.w600,
                  ).copyWith(height: 1.15),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          TileIconButton(
            icon: TintaIcons.play,
            label: 'Start prompt',
            size: 52,
            radius: TintaRadii.md,
            iconSize: 22,
            background: TintaColors.studioInk,
            foreground: TintaColors.sun,
            onPressed: () {
              // Make the page here, then open it on the canvas.
              final page = LibraryScope.of(context).addPage(
                SketchPage(
                  id: '',
                  number: 0,
                  title: prompt.text,
                  paper: PaperType.smooth,
                ),
              );
              Navigator.of(context)
                  .pushNamed(Routes.canvas, arguments: CanvasArgs.page(page));
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.padding,
    this.trailing,
  });

  final String title;
  final EdgeInsets padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(title, style: TintaType.title22)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Cover plus title and page count; opens the sketchbook.
class BookTile extends StatelessWidget {
  const BookTile({super.key, required this.book, this.width = 124});

  final Sketchbook book;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${book.title}, ${plural(book.drawnCount, 'page')}',
      excludeSemantics: true,
      child: GestureDetector(
        onLongPress: () => showBookActions(context, book),
        onTap: () =>
            Navigator.of(context)
                .pushNamed(Routes.sketchbook, arguments: book.id),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: 'cover-${book.id}',
                child: SketchbookCover(
                  cover: book.cover,
                  width: width,
                  title: book.title,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                book.title,
                style: TintaType.body(14, weight: FontWeight.w700, height: 1.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                plural(book.drawnCount, 'page'),
                style: TintaType.body(12, color: TintaColors.ink2, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoosePageCard extends StatelessWidget {
  const _LoosePageCard({required this.page});

  final SketchPage page;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TintaColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: TintaColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: () => showPageActions(context, page),
        onTap: () =>
            Navigator.of(context)
                .pushNamed(Routes.canvas, arguments: CanvasArgs.page(page)),
        child: Semantics(
          label: 'Loose page',
          button: true,
          child: PagePreview(page: page),
        ),
      ),
    );
  }
}

/// Long-press menu for a sketchbook.
Future<void> showBookActions(
  BuildContext context,
  Sketchbook book, {
  bool popAfterDelete = false,
}) {
  final store = LibraryScope.of(context);
  return showActionSheet(
    context,
    title: book.title,
    subtitle: plural(book.drawnCount, 'page'),
    actions: [
      SheetAction(
        'Edit name & cover',
        TintaIcons.pencil,
        () => Navigator.of(context).pushNamed(Routes.book, arguments: book.id),
      ),
      SheetAction('Delete sketchbook', TintaIcons.close, destructive: true, () async {
        final ok = await confirmAction(
          context,
          title: 'Delete “${book.title}”?',
          message: book.drawnCount == 0
              ? 'This empty sketchbook is removed.'
              : book.drawnCount == 1
              ? 'Its page and replay are removed from this device. This can’t be undone.'
              : 'All ${book.drawnCount} pages and their replays are removed from this device. This can’t be undone.',
          confirmLabel: 'Delete',
        );
        if (!ok || !context.mounted) return;
        if (popAfterDelete) Navigator.of(context).pop();
        store.deleteSketchbook(book.id);
      }),
    ],
  );
}

/// Dashed "+ New sketchbook" tile at the end of the shelf.
class NewBookTile extends StatelessWidget {
  const NewBookTile({super.key, this.width = 124});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'New sketchbook',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed(Routes.book),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: width,
                height: width * 164 / 124,
                child: CustomPaint(
                  painter: const DashedRRectPainter(radius: 16),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        const TintaIcon(
                          TintaIcons.plus,
                          size: 24,
                          strokeWidth: 2.2,
                          color: TintaColors.ink2,
                        ),
                        Text(
                          'New',
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
              const SizedBox(height: 8),
              Text(
                'New sketchbook',
                style: TintaType.body(14, weight: FontWeight.w700, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashedRRectPainter extends CustomPainter {
  const DashedRRectPainter({this.radius = TintaRadii.sm});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      Radius.circular(radius),
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
  bool shouldRepaint(DashedRRectPainter old) => old.radius != radius;
}
