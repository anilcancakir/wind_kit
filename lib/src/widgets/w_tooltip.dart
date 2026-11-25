import 'package:flutter/widgets.dart';

import 'w_div.dart';
import 'w_popover.dart';
import 'w_text.dart';

/// **The Utility-First Tooltip**
///
/// A Material-free tooltip built on [RawTooltip]. The message shows in a
/// `className`-styled box after the pointer has hovered the [child] for
/// [hoverDelay], or after a long press on touch devices, and fades out when
/// the pointer leaves. The message is also exposed as the [child]'s semantics
/// tooltip. An empty [message] renders the bare [child]: no overlay, no
/// semantics tooltip.
///
/// Needs an [Overlay] ancestor, which any `MaterialApp` or `WidgetsApp`
/// provides.
///
/// ### Example Usage:
/// ```dart
/// WTooltip(
///   message: 'Save changes',
///   child: WButton(
///     onTap: save,
///     child: WText('Save'),
///   ),
/// )
/// ```
class WTooltip extends StatelessWidget {
  /// The text shown in the tooltip and announced as the child's semantics
  /// tooltip. Empty disables the tooltip.
  final String message;

  /// The widget that triggers the tooltip.
  final Widget child;

  /// Utility classes for the tooltip box. Replaces the default entirely when
  /// given: `bg-gray-900 dark:bg-gray-100 text-white dark:text-gray-900
  /// text-xs px-2 py-1 rounded-md`.
  final String? className;

  /// Where the tooltip sits relative to the [child].
  final PopoverAlignment alignment;

  /// Gap between the [child] and the tooltip, in logical pixels.
  final Offset offset;

  /// How long a mouse pointer must hover the [child] before the tooltip shows.
  final Duration hoverDelay;

  static const String _defaultClassName =
      'bg-gray-900 dark:bg-gray-100 text-white dark:text-gray-900 '
      'text-xs px-2 py-1 rounded-md';

  const WTooltip({
    super.key,
    required this.message,
    required this.child,
    this.className,
    this.alignment = PopoverAlignment.bottomCenter,
    this.offset = const Offset(0, 4),
    this.hoverDelay = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return RawTooltip(
      semanticsTooltip: message,
      hoverDelay: hoverDelay,
      triggerMode: TooltipTriggerMode.longPress,
      tooltipBuilder: _buildTooltip,
      child: child,
    );
  }

  Widget _buildTooltip(BuildContext context, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: WDiv(
        className: className ?? _defaultClassName,
        child: WText(message),
      ),
    );
  }
}
