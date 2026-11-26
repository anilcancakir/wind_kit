import 'package:material_ui/material_ui.dart';

import '../parser/wind_parser.dart';
import '../parser/wind_style.dart';
import '../state/wind_anchor_state_provider.dart';
import '../utils/wind_helpers.dart';
import '../utils/wind_perf_counters.dart';
import 'w_anchor.dart';
import 'w_div.dart';
import 'w_text.dart';

/// **The Utility-First Button Component**
///
/// `WButton` is a button widget that combines `WAnchor` state management
/// with Tailwind-like utility class styling and built-in loading states.
///
/// ### Supported Features:
/// - **States:** `hover:bg-blue-700`, `focus:ring-2`, `disabled:opacity-50`
/// - **Loading:** Built-in spinner, so no class is needed to hide the
///   label; `loadingColor` sets the spinner's colour and `loadingText` puts a
///   caption beside it. The child stays in the tree, unpainted and outside
///   the layout size, when nothing else names the button: the accessible
///   name is `semanticLabel`, else a rendered non-blank `loadingText`, else
///   the child's text.
/// - **Interactvity:** `onTap`, `onDoubleTap`, `onLongPress`
/// - **Styling:** `bg-blue-500`, `text-white`, `rounded`, `shadow`
///
/// ### Example Usage:
///
/// ```dart
/// WButton(
///   onTap: () => print('Clicked!'),
///   className: 'bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg transition-colors',
///   child: Text('Click me'),
/// )
/// ```
///
/// ### Loading State Example:
///
/// ```dart
/// WButton(
///   onTap: _submit,
///   isLoading: _isSubmitting,
///   loadingText: 'Submitting...',
///   className: 'bg-blue-600 text-white px-4 py-2 rounded-lg loading:opacity-70',
///   child: Text('Submit'),
/// )
/// ```
///
/// See also:
///
///  * [WAnchor], which `WButton` delegates all state management and interaction handling to.
///  * [WInput], which pairs with `WButton` in form submission flows.
class WButton extends StatelessWidget {
  /// The button content when not loading.
  final Widget child;

  /// Callback when button is tapped.
  ///
  /// Ignored when `isLoading` or `disabled` is true.
  final VoidCallback? onTap;

  /// Callback when button is long pressed.
  final VoidCallback? onLongPress;

  /// Callback when button is double tapped.
  final VoidCallback? onDoubleTap;

  /// Whether the button is in loading state.
  ///
  /// **Effects:**
  /// - Disables user interaction (`onTap` will not fire).
  /// - Paints a loading spinner in place of the child; the child stays
  ///   mounted but unpainted when it supplies the accessible name.
  /// - Activates the `loading:` prefix for styling (e.g., `loading:opacity-50`).
  final bool isLoading;

  /// Whether the button is disabled.
  ///
  /// **Effects:**
  /// - Disables user interaction.
  /// - Activates the `disabled:` prefix for styling (e.g., `disabled:bg-gray-300`).
  /// - Changes cursor to `forbidden` (desktop/web).
  final bool disabled;

  /// Tailwind-like utility classes for styling.
  ///
  /// Supports special states:
  /// - **Hover:** `hover:bg-blue-700`
  /// - **Focus:** `focus:ring-2 focus:ring-blue-500`
  /// - **Disabled:** `disabled:bg-gray-300 disabled:cursor-not-allowed`
  /// - **Loading:** `loading:opacity-75`
  ///
  /// Example: `'bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400'`
  final String? className;

  /// Optional text to show alongside the loading spinner.
  final String? loadingText;

  /// Custom loading widget to replace the default spinner.
  final Widget? loadingWidget;

  /// Size of the default loading spinner.
  final double loadingSize;

  /// Color of the default loading spinner.
  ///
  /// If null, uses the text color from className or white.
  final Color? loadingColor;

  /// Custom states for dynamic styling (e.g., 'error', 'success').
  ///
  /// These states activate their corresponding prefix classes.
  /// Example: `states: {'error'}` activates `error:border-red-500`.
  final Set<String>? states;

  /// An explicit accessible label for the button.
  ///
  /// Required in practice for icon-only buttons, where there is no text child
  /// for the Semantics tree to absorb. Forwarded to [WAnchor.semanticLabel].
  final String? semanticLabel;

  /// An external focus node, to move focus to the button or read its focus.
  ///
  /// The caller owns a given node: the button never disposes it, and swapping
  /// it for another between rebuilds moves the `focus:` styling to the new
  /// node. A disabled or loading button cannot take focus, and the node keeps
  /// the `canRequestFocus` the button last gave it. Forwarded to
  /// [WAnchor.focusNode].
  final FocusNode? focusNode;

