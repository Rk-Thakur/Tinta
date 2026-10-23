import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/logo.dart';
import '../ui/widgets/widgets.dart';

/// Dev-only gallery of the foundations board: tokens, type, components,
/// plus an index of every screen route.
class KitScreen extends StatefulWidget {
  const KitScreen({super.key});

  @override
  State<KitScreen> createState() => _KitScreenState();
}

class _KitScreenState extends State<KitScreen> {
  String _view = 'Grid';
  bool _toggle = true;
  double _slider = 0.62;
  String _tool = 'pencil';
  String _chip = 'Favorites';

  static const _swatches = [
    ('Riso Blue', TintaColors.risoBlue, 'primary ink'),
    ('Fluoro Orange', TintaColors.fluoroOrange, 'accent, fills'),
    ('Studio Ink', TintaColors.studioInk, 'text, studio chrome'),
    ('Newsprint', TintaColors.newsprint, 'app ground'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            TintaSpace.gutter,
            TintaSpace.x4,
            TintaSpace.gutter,
            48,
          ),
          children: [
            const TintaLockup(height: 44),
            const SizedBox(height: 16),
            // The app icon family and the one-color marks.
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (bg, style) in const [
                  (TintaColors.surface, LogoStyle.paper),
                  (TintaColors.studioInk, LogoStyle.studio),
                  (TintaColors.sun, LogoStyle.sun),
                  (TintaColors.studioInk, LogoStyle.small),
                ])
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: TintaColors.line),
                    ),
                    alignment: Alignment.center,
                    child: TintaLogoMark(size: 44, style: style),
                  ),
                const TintaLogoMark(size: 40, style: LogoStyle.oneColor),
                const TintaLogoMark(
                  size: 40,
                  style: LogoStyle.oneColor,
                  color: TintaColors.risoBlue,
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TintaColors.studioInk,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const TintaLockup(height: 32, dark: true),
            ),
            const SizedBox(height: 12),
            Text(
              'The sketchbook that never needs Wi‑Fi.',
              style: TintaType.title22,
            ),
            _section('Color: two inks + paper'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                for (final s in _swatches)
                  _Swatch(name: s.$1, color: s.$2, role: s.$3),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              spacing: 8,
              children: [
                for (final c in const [
                  TintaColors.sun,
                  TintaColors.ink2,
                  TintaColors.line,
                  TintaColors.dock,
                ])
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
            _section('Typography'),
            Text('Aa Draw', style: TintaType.display(56)),
            Text(
              'Bricolage Grotesque 800 · 34 / 28 / 22',
              style: TintaType.mono(12, color: TintaColors.ink2),
            ),
            const SizedBox(height: 10),
            Text(
              'Aa DM Sans',
              style: TintaType.body(30, weight: FontWeight.w500, height: 1.1),
            ),
            Text(
              'DM Sans 400/500/700 · 17 / 15 / 13',
              style: TintaType.mono(12, color: TintaColors.ink2),
            ),
            const SizedBox(height: 10),
            Text('Aa 12px · 64%', style: TintaType.mono(24)),
            const SizedBox(height: 14),
            _Card(
              children: [
                Text('Sketchbooks', style: TintaType.display34),
                Text('Morning studies', style: TintaType.title22),
                Text('Pick up where you left off.', style: TintaType.body17),
                Text('Edited 2h ago · 14 pages', style: TintaType.body13),
              ],
            ),
            _section('Components'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                PillButton(label: 'Start drawing', onPressed: () {}),
                PillButton(
                  label: 'New sketchbook',
                  variant: PillVariant.accent,
                  onPressed: () {},
                ),
                PillButton(
                  label: 'Import',
                  variant: PillVariant.outline,
                  onPressed: () {},
                ),
                TileIconButton(
                  icon: TintaIcons.plus,
                  label: 'Add',
                  size: 52,
                  radius: TintaRadii.md,
                  iconSize: 24,
                  strokeWidth: 2.4,
                  background: TintaColors.risoBlue,
                  foreground: Colors.white,
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const OnDeviceBadge(),
                for (final c in const ['All', 'Favorites'])
                  TintaChip(
                    label: c,
                    selected: _chip == c,
                    onTap: () => setState(() => _chip = c),
                  ),
                const TintaChip(
                  label: 'Daily prompt',
                  selected: true,
                  selectedColor: TintaColors.sun,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SegmentedPills<String>(
                  options: const ['Grid', 'Shelf', 'List'],
                  value: _view,
                  labelOf: (v) => v,
                  onChanged: (v) => setState(() => _view = v),
                ),
                const Spacer(),
                TintaSwitch(
                  value: _toggle,
                  onChanged: (v) => setState(() => _toggle = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TintaSlider(
                    value: _slider,
                    onChanged: (v) => setState(() => _slider = v),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${(_slider * 100).round()}%', style: TintaType.mono(12)),
              ],
            ),
            _section('Floating tool dock'),
            Align(
              alignment: Alignment.centerLeft,
              child: ToolDock<String>(
                tools: const [
                  DockTool(
                    id: 'pencil',
                    icon: TintaIcons.pencil,
                    label: 'Pencil',
                  ),
                  DockTool(id: 'brush', icon: TintaIcons.brush, label: 'Brush'),
                  DockTool(
                    id: 'eraser',
                    icon: TintaIcons.eraser,
                    label: 'Eraser',
                  ),
                  DockTool(id: 'lasso', icon: TintaIcons.lasso, label: 'Lasso'),
                ],
                selected: _tool,
                onSelect: (t) => setState(() => _tool = t),
                trailing: const [
                  ColorDot(
                    color: TintaColors.risoBlue,
                    label: 'Current color',
                    size: 44,
                    selected: true,
                  ),
                ],
              ),
            ),
            _section('Icons: 2px stroke, round caps'),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final i in TintaIcons.values)
                  TintaIcon(i, size: 26, color: TintaColors.studioInk),
              ],
            ),
            _section('Screens'),
            for (final r in Routes.all)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.$2, style: TintaType.body15),
                trailing: const TintaIcon(TintaIcons.arrowRight, size: 18),
                onTap: () => Navigator.of(context).pushNamed(r.$1),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(top: 32, bottom: 14),
    child: SectionLabel(text),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color, required this.role});

  final String name;
  final Color color;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: TintaColors.surface,
        border: Border.all(color: TintaColors.line),
        borderRadius: BorderRadius.circular(TintaRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ColoredBox(color: color)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TintaType.body(
                    14,
                    weight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                Text(
                  '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()} · $role',
                  style: TintaType.mono(10, color: TintaColors.ink2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: TintaColors.surface,
      border: Border.all(color: TintaColors.line),
      borderRadius: BorderRadius.circular(TintaRadii.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in children)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: c),
      ],
    ),
  );
}
