import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Tinta's line icons: 24-unit grid, 2px stroke, round caps and joins.
/// Bodies are copied from the design kit so they match it exactly.
enum TintaIcons {
  pencil('<path d="M4 20l4-1 11-11-3-3L5 16z"/>'),
  brush(
    '<path d="M14 4l6 6-7 7-6-6z"/><path d="M7 11c-3 1-4 4-4 9 5 0 8-1 9-4"/>',
  ),
  marker('<path d="M6 18l3-8h6l3 8zM9 10V4h6v6M4 21h16"/>'),
  eraser('<path d="M8 20h12"/><path d="M4 16l9-9 6 6-6 6H8z"/>'),
  lasso(
    '<ellipse cx="12" cy="9" rx="8" ry="5"/><path d="M7 13c-1 3 1 6 4 5"/>',
  ),
  sliders(
    '<path d="M4 7h10M18 7h2M4 17h2M10 17h10"/><circle cx="16" cy="7" r="2"/><circle cx="8" cy="17" r="2"/>',
  ),
  home('<path d="M3 11l9-7 9 7v9H3z"/>'),
  book(
    '<path d="M5 4h11a3 3 0 013 3v13H8a3 3 0 01-3-3z"/><path d="M5 17a3 3 0 013-3h11"/>',
  ),
  layers('<path d="M12 3l9 5-9 5-9-5z"/><path d="M3 13l9 5 9-5"/>'),
  undo('<path d="M9 7L4 12l5 5"/><path d="M4 12h10a5 5 0 010 10"/>'),
  redo('<path d="M15 7l5 5-5 5"/><path d="M20 12H10a5 5 0 000 10"/>'),
  export('<path d="M12 15V3M7 8l5-5 5 5"/><path d="M5 13v7h14v-7"/>'),
  play('<path d="M7 4l12 8-12 8z"/>'),
  search('<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>'),
  lock(
    '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/>',
  ),
  grid(
    '<rect x="3" y="3" width="18" height="18" rx="3"/><path d="M3 9h18M3 15h18M9 3v18M15 3v18"/>',
  ),
  settings(
    '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M5 19l2-2M17 7l2-2"/>',
  ),
  plus('<path d="M12 5v14M5 12h14"/>'),
  close('<path d="M6 6l12 12M18 6L6 18"/>'),
  back('<path d="M15 6l-6 6 6 6"/>'),
  arrowRight('<path d="M5 12h14M13 6l6 6-6 6"/>'),
  eye(
    '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  ),
  eyeOff(
    '<path d="M3 3l18 18"/><path d="M10.6 5.1A10 10 0 0112 5c6 0 10 7 10 7a17 17 0 01-3.2 3.9M6.6 6.6C3.9 8.3 2 12 2 12s4 7 10 7a9.8 9.8 0 005.4-1.6"/><path d="M9.9 9.9a3 3 0 004.2 4.2"/>',
  ),
  eyedropper('<path d="M14 4l6 6-2 2-6-6zM12 8l-8 8v4h4l8-8"/>'),
  palette(
    '<path d="M12 3a9 9 0 100 18c1.5 0 2-1 2-2s-1-2 0-3 2 0 4 0 3-2 3-4a9 9 0 00-9-9z"/><circle cx="8" cy="10" r="1.2"/><circle cx="12" cy="7" r="1.2"/><circle cx="16" cy="10" r="1.2"/>',
  ),
  clock('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'),
  branch(
    '<circle cx="6" cy="6" r="2"/><circle cx="18" cy="18" r="2"/><path d="M6 8v4a4 4 0 004 4h6"/>',
  ),
  offline(
    '<path d="M3 3l18 18M8 8a5 5 0 00-1 9h10M12 6a5 5 0 015 5 4 4 0 013 5"/>',
  ),
  // Filled glyphs.
  dragHandle(
    '<circle cx="9" cy="6" r="1.5"/><circle cx="15" cy="6" r="1.5"/><circle cx="9" cy="12" r="1.5"/><circle cx="15" cy="12" r="1.5"/><circle cx="9" cy="18" r="1.5"/><circle cx="15" cy="18" r="1.5"/>',
    filled: true,
  ),
  more(
    '<circle cx="5" cy="12" r="1.8"/><circle cx="12" cy="12" r="1.8"/><circle cx="19" cy="12" r="1.8"/>',
    filled: true,
  ),
  pause(
    '<rect x="6" y="5" width="4" height="14" rx="1"/><rect x="14" y="5" width="4" height="14" rx="1"/>',
    filled: true,
  );

  const TintaIcons(this.body, {this.filled = false});
  final String body;
  final bool filled;
}

class TintaIcon extends StatelessWidget {
  const TintaIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth = 2,
    this.semanticLabel,
  });

  final TintaIcons icon;
  final double size;
  final Color? color;
  final double strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final paint = icon.filled
        ? 'fill="currentColor"'
        : 'fill="none" stroke="currentColor" stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round"';
    final svg =
        '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" $paint>${icon.body}</svg>';
    final resolved =
        color ??
        DefaultTextStyle.of(context).style.color ??
        const Color(0xFF17171C);
    final picture = SvgPicture.string(
      svg,
      width: size,
      height: size,
      theme: SvgTheme(currentColor: resolved),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: picture)
        : Semantics(
            label: semanticLabel,
            image: true,
            child: ExcludeSemantics(child: picture),
          );
  }
}
