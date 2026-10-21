import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/library_store.dart';
import '../data/prefs.dart';
import '../data/vault.dart';
import '../services/backup.dart';
import '../services/reminders.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
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
    final prompt = LibraryScope.of(context).dailyPrompt.text;
    final ok = await Reminders.schedule(prefs.reminderTime, prompt: prompt);
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
                Text('Settings', style: TintaType.display28),
              ],
            ),
            const SizedBox(height: 16),
            _VaultCard(
              usage: usage,
              busy: _busy,
              onBackup: _backup,
              onClearExports: (usage?.exports ?? 0) > 0 ? _clearExports : null,
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                style: TintaType.body(13, color: const Color(0xFFB3261E)),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: TintaColors.surface,
                border: Border.all(color: TintaColors.line),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _ToggleRow(
                    title: 'Left‑handed dock',
                    subtitle: 'Brush size rail on the left edge',
                    value: prefs.leftHanded,
                    onChanged: (v) => prefs.leftHanded = v,
                  ),
                  const Divider(height: 1, color: Color(0xFFECEAE4)),
                  _ToggleRow(
                    title: 'Two‑finger tap to undo',
                    value: prefs.twoFingerUndo,
                    onChanged: (v) => prefs.twoFingerUndo = v,
                  ),
                  const Divider(height: 1, color: Color(0xFFECEAE4)),
                  _ToggleRow(
                    title: 'Daily prompt reminder',
                    subtitle: 'A local notification; nothing is sent anywhere',
                    value: prefs.reminder,
                    onChanged: (v) => _setReminder(prefs, v),
                    trailing: TextButton(
                      onPressed: () => _pickTime(prefs),
                      style: TextButton.styleFrom(
                        foregroundColor: TintaColors.ink2,
                        minimumSize: const Size(44, 44),
                      ),
                      child: Text(
                        prefs.reminderTime.format(context),
                        style: TintaType.mono(13, color: TintaColors.ink2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _ProCard(),
          ],
        ),
      ),
    );
  }
}

class _VaultCard extends StatelessWidget {
  const _VaultCard({
    required this.usage,
    required this.busy,
    required this.onBackup,
    required this.onClearExports,
  });

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
        color: TintaColors.studioInk,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'LOCAL VAULT',
                  style: TintaType.label(color: TintaColors.studioSubtle)
                      .copyWith(fontSize: 11),
                ),
              ),
              const TintaIcon(
                TintaIcons.offline,
                size: 14,
                strokeWidth: 2.4,
                color: TintaColors.sun,
              ),
              const SizedBox(width: 6),
              Text(
                'Never leaves this phone',
                style: TintaType.mono(11, color: TintaColors.sun),
              ),
            ],
          ),
          Text(
            u == null ? '—' : formatBytes(total),
            style: TintaType.display(32, color: TintaColors.newsprint),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                spacing: 2,
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
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TintaType.body(
                    15,
                    weight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TintaType.body(
                      12,
                      color: TintaColors.ink2,
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
          Semantics(
            label: title,
            child: TintaSwitch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class _ProCard extends StatelessWidget {
  const _ProCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TintaColors.fluoroOrange,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text('Tinta Pro', style: TintaType.display(24)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              'Unlimited sketchbooks, every brush, layered PSD, replay video and riso separations.',
              style: TintaType.body(14, height: 1.45),
            ),
          ),
          PillButton(
            label: 'Unlock for [YOUR PRICE]/mo',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Tinta Pro'),
                content: const Text(
                  'Purchases aren’t set up in this build, so every Pro feature is already unlocked.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
