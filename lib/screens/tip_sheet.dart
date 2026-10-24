import 'dart:io';

import 'package:flutter/material.dart';

import '../services/tips.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/widgets/dialogs.dart';
import '../ui/widgets/widgets.dart';

/// "Buy me a coffee": three tip sizes, paid through the store.
Future<void> showTipSheet(BuildContext context) {
  final jar = TipJarScope.of(context)..reset();
  if (jar.state != TipJarState.ready) jar.load();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const TipSheet(),
  );
}

class TipSheet extends StatelessWidget {
  const TipSheet({super.key});

  static String get _storeName =>
      Platform.isIOS || Platform.isMacOS ? 'the App Store' : 'Google Play';

  @override
  Widget build(BuildContext context) {
    final jar = TipJarScope.of(context);
    final thanked = jar.state == TipJarState.thanked;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                    thanked ? 'Thank you!' : 'Buy me a coffee',
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
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: thanked
                  ? const _Thanks(key: ValueKey('thanks'))
                  : _Choices(key: const ValueKey('choices'), jar: jar),
            ),
            if (!thanked) ...[
              const SizedBox(height: 14),
              Text(
                'One-time tip through $_storeName. Nothing to unlock, just thanks.',
                textAlign: TextAlign.center,
                style: TintaType.mono(11, color: TintaColors.ink2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({super.key, required this.jar});

  final TipJar jar;

  @override
  Widget build(BuildContext context) {
    final state = jar.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tinta has no ads, no account and no subscription. If it’s earned '
          'a spot on your phone, a coffee helps keep it that way.',
          style: TintaType.body(15, color: TintaColors.ink2),
        ),
        const SizedBox(height: 18),
        if (state == TipJarState.unavailable)
          _Unavailable(onRetry: jar.load)
        else
          Row(
            spacing: 10,
            children: [
              for (final tip in Tip.values)
                Expanded(
                  child: _TipTile(tip: tip, jar: jar),
                ),
            ],
          ),
        if (jar.error != null) ...[
          const SizedBox(height: 12),
          Text(
            jar.error!,
            textAlign: TextAlign.center,
            style: TintaType.body(13, color: tintaDanger),
          ),
        ],
      ],
    );
  }
}

class _TipTile extends StatelessWidget {
  const _TipTile({required this.tip, required this.jar});

  final Tip tip;
  final TipJar jar;

  @override
  Widget build(BuildContext context) {
    TipOffer? offer;
    for (final o in jar.offers) {
      if (o.tip == tip) offer = o;
    }
    final buying = jar.state == TipJarState.buying;
    final thisOne = buying && jar.buying == tip;
    final enabled = offer != null && !buying;
    return Semantics(
      button: true,
      enabled: enabled,
      label: offer == null
          ? '${tip.label}, loading price'
          : '${tip.label}, ${offer.price}',
      excludeSemantics: true,
      child: Opacity(
        opacity: buying && !thisOne ? 0.45 : 1,
        child: Material(
          color: TintaColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TintaRadii.md),
            side: BorderSide(
              color: thisOne ? TintaColors.risoBlue : TintaColors.line,
              width: thisOne ? 3 : 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? () => jar.buy(offer!) : null,
            child: SizedBox(
              height: 128,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
                child: Column(
                  children: [
                    SizedBox(
                      height: 26,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < tip.cups; i++)
                            TintaIcon(
                              TintaIcons.coffee,
                              size: 22,
                              strokeWidth: 2,
                              color: TintaColors.studioInk,
                            ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      tip.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TintaType.body(13, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 26,
                      child: Center(
                        child: offer == null || thisOne
                            ? SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: TintaColors.ink2,
                                ),
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  offer.price,
                                  style: TintaType.display(22),
                                ),
                              ),
                      ),
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

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: TintaColors.surface,
        border: Border.all(color: TintaColors.line),
        borderRadius: BorderRadius.circular(TintaRadii.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tips aren’t available right now',
                  style: TintaType.body(15, weight: FontWeight.w600),
                ),
                Text(
                  'The store can’t be reached. Check your connection and '
                  'try again.',
                  style: TintaType.body(13, color: TintaColors.ink2),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: TintaColors.risoBlue,
              minimumSize: const Size(44, 44),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _Thanks extends StatelessWidget {
  const _Thanks({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: TintaColors.sun,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: TintaIcon(
              TintaIcons.coffee,
              size: 44,
              strokeWidth: 2,
              color: TintaInk.studioInk,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'That means a lot. Your coffee keeps tinta offline and ad‑free.',
          textAlign: TextAlign.center,
          style: TintaType.body(15, color: TintaColors.ink2),
        ),
        const SizedBox(height: 18),
        PillButton(
          label: 'Back to drawing',
          variant: PillVariant.ink,
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
