import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../data/library_store.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/widgets/paper.dart';
import '../ui/widgets/widgets.dart';

/// Make a sketchbook, or (with [bookId]) edit one's name and cover.
/// Paper and size are fixed once a book exists, so they only show when new.
class SketchbookSheet extends StatefulWidget {
  const SketchbookSheet({super.key, this.bookId});

  final String? bookId;

  @override
  State<SketchbookSheet> createState() => _SketchbookSheetState();
}

class _SketchbookSheetState extends State<SketchbookSheet> {
  final _title = TextEditingController();
  CoverDesign _cover = coverPresets.first;
  PaperType _paper = PaperType.toned;
  PageFormat _format = PageFormat.a5;
  Sketchbook? _editing;

  static const _formats = [PageFormat.a5, PageFormat.a4, PageFormat.square];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.bookId == null || _editing != null) return;
    _editing = LibraryScope.of(context).sketchbook(widget.bookId!);
    if (_editing != null) {
      _title.text = _editing!.title;
      _cover = _editing!.cover;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String get _name =>
      _title.text.trim().isEmpty ? 'Untitled sketchbook' : _title.text.trim();

  void _save() {
    final store = LibraryScope.of(context);
    final editing = _editing;
    if (editing != null) {
      store.updateSketchbook(editing.id, title: _name, cover: _cover);
      Navigator.of(context).pop();
      return;
    }
    final book = store.createSketchbook(
      title: _name,
      cover: _cover,
      paper: _paper,
      format: _format,
    );
    Navigator.of(context)
        .pushReplacementNamed(Routes.sketchbook, arguments: book.id);
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editing != null;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: TintaColors.studioMuted,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    editing ? 'Edit sketchbook' : 'New sketchbook',
                    style: TintaType.display28,
                  ),
                ),
                TileIconButton(
                  icon: TintaIcons.close,
                  label: 'Close',
                  radius: 22,
                  iconSize: 18,
                  strokeWidth: 2.4,
                  background: TintaColors.segmentTrack,
                  foreground: TintaColors.studioInk,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: !editing,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              style: TintaType.body(17),
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'Untitled sketchbook',
                filled: true,
                fillColor: TintaColors.surface,
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
                  borderSide: const BorderSide(
                    color: TintaColors.studioInk,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'COVER',
              style: TintaType.mono(
                11,
                color: TintaColors.ink2,
              ).copyWith(letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            SizedBox(
              // Two rows that scroll sideways: lots of covers, short sheet.
              height: 112 * 2 + 10,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: coverPresets.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 84,
                ),
                itemBuilder: (context, i) {
                  final c = coverPresets[i];
                  final selected = _sameCover(c, _cover);
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: 'Cover ${i + 1}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => setState(() => _cover = c),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selected
                                ? TintaColors.risoBlue
                                : Colors.transparent,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: SketchbookCover(
                          cover: c,
                          width: 72,
                          title: _name,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (!editing) ...[
              const SizedBox(height: 18),
              Text(
                'PAPER',
                style: TintaType.mono(
                  11,
                  color: TintaColors.ink2,
                ).copyWith(letterSpacing: 1),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in PaperType.values)
                    TintaChip(
                      label: p.label,
                      selected: p == _paper,
                      height: 38,
                      onTap: () => setState(() => _paper = p),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'PAGE SIZE',
                style: TintaType.mono(
                  11,
                  color: TintaColors.ink2,
                ).copyWith(letterSpacing: 1),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in _formats)
                    TintaChip(
                      label: f.label,
                      selected: f == _format,
                      height: 38,
                      onTap: () => setState(() => _format = f),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: TintaColors.studioInk,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  textStyle: TintaType.body(17, weight: FontWeight.w700),
                ),
                child: Text(editing ? 'Save' : 'Create sketchbook'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameCover(CoverDesign a, CoverDesign b) =>
      a.color == b.color &&
      a.band == b.band &&
      a.motif == b.motif &&
      a.motifColor == b.motifColor;
}
