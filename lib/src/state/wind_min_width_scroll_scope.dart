import 'package:flutter/widgets.dart';

import '../widgets/wind_min_width_scroll.dart';

/// Threads a scrollable parent's axis information down to its content, since a
/// scrollable `WDiv` cannot inspect a descendant's `className` directly.
///
/// A `WDiv` with a scrollable axis installs this scope for its scroll content:
///
/// - `overflow-x-auto` / `overflow-x-scroll` sets [horizontalPort] so a `w-full`
///   descendant sizes to `max(viewport, min-w-*)` (fill on desktop, scroll on
///   narrow) instead of asserting on the scroll's unbounded width.
/// - `overflow-y-auto` / `overflow-y-scroll` sets [verticalUnbounded] so a
///   descendant that resolves `h-full` can raise an actionable assert pointing
///   at `flex-1`. The flag only says a vertical scroll is above: the assert
///   itself fires in `WindFullHeightBox.performLayout`, and only when the
///   height that box is actually offered is unbounded, since a fixed-height
///   ancestor in between leaves `h-full` something to fill.
class WindMinWidthScrollScope extends InheritedWidget {
  /// Shared carrier for the horizontal viewport width; non-null only inside a
  /// horizontally scrollable parent.
  final WindViewportWidthPort? horizontalPort;

  /// Whether the nearest scrollable parent leaves the vertical axis unbounded
  /// (a vertical scroll), so `h-full` on a child is a layout error.
  final bool verticalUnbounded;

  const WindMinWidthScrollScope({
    super.key,
    this.horizontalPort,
    this.verticalUnbounded = false,
    required super.child,
  });

  /// Returns the nearest [WindMinWidthScrollScope] and subscribes so dependents
  /// rebuild when the axis information changes.
  static WindMinWidthScrollScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<WindMinWidthScrollScope>();
  }

  @override
  bool updateShouldNotify(WindMinWidthScrollScope oldWidget) {
    return oldWidget.horizontalPort != horizontalPort ||
        oldWidget.verticalUnbounded != verticalUnbounded;
  }
}
