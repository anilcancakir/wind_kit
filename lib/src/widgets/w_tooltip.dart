import 'dart:async';

import 'package:flutter/services.dart';
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
class WTooltip extends StatefulWidget {
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
  State<WTooltip> createState() => _WTooltipState();
}

class _WTooltipState extends State<WTooltip> {
  static const String _defaultClassName =
      'bg-gray-900 dark:bg-gray-100 text-white dark:text-gray-900 '
      'text-xs px-2 py-1 rounded-md';

  /// Gap kept between the box and the overlay edge when it must be clamped.
  static const double _margin = 8;

  final GlobalKey<RawTooltipState> _tooltipKey = GlobalKey<RawTooltipState>();

  /// Whether the current focus showed the tooltip, so a blur hides only what
  /// a focus opened and never a tooltip the pointer is holding open.
  bool _shownByFocus = false;

  @override
  Widget build(BuildContext context) {
    return RawTooltip(
      key: _tooltipKey,
      semanticsTooltip: widget.message,
      hoverDelay: widget.hoverDelay,
      triggerMode: TooltipTriggerMode.longPress,
      positionDelegate: _position,
      tooltipBuilder: _buildTooltip,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onFocusChange: _onFocusChange,
        child: widget.child,
      ),
    );
  }

  /// Shows the tooltip at once when the keyboard moves focus into the child
  /// and hides it again on blur. Fires on every focus notification, so the
  /// flag, not [hasFocus], decides whether anything changes.
  void _onFocusChange(bool hasFocus) {
    if (!hasFocus) {
      if (_shownByFocus) {
        _shownByFocus = false;
        RawTooltip.dismissAllToolTips();
      }
      return;
    }
    if (widget.message.isEmpty ||
        FocusManager.instance.highlightMode != FocusHighlightMode.traditional) {
      return;
    }
    // The newly focused path is notified before the old one, so showing now
    // would let the previous tooltip's blur dismiss this one as well.
    scheduleMicrotask(() {
      if (!mounted) {
        return;
      }
      if (_tooltipKey.currentState?.ensureTooltipVisible() ?? false) {
        _shownByFocus = true;
      }
    });
  }

  /// Places the box on the requested side of the [child], then lets the public
  /// popover helpers flip it and pull it back inside the overlay.
  Offset _position(TooltipPositionContext context) {
    // 1. RawTooltip reports the child's centre, the helpers want its top left.
    final Size triggerSize = context.targetSize;
    final Size tooltipSize = context.tooltipSize;
    final Size overlaySize = context.overlaySize;
    final Offset offset = widget.offset;
    final Offset trigger =
        context.target - Offset(triggerSize.width / 2, triggerSize.height / 2);

    // 2. Flip to the side with room, then correct what the flip cannot.
    final PopoverAlignment effective = computeEffectiveAlignment(
      requested: widget.alignment,
      triggerPosition: trigger,
      triggerSize: triggerSize,
      popoverSize: tooltipSize,
      screenSize: overlaySize,
      offset: offset,
    );
    final double dxCorrection = computeHorizontalClamp(
      alignment: effective,
      triggerPosition: trigger,
      triggerSize: triggerSize,
      popoverWidth: tooltipSize.width,
      screenSize: overlaySize,
      offset: offset,
    );

    // 3. Anchor on the effective side.
    final double x = switch (effective) {
      PopoverAlignment.bottomLeft ||
      PopoverAlignment.topLeft => trigger.dx + offset.dx,
      PopoverAlignment.bottomRight || PopoverAlignment.topRight =>
        trigger.dx + triggerSize.width - tooltipSize.width + offset.dx,
      PopoverAlignment.bottomCenter || PopoverAlignment.topCenter =>
        trigger.dx + (triggerSize.width - tooltipSize.width) / 2 + offset.dx,
    };
    final bool isTop =
        effective == PopoverAlignment.topLeft ||
        effective == PopoverAlignment.topCenter ||
        effective == PopoverAlignment.topRight;
    final double y = isTop
        ? trigger.dy - offset.dy - tooltipSize.height
        : trigger.dy + triggerSize.height + offset.dy;

    // 4. A box taller than the room on its side stays inside the overlay.
    final double available = computeAvailableHeight(
      alignment: effective,
      triggerPosition: trigger,
      triggerSize: triggerSize,
      screenSize: overlaySize,
      offset: offset,
    );
    if (available >= tooltipSize.height) {
      return Offset(x + dxCorrection, y);
    }
    final double maxY = overlaySize.height - tooltipSize.height - _margin;

    return Offset(
      x + dxCorrection,
      y.clamp(_margin, maxY < _margin ? _margin : maxY),
    );
  }

  Widget _buildTooltip(BuildContext context, Animation<double> animation) {
    return _EscapeDismissal(
      child: FadeTransition(
        opacity: animation,
        child: WDiv(
          className: widget.className ?? _defaultClassName,
          child: WText(widget.message),
        ),
      ),
    );
  }
}

/// Dismisses every open tooltip on Escape for as long as it is mounted. It
/// sits in the overlay child, which exists only while a tooltip shows, so
/// Escape is left alone otherwise and reaches the app's own shortcuts.
class _EscapeDismissal extends StatefulWidget {
  final Widget child;

  const _EscapeDismissal({required this.child});

  @override
  State<_EscapeDismissal> createState() => _EscapeDismissalState();
}

class _EscapeDismissalState extends State<_EscapeDismissal> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }

    return RawTooltip.dismissAllToolTips();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
