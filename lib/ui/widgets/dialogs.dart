import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../icons.dart';

class SheetAction {
  const SheetAction(
    this.label,
    this.icon,
    this.onTap, {
    this.destructive = false,
  });

  final String label;
  final TintaIcons icon;
  final VoidCallback onTap;
  final bool destructive;
}

const _danger = Color(0xFFB3261E);

/// A light bottom sheet with a title and a list of actions.
Future<void> showActionSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<SheetAction> actions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TintaType.title22,
            ),
            if (subtitle != null) Text(subtitle, style: TintaType.body13),
            const SizedBox(height: 12),
            for (final a in actions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: 52,
                leading: TintaIcon(
                  a.icon,
                  size: 22,
                  color: a.destructive ? _danger : TintaColors.studioInk,
                ),
                title: Text(
                  a.label,
                  style: TintaType.body(
                    16,
                    weight: FontWeight.w500,
                    color: a.destructive ? _danger : null,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheet);
                  a.onTap();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

/// Yes/no confirmation for destructive actions. Returns true on confirm.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, true),
          style: TextButton.styleFrom(foregroundColor: _danger),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Single-line text prompt (rename). Returns the trimmed text, or null.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String action = 'Save',
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (v) => Navigator.pop(dialog, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, controller.text),
          child: Text(action),
        ),
      ],
    ),
  );
  controller.dispose();
  final trimmed = result?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
