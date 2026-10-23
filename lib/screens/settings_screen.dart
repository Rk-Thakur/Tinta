import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/library_store.dart';
import '../data/prefs.dart';
import '../data/studio_store.dart';
import '../data/vault.dart';
import '../services/backup.dart';
import '../services/reminders.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/format.dart';
import '../ui/widgets/dialogs.dart';
import '../ui/widgets/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  VaultUsage? _usage;
  bool _busy = false;
  String? _message;
  bool _messageOk = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  Future<void> _refresh() async {
    final vault = LibraryScope.of(context).vault;
    if (vault == null) return;
    final usage = await vault.usage();
    if (mounted) setState(() => _usage = usage);
  }

  Future<void> _backup(BuildContext buttonContext) async {
    final store = LibraryScope.of(context);
    final vault = store.vault;
    if (vault == null) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _busy = true;
      _message = null;
      _messageOk = false;
    });
    try {
      final file = await Backup.create(vault, store);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], sharePositionOrigin: origin),
      );
    } catch (e) {
      if (mounted) setState(() => _message = 'Backup failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      _refresh();
    }
  }

  Future<void> _restore() async {
    final library = LibraryScope.of(context);
    final studio = StudioScope.of(context);
    final vault = library.vault;
    if (vault == null) return;
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Choose a Tinta backup',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    final path = picked?.path;
    if (path == null || !mounted) return;
    final ok = await confirmAction(
      context,
      title: 'Restore this backup?',
      message:
          'Sketchbooks, pages, palettes and brushes on this device are replaced by the backup. '
          'What’s here now is saved to a safety backup in exported files first.',
      confirmLabel: 'Restore',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
      _messageOk = false;
    });
    try {
      final r = await Backup.restore(File(path), vault, library, studio);
      if (mounted) {
        setState(() {
          _message =
              'Restored ${plural(r.sketchbooks, 'sketchbook')} and ${plural(r.pages, 'page')}.';
          _messageOk = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Restore failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      _refresh();
    }
  }

  Future<void> _clearExports() async {
    await LibraryScope.of(context).vault?.clearExports();
    _refresh();
  }

  Future<void> _setReminder(AppPrefs prefs, bool on) async {
    if (!on) {
      prefs.reminder = false;
      await Reminders.cancel();
      return;
    }
    final ok = await Reminders.schedule(prefs.reminderTime);
    prefs.reminder = ok;
    if (!ok && mounted) {
      setState(
        () => _message = 'Notifications are off for Tinta. Turn them on in system Settings to get the reminder.',
      );
    }
  }

  Future<void> _pickTime(AppPrefs prefs) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: prefs.reminderTime,
    );
    if (picked == null || !mounted) return;
    prefs.reminderTime = picked;
    if (prefs.reminder) await _setReminder(prefs, true);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = PrefsScope.of(context);
    final usage = _usage;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              spacing: 10,
              children: [
                TileIconButton(
                  icon: TintaIcons.back,
                  label: 'Back to library',
                  background: TintaColors.surface,
                  foreground: TintaColors.studioInk,
                  borderColor: TintaColors.line,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(child: Text('Settings', style: TintaType.display28)),
                const OnDeviceBadge(text: 'Offline'),
              ],
            ),
            const SizedBox(height: 24),
            _Heading(
              'Theme',
              trailing: switch (prefs.theme) {
                ThemeChoice.light => 'Newsprint',
                ThemeChoice.dark => 'Studio ink',
                ThemeChoice.system => 'Matches your phone',
              },
            ),
            Row(
              spacing: 10,
              children: [
                for (final t in ThemeChoice.values)
                  Expanded(
                    child: _ThemeTile(
                      theme: t,
                      selected: prefs.theme == t,
                      onTap: () => prefs.theme = t,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            const _Heading('Ink pair · tints the whole app'),
            Row(
              spacing: 10,
              children: [
                for (final pair in InkPair.values)
                  Expanded(
                    child: _InkPairTile(
                      pair: pair,
                      selected: prefs.inkPair == pair,
                      onTap: () => prefs.inkPair = pair,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                color: TintaColors.surface,
                border: Border.all(color: TintaColors.line),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _ToggleRow(
                    title: 'Pencil sounds',
                    subtitle: const Text('Soft paper scratch while you draw'),
                    value: prefs.pencilSounds,
                    onChanged: (v) => prefs.pencilSounds = v,
                  ),
                  Divider(height: 1, color: TintaColors.hairline),
                  _ToggleRow(
                    title: 'Left‑handed dock',
                    subtitle: const Text(
                      'Size rail and inks move to the left edge',
                    ),
                    value: prefs.leftHanded,
                    onChanged: (v) => prefs.leftHanded = v,
                  ),
                  Divider(height: 1, color: TintaColors.hairline),
                  _ToggleRow(
                    title: 'Two‑finger tap to undo',
                    subtitle: const Text('Three fingers to redo'),
                    value: prefs.twoFingerUndo,
                    onChanged: (v) => prefs.twoFingerUndo = v,
                  ),
                  Divider(height: 1, color: TintaColors.hairline),
                  _ToggleRow(
                    title: 'Daily prompt',
                    subtitle: Semantics(
                      button: true,
                      label:
                          'Reminder time, ${prefs.reminderTime.format(context)}. Tap to change.',
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _pickTime(prefs),
                        child: Text.rich(
                          TextSpan(
                            text: 'A 3-minute idea at ',
                            children: [
                              TextSpan(
                                text: prefs.reminderTime.format(context),
                                style: TextStyle(
                                  color: TintaColors.risoBlue,
                                  fontWeight: FontWeight.w600,
                                  fontVariations: const [
                                    FontVariation('wght', 600),
                                  ],
                                  decoration: TextDecoration.underline,
                                  decorationColor: TintaColors.risoBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    value: prefs.reminder,
                    onChanged: (v) => _setReminder(prefs, v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _Heading('Your library · on this device'),
            _VaultCard(
              usage: usage,
              busy: _busy,
              onBackup: _backup,
              onRestore: _restore,
              onClearExports: (usage?.exports ?? 0) > 0 ? _clearExports : null,
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TintaType.body(
                  13,
                  weight: _messageOk ? FontWeight.w700 : FontWeight.w400,
                  color: _messageOk ? TintaColors.studioInk : tintaDanger,
                ),
              ),
            ],
            const SizedBox(height: 36),
            Center(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'tinta'),
                    TextSpan(
                      text: '.',
                      style: TextStyle(color: TintaColors.fluoroOrange),
                    ),
                    const TextSpan(
                      text: ' v$appVersion · made for drawing anywhere',
                    ),
                  ],
                ),
                style: TintaType.mono(12, color: TintaColors.ink2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown in the Settings footer (pubspec version, major.minor).
const appVersion = '1.0';

/// Mono section label with an optional value on the right.
class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: SectionLabel(text)),
          if (trailing != null)
            Text(trailing!, style: TintaType.body(14, color: TintaColors.ink2)),
        ],
      ),
    );
  }
}

/// A choice tile: surface card, accent ring when selected.
class _ChoiceFrame extends StatelessWidget {
  const _ChoiceFrame({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(8),
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: padding,
          decoration: BoxDecoration(
            color: TintaColors.surface,
            borderRadius: BorderRadius.circular(TintaRadii.md),
            border: Border.all(
              color: selected ? TintaColors.risoBlue : TintaColors.line,
              width: selected ? 3 : 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final ThemeChoice theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (theme) {
      ThemeChoice.light => 'Light',
      ThemeChoice.dark => 'Dark',
      ThemeChoice.system => 'System',
    };
    return _ChoiceFrame(
      label: '$label theme',
      selected: selected,
      onTap: onTap,
      padding: EdgeInsets.all(selected ? 6.5 : 8),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.3,
            child: Container(
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TintaRadii.xs + 2),
                border: Border.all(color: TintaColors.line),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(TintaRadii.xs + 2),
                child: CustomPaint(painter: _ThemePreviewPainter(theme)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TintaType.body(15, weight: FontWeight.w600, height: 1.2),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

/// A tiny screen: title bar, a sun card and the dock with its orange dot.
class _ThemePreviewPainter extends CustomPainter {
  _ThemePreviewPainter(this.theme);

  final ThemeChoice theme;

  @override
  void paint(Canvas canvas, Size size) {
    const paper = Color(0xFFEFECE5);
    const night = TintaInk.studioInk;
    final w = size.width, h = size.height;
    final dark = theme == ThemeChoice.dark;
    canvas.drawRect(Offset.zero & size, Paint()..color = dark ? night : paper);
    if (theme == ThemeChoice.system) {
      // Light above the diagonal, dark below it.
      canvas.drawPath(
        Path()
          ..moveTo(w, h * 0.05)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close(),
        Paint()..color = night,
      );
    }
    RRect bar(double l, double t, double bw, double bh) => RRect.fromLTRBR(
      w * l,
      h * t,
      w * (l + bw),
      h * (t + bh),
      Radius.circular(h * bh / 2),
    );
    final titleColor = switch (theme) {
      ThemeChoice.light => night,
      ThemeChoice.dark => TintaInk.newsprint,
      ThemeChoice.system => const Color(0xFF55555E),
    };
    canvas.drawRRect(bar(0.1, 0.12, 0.36, 0.08), Paint()..color = titleColor);
    canvas.drawRRect(
      RRect.fromLTRBR(
        w * 0.1,
        h * 0.32,
        w * 0.9,
        h * 0.58,
        Radius.circular(h * 0.07),
      ),
      Paint()..color = TintaInk.sun,
    );
    final dockColor = theme == ThemeChoice.light
        ? night
        : const Color(0xFF3A3A42);
    canvas.drawRRect(bar(0.3, 0.72, 0.4, 0.14), Paint()..color = dockColor);
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.79),
      h * 0.035,
      Paint()..color = TintaInk.fluoroOrange,
    );
  }

  @override
  bool shouldRepaint(_ThemePreviewPainter old) => old.theme != theme;
}

class _InkPairTile extends StatelessWidget {
  const _InkPairTile({
    required this.pair,
    required this.selected,
    required this.onTap,
  });

  final InkPair pair;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ChoiceFrame(
      label: '${pair.label} ink pair',
      selected: selected,
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: selected ? 51 : 54,
        child: Center(
          child: CustomPaint(
            size: const Size(40, 26),
            // The inks as they print in the current theme.
            painter: _OverprintPainter(
              TintaColors.isDark ? pair.primaryOnDark : pair.primary,
              pair.secondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Two ink dots overprinting (multiply), as on the riso drum.
class _OverprintPainter extends CustomPainter {
  _OverprintPainter(this.a, this.b);

  final Color a;
  final Color b;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawCircle(Offset(r, r), r, Paint()..color = a);
    canvas.drawCircle(
      Offset(size.width - r, r),
      r,
      Paint()
        ..color = b
        ..blendMode = BlendMode.multiply,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OverprintPainter old) => old.a != a || old.b != b;
}

class _VaultCard extends StatelessWidget {
  const _VaultCard({
    required this.usage,
    required this.busy,
    required this.onBackup,
    required this.onRestore,
    required this.onClearExports,
  });

  final VoidCallback onRestore;

  final VaultUsage? usage;
  final bool busy;
  final void Function(BuildContext) onBackup;
  final VoidCallback? onClearExports;

  @override
  Widget build(BuildContext context) {
    final u = usage;
    final total = u?.total ?? 0;
    final parts = <(Color, String, int)>[
      (TintaColors.risoBlue, 'Pages', u?.pages ?? 0),
      (TintaColors.fluoroOrange, 'Exports', u?.exports ?? 0),
      (TintaColors.sun, 'Brushes & palettes', u?.studio ?? 0),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        // A dark studio card in both themes, lifted off the dark ground.
        color: TintaColors.isDark ? TintaColors.dock : TintaInk.studioInk,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              Text(
                'LOCAL VAULT',
                style: TintaType.label(color: TintaColors.studioSubtle)
                    .copyWith(fontSize: 11),
              ),
              const SizedBox(width: 12),
              // Shrinks (with an ellipsis) on narrow phones and large text.
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const TintaIcon(
                      TintaIcons.offline,
                      size: 14,
                      strokeWidth: 2.4,
                      color: TintaColors.sun,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Never leaves this phone',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TintaType.mono(11, color: TintaColors.sun),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            u == null ? '—' : formatBytes(total),
            style: TintaType.display(32, color: TintaInk.newsprint),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                spacing: 2,
                // Stretch: childless ColoredBoxes otherwise collapse to 0 height.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (color, _, bytes) in parts)
                    if (bytes > 0)
                      Expanded(
                        flex: (bytes * 1000 ~/ (total == 0 ? 1 : total)) + 1,
                        child: ColoredBox(color: color),
                      ),
                  if (total == 0)
                    const Expanded(
                      child: ColoredBox(color: TintaColors.dockRaised),
                    ),
                ],
              ),
            ),
          ),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final (color, label, bytes) in parts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      '$label ${formatBytes(bytes)}',
                      style: TintaType.body(
                        12,
                        color: TintaColors.studioSubtle,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (u?.freeBytes != null)
            Text(
              '${formatBytes(u!.freeBytes!)} free on this device',
              style: TintaType.mono(11, color: TintaColors.studioMuted),
            ),
          Builder(
            builder: (b) => SizedBox(
              height: 48,
              child: PillButton(
                label: busy ? 'Packing backup…' : 'Back up to a file',
                variant: PillVariant.light,
                expand: true,
                onPressed: busy || u == null ? null : () => onBackup(b),
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: busy || u == null ? null : onRestore,
              style: TextButton.styleFrom(
                foregroundColor: TintaInk.newsprint,
                minimumSize: const Size(44, 44),
              ),
              child: const Text('Restore from a backup'),
            ),
          ),
          if (onClearExports != null)
            Center(
              child: TextButton(
                onPressed: onClearExports,
                style: TextButton.styleFrom(
                  foregroundColor: TintaColors.fluoroOrange,
                  minimumSize: const Size(44, 44),
                ),
                child: const Text('Clear exported files'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TintaType.body(
                    16,
                    weight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                if (subtitle != null)
                  DefaultTextStyle.merge(
                    style: TintaType.body(
                      13,
                      color: TintaColors.ink2,
                      height: 1.35,
                    ),
                    child: subtitle!,
                  ),
              ],
            ),
          ),
          Semantics(
            label: title,
            child: TintaSwitch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
