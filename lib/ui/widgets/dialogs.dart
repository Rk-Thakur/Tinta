import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../icons.dart';
import 'buttons.dart';

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

/// Tinta's "danger" red: destructive actions only.
const tintaDanger = Color(0xFFB3261E);

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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Grabber(),
            const SizedBox(height: 14),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TintaType.title22,
            ),
            if (subtitle != null) Text(subtitle, style: TintaType.body13),
            const SizedBox(height: 10),
            for (final a in actions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: 52,
                leading: TintaIcon(
                  a.icon,
                  size: 22,
                  color: a.destructive ? tintaDanger : TintaColors.studioInk,
                ),
                title: Text(
                  a.label,
                  style: TintaType.body(
                    16,
                    weight: FontWeight.w500,
                    color: a.destructive ? tintaDanger : null,
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

/// Yes/no confirmation. Returns true on confirm. [destructive] paints the
/// confirm button red and shows a warning badge.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final ok = await _showTintaDialog<bool>(
    context,
    builder: (dialog) => TintaDialog(
      icon: destructive ? TintaIcons.close : TintaIcons.export,
      iconColor: destructive ? tintaDanger : TintaColors.risoBlue,
      title: title,
      body: Text(
        message,
        style: TintaType.body(15, color: TintaColors.ink2, height: 1.45),
      ),
      actions: [
        PillButton(
          label: 'Cancel',
          variant: PillVariant.outline,
          compact: true,
          expand: true,
          onPressed: () => Navigator.pop(dialog, false),
        ),
        _DangerAwareButton(
          label: confirmLabel,
          destructive: destructive,
          onPressed: () => Navigator.pop(dialog, true),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Single-line text prompt (rename). Returns the trimmed text, or null if
/// cancelled. Save is disabled while the field is empty.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String action = 'Save',
  String hint = 'Name',
}) {
  return _showTintaDialog<String>(
    context,
    builder: (_) => _PromptDialog(
      title: title,
      initial: initial,
      action: action,
      hint: hint,
    ),
  );
}

Future<T?> _showTintaDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0x8C17171C),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// The shared dialog card: newsprint, rounded, display title, pill actions.
class TintaDialog extends StatelessWidget {
  const TintaDialog({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
    this.icon,
    this.iconColor,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final TintaIcons? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + keyboard),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Material(
              color: TintaColors.newsprint,
              borderRadius: BorderRadius.circular(TintaRadii.sheet),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon badge and title on one line, centred on each other.
                    Row(
                      spacing: 12,
                      children: [
                        if (icon != null)
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: (iconColor ?? TintaColors.studioInk)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                TintaRadii.sm,
                              ),
                            ),
                            child: Center(
                              child: TintaIcon(
                                icon!,
                                size: 20,
                                strokeWidth: 2.4,
                                color: iconColor ?? TintaColors.studioInk,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              title,
                              style: TintaType.display(24)
                                  .copyWith(height: 1.15),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    body,
                    const SizedBox(height: 20),
                    Row(
                      spacing: 10,
                      children: [for (final a in actions) Expanded(child: a)],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.initial,
    required this.action,
    required this.hint,
  });

  final String title;
  final String initial;
  final String action;
  final String hint;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  // Owned by the dialog and disposed with it, after its closing animation.
  late final TextEditingController _text =
      TextEditingController(text: widget.initial)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initial.length,
        );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _value => _text.text.trim();

  void _submit() {
    if (_value.isEmpty) return;
    Navigator.pop(context, _value);
  }

  @override
  Widget build(BuildContext context) {
    return TintaDialog(
      icon: TintaIcons.pencil,
      title: widget.title,
      body: TextField(
        controller: _text,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
        style: TintaType.body(17),
        cursorColor: TintaColors.risoBlue,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TintaType.body(17, color: TintaColors.studioMuted),
          filled: true,
          fillColor: TintaColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TintaRadii.md),
            borderSide: BorderSide(color: TintaColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TintaRadii.md),
            borderSide: BorderSide(color: TintaColors.studioInk, width: 2),
          ),
          suffixIcon: _text.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: () => setState(_text.clear),
                  icon: TintaIcon(
                    TintaIcons.close,
                    size: 16,
                    color: TintaColors.ink2,
                  ),
                ),
        ),
      ),
      actions: [
        PillButton(
          label: 'Cancel',
          variant: PillVariant.outline,
          compact: true,
          expand: true,
          onPressed: () => Navigator.pop(context),
        ),
        PillButton(
          label: widget.action,
          compact: true,
          expand: true,
          onPressed: _value.isEmpty ? null : _submit,
        ),
      ],
    );
  }
}

class _DangerAwareButton extends StatelessWidget {
  const _DangerAwareButton({
    required this.label,
    required this.destructive,
    required this.onPressed,
  });

  final String label;
  final bool destructive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!destructive) {
      return PillButton(
        label: label,
        compact: true,
        expand: true,
        onPressed: onPressed,
      );
    }
    return SizedBox(
      height: 40,
      child: Material(
        color: tintaDanger,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: TintaType.body(
                14,
                weight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 5,
      decoration: BoxDecoration(
        color: TintaColors.studioMuted,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}