  /// Whether the button asks for focus when it first mounts.
  ///
  /// Applies only when nothing in the focus scope is focused already, as with
  /// [Focus.autofocus]. A button that is disabled or loading at mount never
  /// takes focus, and does not ask again when loading ends. Forwarded to
  /// [WAnchor.autofocus].
  final bool autofocus;

  /// Creates a new [WButton] instance.
  const WButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.isLoading = false,
    this.disabled = false,
    this.className,
    this.loadingText,
    this.loadingWidget,
    this.loadingSize = 16,
    this.loadingColor,
    this.states,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    WindPerfCounters.recordWidgetBuild('WButton');

    // Determine if button is interactive
    final bool isInteractive = !isLoading && !disabled;
    final bool hasCallback =
        onTap != null || onLongPress != null || onDoubleTap != null;

    // The callbacks reach WAnchor even when the button is inert, because a
    // gestureless anchor reads as a styling wrapper and publishes no button
    // node: a disabled or loading button vanished from the Semantics tree.
    // `isDisabled` is what keeps them from firing, so loading must set it too.
    final Widget anchor = WAnchor(
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      isDisabled: !isInteractive,
      focusNode: focusNode,
      autofocus: autofocus,
      states: states,
      // Without a callback the label goes on the node built below: WAnchor
      // would publish it as an ENABLED button, since it is not `isDisabled`.
      semanticLabel: hasCallback ? semanticLabel : null,
      mouseCursor: isInteractive
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: Builder(
        builder: (innerContext) {
          // Now we can access the hover state from WindAnchorStateProvider
          final anchorState = WindAnchorStateProvider.of(innerContext);

          // Build active states set for parsing
          final Set<String> activeStates = {
            ...?anchorState?.customStates,
            if (isLoading) 'loading',
            if (disabled) 'disabled',
            if (anchorState?.isHovering ?? false) 'hover',
            if (anchorState?.isFocused ?? false) 'focus',
          };

          // Parse styles with current states
          final WindStyle styles = className != null
              ? WindParser.parse(className!, innerContext, states: activeStates)
              : const WindStyle();

          // Build content
          Widget content = isLoading ? _buildLoadingContent(styles) : child;

          // A spinner carries no text, so a loading button named by neither
          // `semanticLabel` nor a rendered `loadingText` would be nameless.
          // The child stays mounted, unpainted and out of the layout size,
          // purely so its text names the merged button node. `ExcludeFocus`
          // keeps a focusable descendant of the unpainted child from being an
          // invisible keyboard stop.
          final bool namedByChild =
              isLoading &&
              semanticLabel == null &&
              (!_hasLoadingCaption || loadingWidget != null);
          if (namedByChild) {
            content = Stack(
              alignment: Alignment.center,
              fit: StackFit.passthrough,
              children: [
                content,
                Positioned.fill(
                  child: ExcludeFocus(
                    child: Opacity(
                      opacity: 0,
                      alwaysIncludeSemantics: true,
                      child: child,
                    ),
                  ),
                ),
              ],
            );
          }

          // Determine alignment for content
          // justify-center in flex maps to centered content
          Alignment? containerAlignment;
          if (styles.mainAxisAlignment == MainAxisAlignment.center) {
            containerAlignment = Alignment.center;
          } else if (styles.alignment != null) {
            containerAlignment = styles.alignment;
          }

          // The box shadow travels beside the decoration in WindStyle, so it
          // is folded in here; building from the decoration alone dropped
          // every `shadow-*` on a button.
          final List<BoxShadow>? shadows = styles.boxShadow;
          final BoxDecoration? decoration = shadows == null || shadows.isEmpty
              ? styles.decoration
              : (styles.decoration ?? const BoxDecoration()).copyWith(
                  boxShadow: shadows,
                );

          // Wrap in styled container
          WindPerfCounters.recordWrapperEmission('Container');
          WindPerfCounters.recordWrapperEmission('DefaultTextStyle');
          Widget styledButton = Container(
            width: styles.widthFactor != null ? double.infinity : styles.width,
            height: styles.heightFactor != null
                ? double.infinity
                : styles.height,
            constraints: styles.constraints,
            padding: styles.padding,
            decoration: decoration,
            alignment: containerAlignment,
            child: DefaultTextStyle.merge(
              style: styles.toTextStyle(
                inheritedFontSize: styles.needsInheritedFontSize
                    ? wInheritedFontSize(innerContext)
                    : null,
              ),
              child: content,
            ),
          );

          // The ring, an outline around the box (`WindStyle.ringOutline`).
          // A button is the control most often focused from the keyboard, and
          // its `focus:ring-*` painted nothing until this.
          final BoxDecoration? ring = styles.ringOutline;
          if (ring != null) {
            WindPerfCounters.recordWrapperEmission('DecoratedBox');
            styledButton = DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: ring,
              child: styledButton,
            );
          }

          // The opacity, as `WDiv` applies it: animated under a transition.
          // It is how a `disabled:` or `loading:` button usually fades, and it
          // painted nothing until this.
          final double? opacity = styles.opacity;
          if (opacity != null) {
            final Duration? duration = styles.transitionDuration;
            if (duration != null) {
              WindPerfCounters.recordWrapperEmission('AnimatedOpacity');
              styledButton = AnimatedOpacity(
                duration: duration,
                curve: styles.transitionCurve ?? Curves.linear,
                opacity: opacity,
                child: styledButton,
              );
            } else {
              WindPerfCounters.recordWrapperEmission('Opacity');
              styledButton = Opacity(opacity: opacity, child: styledButton);
            }
          }

          // Wrap with AbsorbPointer when not interactive
          if (!isInteractive) {
            WindPerfCounters.recordWrapperEmission('AbsorbPointer');
            styledButton = AbsorbPointer(child: styledButton);
          }

          return styledButton;
        },
      ),
    );

    if (hasCallback) {
      return anchor;
    }

    // With no callback WAnchor is gestureless and publishes nothing, which is
    // right for a styling wrapper and wrong for a button: the common
    // `onTap: canSubmit ? submit : null` left its label as plain text. The
    // button publishes its own node, never enabled, since nothing can run.
    WindPerfCounters.recordWrapperEmission('MergeSemantics');
    WindPerfCounters.recordWrapperEmission('Semantics');
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: false,
        label: semanticLabel,
        excludeSemantics: semanticLabel != null,
        child: anchor,
      ),
    );
  }

  /// Whether [loadingText] has a readable caption to render.
  ///
  /// A blank one would be a gap beside the spinner that names nothing, so it
  /// is not rendered and the child names the button instead.
  bool get _hasLoadingCaption => loadingText?.trim().isNotEmpty ?? false;

  /// Builds the loading content with spinner and optional text.
  Widget _buildLoadingContent(WindStyle styles) {
    if (loadingWidget != null) {
      return loadingWidget!;
    }

    // Determine spinner color:
    // 1. Explicit loadingColor takes priority.
    // 2. Text color from className (styles.color), unless it is fully
    //    transparent. `text-transparent` says "do not show the label"; the
    //    spinner is not the label, and reading it as a spinner color paints
    //    nothing for the whole loading state. `loadingColor` is the channel
    //    for asking for a transparent spinner on purpose, and it still wins.
    // 3. Contrast color based on background: prevents invisible spinners
    //    (e.g., white spinner on white button).
    // 4. Final fallback: white.
    final Color? textColor = styles.color;
    final Color spinnerColor =
        loadingColor ??
        ((textColor != null && textColor.a > 0)
            ? textColor
            : _contrastColor(styles));

    // The indicator publishes `SemanticsRole.loadingSpinner`, and merging
    // copies a child's role onto the button node, whose role is `none` (the
    // button is a flag). Flutter web reads the role before the flags, so the
    // merged node lost its button role and its disabled state. The spinner
    // carries no label, so excluding it drops only that role.
    WindPerfCounters.recordWrapperEmission('ExcludeSemantics');
    final Widget spinner = SizedBox(
      width: loadingSize,
      height: loadingSize,
      child: ExcludeSemantics(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
        ),
      ),
    );

    if (_hasLoadingCaption) {
      return WDiv(
        className: 'flex items-center justify-center gap-2',
        children: [spinner, WText(loadingText!)],
      );
    }

    return WDiv(
      className: 'flex items-center justify-center',
      children: [spinner],
    );
  }

  /// Returns a contrasting spinner color based on background luminance.
  ///
  /// If the background is light (luminance > 0.5), returns a dark color.
  /// Otherwise returns white, matching the common pattern of light text
  /// on dark buttons.
  Color _contrastColor(WindStyle styles) {
    final Color? bgColor = styles.decoration?.color;
    if (bgColor == null) return Colors.white;

    // Use W3C relative luminance to determine if background is light.
    return bgColor.computeLuminance() > 0.5
        ? const Color(0xFF1E293B) // slate-800, readable on light bg
        : Colors.white;
  }
}
