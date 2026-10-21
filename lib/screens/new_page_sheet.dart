import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/routes.dart';
import '../data/library_store.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/widgets/paper.dart';
import '../ui/widgets/widgets.dart';

/// Bottom sheet: pick paper, size and riso mode, then open the new page.
class NewPageSheet extends StatefulWidget {
  const NewPageSheet({super.key, this.bookId});

  /// Sketchbook to add the page to; null makes a loose page.
  final String? bookId;

  @override
  State<NewPageSheet> createState() => _NewPageSheetState();
}

class _NewPageSheetState extends State<NewPageSheet> {
  PaperType _paper = PaperType.smooth;
  PageFormat _format = PageFormat.screen;
  bool _riso = true;
  final _customW = TextEditingController(text: '1080');
  final _customH = TextEditingController(text: '1350');
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    // A new page in a sketchbook defaults to that book's paper and size.
    final book = widget.bookId == null
        ? null
        : LibraryScope.of(context).sketchbook(widget.bookId!);
    if (book != null) {
      _paper = book.paper;
      _format = book.format;
    }
  }

  @override
  void dispose() {
    _customW.dispose();
    _customH.dispose();
    super.dispose();
  }

  double _aspect(BuildContext context) {
    switch (_format) {
      case PageFormat.screen:
        // Match the page area of the studio canvas on this device.
        final size = MediaQuery.sizeOf(context);
        final padding = MediaQuery.paddingOf(context);
        final h = size.height - padding.vertical - 64 - 162;
        return (h / (size.width - 40)).clamp(1.0, 2.4);
      case PageFormat.custom:
        final w = double.tryParse(_customW.text) ?? 0;
        final h = double.tryParse(_customH.text) ?? 0;
        if (w <= 0 || h <= 0) return 1;
        return (h / w).clamp(0.25, 4.0);
      default:
        return _format.aspect!;
    }
  }

  void _create() {
    final store = LibraryScope.of(context);
    final page = store.addPage(
      SketchPage(
        id: '',
        number: 0,
        paper: _paper,
        aspect: _aspect(context),
        riso: _riso,
      ),
      bookId: widget.bookId,
    );
    Navigator.of(context).pushReplacementNamed(
      Routes.canvas,
      arguments: CanvasArgs.page(page, bookId: widget.bookId),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                Expanded(child: Text('New page', style: TintaType.display28)),
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
            const SizedBox(height: 18),
            Text(
              'PAPER',
              style: TintaType.mono(
                11,
                color: TintaColors.ink2,
              ).copyWith(letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 116,
              children: [
                for (final p in PaperType.values)
                  _PaperOption(
                    paper: p,
                    selected: p == _paper,
                    onTap: () => setState(() => _paper = p),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'SIZE',
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
                for (final f in PageFormat.values)
                  _SizeChip(
                    label: f.label,
                    selected: f == _format,
                    onTap: () => setState(() => _format = f),
                  ),
              ],
            ),
            if (_format == PageFormat.custom) ...[
              const SizedBox(height: 12),
              Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: _PxField(controller: _customW, label: 'Width'),
                  ),
                  Text('×', style: TintaType.body(17, color: TintaColors.ink2)),
                  Expanded(
                    child: _PxField(controller: _customH, label: 'Height'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            _RisoCard(
              value: _riso,
              onChanged: (v) => setState(() => _riso = v),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _create,
                style: FilledButton.styleFrom(
                  backgroundColor: TintaColors.studioInk,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  textStyle: TintaType.body(17, weight: FontWeight.w700),
                ),
                child: const Text('Create page'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperOption extends StatelessWidget {
  const _PaperOption({
    required this.paper,
    required this.selected,
    required this.onTap,
  });

  final PaperType paper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${paper.label} paper',
      excludeSemantics: true,
      child: Material(
        color: TintaColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TintaRadii.md),
          side: BorderSide(
            color: selected ? TintaColors.risoBlue : TintaColors.line,
            width: selected ? 3 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 72,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: paper == PaperType.smooth
                        ? Border.all(color: const Color(0xFFECEAE4))
                        : null,
                  ),
                  child: PaperSurface(paper: paper),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    paper.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TintaType.body(
                      13,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? TintaColors.studioInk : TintaColors.surface,
        shape: StadiumBorder(
          side: selected
              ? BorderSide.none
              : const BorderSide(color: TintaColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TintaType.body(
                  14,
                  weight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? Colors.white : TintaColors.studioInk,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PxField extends StatelessWidget {
  const _PxField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5),
      ],
      style: TintaType.mono(15),
      decoration: InputDecoration(
        labelText: '$label (px)',
        labelStyle: TintaType.body(13, color: TintaColors.ink2),
        filled: true,
        fillColor: TintaColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TintaRadii.sm),
          borderSide: const BorderSide(color: TintaColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TintaRadii.sm),
          borderSide: const BorderSide(color: TintaColors.line),
        ),
      ),
    );
  }
}

class _RisoCard extends StatelessWidget {
  const _RisoCard({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: 'Riso mode. Limit to two inks that overprint.',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: TintaColors.surface,
            border: Border.all(color: TintaColors.line),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            spacing: 12,
            children: [
              const SizedBox(
                width: 42,
                height: 26,
                child: Stack(
                  children: [
                    Positioned(left: 0, child: _InkDot(TintaColors.risoBlue)),
                    Positioned(
                      left: 16,
                      child: _InkDot(TintaColors.fluoroOrange, multiply: true),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Riso mode',
                      style: TintaType.body(
                        15,
                        weight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    Text(
                      'Limit to two inks that overprint.',
                      style: TintaType.body13,
                    ),
                  ],
                ),
              ),
              TintaSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _InkDot extends StatelessWidget {
  const _InkDot(this.color, {this.multiply = false});

  final Color color;
  final bool multiply;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(26),
    painter: _DotPainter(color, multiply),
  );
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.color, this.multiply);

  final Color color;
  final bool multiply;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawCircle(
    size.center(Offset.zero),
    size.width / 2,
    Paint()
      ..color = color
      ..blendMode = multiply ? BlendMode.multiply : BlendMode.srcOver,
  );

  @override
  bool shouldRepaint(_DotPainter old) => old.color != color;
}
