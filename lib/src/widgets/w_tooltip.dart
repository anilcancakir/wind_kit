import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'w_div.dart';
import 'w_popover.dart';
import 'w_text.dart';

/// **The Utility-First Tooltip**
///
/// A Material-free tooltip built on [RawTooltip]. The message shows in a
/// `className`-styled box after the pointer has hovered the [child] for
/// [hoverDelay], at once when the keyboard moves focus into the [child], or
/// after a long press on touch devices. It hides when the pointer leaves, on
/// blur and on Escape, which is consumed only while a tooltip is open. The
/// tooltip never takes focus and is not a Tab stop. The message is also
/// exposed as the [child]'s semantics tooltip. An empty [message] renders the
/// bare [child]: no overlay, no semantics tooltip.
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

  /// Whether this tooltip is open because focus showed it. A blur dismisses
  /// only while it is set, because [RawTooltip.dismissAllToolTips] cannot
  /// narrow to one instance and also closes any other tooltip open at that
  /// moment. The open overlay clears it through [_handleClosed] when it starts
  /// to close, whoever closed it (Escape, a pointer press, the pointer
  /// leaving), so a blur after that never reaches another tooltip.
  bool _shownByFocus = false;

  /// Whether the message overflows the capped box and scrolls. [RawTooltip]
  /// dismisses on any pointer press it does not own, which includes the one
  /// that starts a drag inside the box, so tap dismissal is off while this is
  /// set. The tooltip still hides on pointer exit, after the touch delay, on
  /// blur and on Escape.
  bool _scrollable = false;

  @override
  Widget build(BuildContext context) {
    return RawTooltip(
      key: _tooltipKey,
      semanticsTooltip: widget.message,
      hoverDelay: widget.hoverDelay,
      triggerMode: TooltipTriggerMode.longPress,
      enableTapToDismiss: !_scrollable,
      ignorePointer: false,
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

  void _handleClosed() {
    _shownByFocus = false;
  }

  /// Runs after the frame that laid the message out, so [setState] is safe.
  bool _handleScrollMetrics(ScrollMetricsNotification notification) {
    final bool scrollable = notification.metrics.maxScrollExtent > 0;
    if (mounted && scrollable != _scrollable) {
      setState(() => _scrollable = scrollable);
    }

    return false;
  }

  /// The box is capped at the overlay height less a margin on each side, so
  /// [_position] can always keep it on screen, and a longer message scrolls.
  /// The scroll view is not primary, so it never attaches to the page's
  /// [PrimaryScrollController]. [ExcludeFocus] keeps a `focus:` className on
  /// the box from adding a Tab stop, as the tooltip never takes focus.
  Widget _buildTooltip(BuildContext context, Animation<double> animation) {
    return _OpenTooltip(
      animation: animation,
      onClosed: _handleClosed,
      child: ExcludeFocus(
        child: FadeTransition(
          opacity: animation,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.max(0.0, constraints.maxHeight - _margin * 2),
                ),
                child: WDiv(
                  className: widget.className ?? _defaultClassName,
                  child: NotificationListener<ScrollMetricsNotification>(
                    onNotification: _handleScrollMetrics,
                    child: SingleChildScrollView(
                      primary: false,
                      child: WText(widget.message),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Marks the overlay child of one tooltip, which exists only while it shows,
/// and dismisses every open tooltip on Escape for as long as it is mounted, on
/// the Flutter versions whose [RawTooltip] does not do it itself (before 3.50).
/// Escape is left alone otherwise and reaches the app's own shortcuts.
///
/// [onClosed] fires when the tooltip starts to hide, or at once when the
/// overlay child is removed, so the owner never believes a closing tooltip is
/// still open.
///
/// The early [FocusManager] handler runs before the focus tree, so returning
/// [KeyEventResult.handled] keeps one Escape from also closing a dialog or
/// reaching the focused widget. The [HardwareKeyboard] handler covers the case
/// where nothing has primary focus, which the focus manager never sees.
class _OpenTooltip extends StatefulWidget {
  final Animation<double> animation;
  final VoidCallback onClosed;
  final Widget child;

  const _OpenTooltip({
    required this.animation,
    required this.onClosed,
    required this.child,
  });

  @override
  State<_OpenTooltip> createState() => _OpenTooltipState();
}

class _OpenTooltipState extends State<_OpenTooltip> {
  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_handleStatus);
    FocusManager.instance.addEarlyKeyEventHandler(_handleEarlyKeyEvent);
    HardwareKeyboard.instance.addHandler(_handleHardwareKeyEvent);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleStatus);
    FocusManager.instance.removeEarlyKeyEventHandler(_handleEarlyKeyEvent);
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    widget.onClosed();
    super.dispose();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse ||
        status == AnimationStatus.dismissed) {
      widget.onClosed();
    }
  }

  static bool _isEscape(KeyEvent event) {
    return (event is KeyDownEvent || event is KeyRepeatEvent) &&
        event.logicalKey == LogicalKeyboardKey.escape;
  }

  KeyEventResult _handleEarlyKeyEvent(KeyEvent event) {
    if (_isEscape(event) && RawTooltip.dismissAllToolTips()) {
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _handleHardwareKeyEvent(KeyEvent event) {
    if (FocusManager.instance.primaryFocus != null) {
      return false;
    }

    return _isEscape(event) && RawTooltip.dismissAllToolTips();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
