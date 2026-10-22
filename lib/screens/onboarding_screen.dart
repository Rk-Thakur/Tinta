import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../data/library_store.dart';
import '../data/models.dart';
import '../data/prefs.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../ui/art.dart';
import '../ui/widgets/paper.dart';
import '../ui/widgets/widgets.dart';

class _Slide {
  const _Slide({
    required this.badge,
    this.badgeIcon = TintaIcons.offline,
    required this.title,
    required this.body,
    required this.art,
    this.keywords = const ['No sign‑up', 'Works offline', 'Private by default'],
  });
  final String badge;

  /// The pill keywords under the copy.
  final List<String> keywords;
  final TintaIcons badgeIcon;
  final String title;
  final String body;
  final Artwork art;
}

// Slide 1 is the design's; 2 and 3 carry the remaining two design principles.
const _slides = [
  _Slide(
    badge: 'Airplane mode: fine',
    title: 'Draw anywhere.\nEven at 30,000 ft.',
    body: 'Every stroke lives on your phone. No account, no cloud, nothing to load.',
    keywords: ['Two‑ink riso', 'Every stroke replays', 'Real paper grain'],
    art: Artwork(Size(342, 340), [
      ArtCircle(140, 150, 96, fill: TintaColors.risoBlue, opacity: 0.9),
      ArtCircle(
        214,
        190,
        86,
        fill: TintaColors.fluoroOrange,
        opacity: 0.85,
        multiply: true,
      ),
      ArtRect(40, 250, 110, 34, rx: 17, fill: TintaColors.sun),
      ArtPath(
        'M30 80c40-30 70 10 100-10s60-40 90-10 50 30 90 0',
        stroke: TintaColors.studioInk,
        strokeWidth: 3,
      ),
      ArtPath(
        'M180 280l18-50 70-70 18 18-70 70z',
        fill: TintaColors.newsprint,
        stroke: TintaColors.studioInk,
        strokeWidth: 3,
      ),
      ArtPath('M180 280l18-50 12 12z', fill: TintaColors.studioInk),
    ]),
  ),
  _Slide(
    badge: 'Six papers',
    badgeIcon: TintaIcons.layers,
    title: 'Paper,\nnot pixels.',
    body: 'Sketchbooks look like real books. Pages have tooth, tone and grain.',
    art: Artwork(Size(342, 340), [
      ArtRect(
        56,
        70,
        150,
        200,
        rx: 8,
        fill: TintaColors.paperToned,
        stroke: TintaColors.studioInk,
        strokeWidth: 3,
      ),
      ArtRect(
        136,
        100,
        150,
        200,
        rx: 8,
        fill: TintaColors.paperKraft,
        stroke: TintaColors.studioInk,
        strokeWidth: 3,
      ),
      ArtPath(
        'M160 240c30-40 60-40 100-10',
        stroke: TintaColors.risoBlue,
        strokeWidth: 8,
      ),
      ArtCircle(
        230,
        160,
        26,
        fill: TintaColors.fluoroOrange,
        opacity: 0.9,
        multiply: true,
      ),
    ]),
  ),
  _Slide(
    badge: 'One floating dock',
    badgeIcon: TintaIcons.sliders,
    title: 'Studio mode.\nThumb first.',
    body:
        'Dark chrome around the page and every tool within reach of one hand.',
    art: Artwork(Size(342, 340), [
      ArtRect(0, 0, 342, 340, fill: TintaColors.studioInk),
      ArtRect(70, 40, 202, 200, rx: 6, fill: TintaColors.paperSmooth),
      ArtCircle(171, 120, 40, stroke: TintaColors.studioInk, strokeWidth: 3),
      ArtPath(
        'M100 210c50-10 100-10 140 0',
        stroke: TintaColors.risoBlue,
        strokeWidth: 10,
      ),
      ArtRect(60, 264, 222, 52, rx: 26, fill: TintaColors.dock),
      ArtRect(70, 272, 36, 36, rx: 14, fill: TintaColors.newsprint),
      ArtCircle(
        260,
        290,
        13,
        fill: TintaColors.risoBlue,
        stroke: TintaColors.newsprint,
        strokeWidth: 3,
      ),
    ]),
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pager = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  /// Skip: straight to the (possibly empty) library.
  void _finish() {
    PrefsScope.of(context).onboarded = true;
    Navigator.of(context).pushReplacementNamed(Routes.library);
  }

  /// "Open my first sketchbook": make one if there isn't any, then open it.
  void _openFirstBook() {
    final store = LibraryScope.of(context);
    final book = store.sketchbooks.isNotEmpty
        ? store.sketchbooks.first
        : store.createSketchbook(
            title: 'My first sketchbook',
            cover: coverPresets.first,
            paper: PaperType.toned,
            format: PageFormat.a5,
          );
    PrefsScope.of(context).onboarded = true;
    final nav = Navigator.of(context);
    nav.pushReplacementNamed(Routes.library);
    nav.pushNamed(Routes.sketchbook, arguments: book.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
              child: Row(
                children: [
                  GestureDetector(
                    // Debug-only door into the component kit.
                    onLongPress: kDebugMode
                        ? () => Navigator.of(context).pushNamed(Routes.kit)
                        : null,
                    child: Text.rich(
                      TextSpan(
                        text: 'tinta',
                        style: TintaType.display(26),
                        children: const [
                          TextSpan(
                            text: '.',
                            style: TextStyle(color: TintaColors.fluoroOrange),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: TintaColors.ink2,
                      minimumSize: const Size(44, 44),
                      textStyle: TintaType.body(15),
                    ),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pager,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Dots(count: _slides.length, index: _index),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: _openFirstBook,
                      style: FilledButton.styleFrom(
                        backgroundColor: TintaColors.studioInk,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        textStyle: TintaType.body(17, weight: FontWeight.w700),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'Open my first sketchbook',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 10),
                          TintaIcon(
                            TintaIcons.arrowRight,
                            size: 20,
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 340,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: TintaColors.surface,
              border: Border.all(color: TintaColors.line),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: ArtView(slide.art, fit: BoxFit.cover)),
                Positioned(
                  left: 16,
                  top: 16,
                  child: OnDeviceBadge(
                    text: slide.badge,
                    icon: slide.badgeIcon,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            slide.title,
            style: TintaType.display(38).copyWith(height: 1.02),
          ),
          const SizedBox(height: 12),
          Text(
            slide.body,
            style: TintaType.body(16, color: TintaColors.ink2, height: 1.5),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final k in slide.keywords) _Promise(k)],
          ),
        ],
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      border: Border.all(color: TintaColors.studioInk),
      borderRadius: BorderRadius.circular(TintaRadii.pill),
    ),
    child: Center(
      widthFactor: 1,
      child: Text(
        text,
        style: TintaType.body(13, weight: FontWeight.w500, height: 1),
      ),
    ),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${index + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 6,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == index ? 24 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index
                    ? TintaColors.studioInk
                    : TintaColors.studioMuted,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
