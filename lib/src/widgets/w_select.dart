import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../parser/wind_parser.dart';
import '../parser/wind_style.dart';
import '../state/wind_anchor_state.dart';
import '../state/wind_anchor_state_provider.dart';
import '../utils/wind_extensions.dart';
import '../utils/wind_logger.dart';
import '../utils/wind_perf_counters.dart';
import 'select_option.dart';
import 'w_div.dart';
import 'w_input.dart';
import 'w_popover.dart';
import 'w_text.dart';

/// Signature for building a custom trigger widget for [WSelect].
///
/// The [selectedOption] is null when no value is selected.
/// For multi-select, use [MultiSelectTriggerBuilder] instead.
typedef SelectTriggerBuilder<T> = Widget Function(
  BuildContext context,
  SelectOption<T>? selectedOption,
  bool isOpen,
);

/// Signature for building a custom trigger widget for multi-select [WSelect].
typedef MultiSelectTriggerBuilder<T> = Widget Function(
  BuildContext context,
  List<SelectOption<T>> selectedOptions,
  bool isOpen,
);

/// Signature for building a custom item widget for [WSelect].
typedef SelectItemBuilder<T> = Widget Function(
  BuildContext context,
  SelectOption<T> option,
  bool isSelected,
  bool isHovered,
);

/// Signature for building a selected chip/tag in multi-select mode.
typedef SelectedChipBuilder<T> = Widget Function(
  BuildContext context,
  SelectOption<T> option,
  VoidCallback onRemove,
);

/// Signature for building the "create option" button.
typedef CreateOptionBuilder = Widget Function(
  BuildContext context,
  String query,
  VoidCallback onCreate,
);

/// Signature for building the empty state.
typedef EmptyStateBuilder = Widget Function(BuildContext context, String query);

/// Signature for building the loading indicator.
typedef LoadingBuilder = Widget Function(BuildContext context);

/// **The Utility-First Select Component**
///
/// `WSelect` is a highly customizable dropdown widget that combines
/// React-style controlled state management with Tailwind-like utility class styling.
///
/// ### Supported Features:
/// - **Selection:** Single or Multi-select (`isMulti: true`)
/// - **Searchable:** Built-in search input (`searchable: true`)
/// - **Remote Data:** Async search (`onSearch`) and Pagination (`onLoadMore`)
/// - **Tagging:** Create new options on the fly (`onCreateOption`)
/// - **Styling:** `className` (trigger) and `menuClassName` (dropdown)
/// - **Keyboard:** Enter, Space or ArrowDown opens the menu; arrows move the
///   highlight over enabled options (no wrap) and Home/End jump to the ends,
///   Enter or Space selects and Escape closes. A searchable menu leaves Space
///   and Home/End to its search field.
///
/// ### Example Usage:
///
/// ```dart
/// WSelect<String>(
///   value: _selectedCountry,
///   options: countries,
///   onChange: (value) => setState(() => _selectedCountry = value),
///   className: 'w-64 bg-white border border-gray-300 rounded-lg',
///   menuClassName: 'bg-white shadow-xl rounded-lg border border-gray-100',
/// )
/// ```
///
/// ### Multi-Select Example:
///
/// ```dart
/// WSelect<String>(
///   isMulti: true,
///   values: _selectedTags,
///   options: tags,
///   onMultiChange: (values) => setState(() => _selectedTags = values),
///   searchable: true,
/// )
/// ```
class WSelect<T> extends StatefulWidget {
  // ============== SINGLE SELECT PROPS ==============

  /// The currently selected value (single-select mode).
  final T? value;

  /// Called when the user selects an option (single-select mode).
  final ValueChanged<T>? onChange;

  // ============== MULTI-SELECT PROPS ==============

  /// Whether to enable multi-select mode.
  ///
  /// When true, use `values` and `onMultiChange` instead of `value`/`onChange`.
  final bool isMulti;

  /// The currently selected values (multi-select mode).
  final List<T>? values;

  /// Called when selection changes (multi-select mode).
  final ValueChanged<List<T>>? onMultiChange;

  /// Custom builder for selected chips in multi-select mode.
  final SelectedChipBuilder<T>? selectedChipBuilder;

  // ============== OPTIONS ==============

  /// The list of available options.
  final List<SelectOption<T>> options;

  // ============== SEARCH ==============

  /// Whether the dropdown includes a search input.
  final bool searchable;

  /// Async search callback for fetching filtered options.
  final Future<List<SelectOption<T>>> Function(String query)? onSearch;

  /// Placeholder text for the search input.
  final String searchPlaceholder;

  // ============== TAGGING ==============

  /// Callback to create a new option from search query.
  ///
  /// When provided and search returns no matches, a "Create X" button appears.
  final Future<SelectOption<T>> Function(String query)? onCreateOption;

  /// Custom builder for the "Create X" button.
  final CreateOptionBuilder? createOptionBuilder;

  // ============== PAGINATION ==============

  /// Callback for loading more options (infinite scroll).
  final Future<List<SelectOption<T>>> Function()? onLoadMore;

  /// Whether more pages are available for pagination.
  final bool hasMore;

  /// Called when the menu OPENS, before the first frame of the overlay.
  ///
  /// Opening resets this widget's own visible list: `_searchQuery` goes back to
  /// empty and `_filteredOptions` back to [options]. A caller paginating
  /// through [onLoadMore] keeps its cursor across that reset unless something
  /// tells it, and then the next scroll to the bottom asks for the page AFTER
  /// the one the reader can no longer see. Reported against a searchable
  /// timezone select: open, scroll once to pull page two, close, reopen, and
  /// page two's rows were unreachable without searching for them.
  ///
  /// So a caller that paginates resets its cursor here. Nothing else in this
  /// widget needs it, which is why it is a callback rather than internal state:
  /// the cursor belongs to whoever owns [onLoadMore].
  ///
  /// That advice assumes [options] goes back to page one along with the visible
  /// list, which is the ordinary shape: return rows from [onLoadMore] and leave
  /// [options] alone. A caller that instead MIRRORS fetched pages into
  /// [options] already holds all of them on reopen, so resetting its cursor
  /// here would re-fetch page two and append duplicates. Reset the cursor only
  /// if [options] resets too.
  final VoidCallback? onOpen;

  // ============== STYLING ==============

  /// Tailwind-like utility classes for the trigger container.
  ///
  /// Supports:
  /// - **Box Model:** `w-64`, `p-3`, `rounded-lg`
  /// - **Visuals:** `bg-white`, `border`, `border-gray-300`
  /// - **States:** `hover:border-blue-500`, `focus:ring-2`
  ///
  /// Without a className the trigger is `bg-white dark:bg-gray-800` with a
  /// gray 300 (dark: gray 600) border. A custom className replaces that
  /// default, so give each colour class its `dark:` peer.
  ///
  /// Example: `'w-full p-2 bg-white dark:bg-gray-800 border rounded shadow-sm'`
  final String? className;

  /// Tailwind-like utility classes for the dropdown menu container.
  ///
  /// *Note: This container holds the scrollable list.*
  ///
  /// Supports:
  /// - **Box Model:** `rounded-lg`, `border`
  /// - **Shadow:** `shadow-xl`, `shadow-gray-200`
  /// - **Background:** `bg-white dark:bg-gray-800` (Recommended)
  ///
  /// A menu with no background class gets the default surface (white, gray 800
  /// in dark mode); with no decoration at all it also gets the default border
  /// (gray 200, dark gray 700) and shadow. Any background class you give wins.
  ///
  /// Example: `'bg-white dark:bg-gray-800 border border-gray-100 shadow-lg rounded-xl'`
  final String? menuClassName;

  /// Placeholder text shown when no value is selected.
  final String placeholder;

  /// Whether the select is disabled.
  final bool disabled;

  /// Width of the dropdown menu.
  final double? menuWidth;

  /// Maximum height of the dropdown menu.
  final double maxMenuHeight;

  /// Custom states for dynamic styling.
  final Set<String>? states;

  // ============== CUSTOM BUILDERS ==============

  /// Custom builder for the trigger widget (single-select).
  final SelectTriggerBuilder<T>? triggerBuilder;

  /// Custom builder for the trigger widget (multi-select).
  final MultiSelectTriggerBuilder<T>? multiTriggerBuilder;

  /// Custom builder for option items.
  final SelectItemBuilder<T>? itemBuilder;

  /// Custom builder for empty state.
  final EmptyStateBuilder? emptyBuilder;

  /// Custom builder for loading indicator.
  final LoadingBuilder? loadingBuilder;

  /// Creates a new [WSelect] instance.
  const WSelect({
    super.key,
    // Single select
    this.value,
    this.onChange,
    // Multi select
    this.isMulti = false,
    this.values,
    this.onMultiChange,
    this.selectedChipBuilder,
    // Options
    required this.options,
    // Search
    this.searchable = false,
    this.onSearch,
    this.searchPlaceholder = 'Search...',
    // Tagging
    this.onCreateOption,
    this.createOptionBuilder,
    // Pagination
    this.onLoadMore,
    this.hasMore = false,
    this.onOpen,
    // Styling
    this.className,
    this.menuClassName,
    this.placeholder = 'Select an option',
    this.disabled = false,
    this.menuWidth,
    this.maxMenuHeight = 300,
    this.states,
    // Builders
    this.triggerBuilder,
    this.multiTriggerBuilder,
    this.itemBuilder,
    this.emptyBuilder,
    this.loadingBuilder,
  });

  @override
  State<WSelect<T>> createState() => _WSelectState<T>();
}

class _WSelectState<T> extends State<WSelect<T>> {
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _triggerKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  bool _isOpen = false;
  bool _isHovering = false;
  bool _openUpward = false;

  /// Whether the trigger holds focus that a keyboard put there.
  ///
  /// Gated on [FocusHighlightMode.traditional] the way Flutter's own focus
  /// highlights are, so a ring answers Tab and not a tap that happens to move
  /// focus. Never true while disabled.
  bool _hasKeyboardFocus = false;

  /// The theme's `primary` swatch, used for the raw [Icon] colors that cannot
  /// take a className. `primary` is always present in the resolved color map
  /// (Wind seeds it into the default theme), so the brand color drives these
  /// icons the same way `bg-primary`/`text-primary` drive the surrounding text.
  MaterialColor get _primaryColor => context.windColors['primary']!;

  /// A specific [shade] of the theme `primary` swatch for a raw [Icon] color,
  /// falling back to the swatch's base color when a consumer registered a
  /// partial `primary` `MaterialColor` without that shade, so a custom theme
  /// can never crash the icon lookup (the `.shadeN` getters would throw).
  Color _primaryShade(int shade) => _primaryColor[shade] ?? _primaryColor;

  /// Picks [light] or [dark] for a raw colour that cannot take a `dark:` class.
  Color _paired({required Color light, required Color dark}) =>
      context.windIsDark ? dark : light;

  /// Shared [TapRegion] group for the trigger and the open menu, so re-tapping
  /// the trigger toggles it closed (the tap is inside the group) rather than
  /// being treated as an outside tap. The opening-tap self-close is handled
  /// separately by deferring the overlay mount one frame (see [_toggleMenu]).
  final Object _tapGroupId = Object();
  String _searchQuery = '';
  List<SelectOption<T>> _filteredOptions = [];
  bool _isSearching = false;
  bool _isLoadingMore = false;

  /// Bumped every time the widget replaces its own list wholesale, which is
  /// every open and every caller-driven change of `options`.
  ///
  /// An async response captured before that reset must not write to the list
  /// the reset restored, and neither async path can decide that on its own.
  /// A search compares query strings, and the empty query is equal to itself
  /// across a reset, so clearing the box and reopening inside the window let a
  /// stale response overwrite the restored options. A page has no query to
  /// compare at all, so it was stitched onto the end of a list the reader had
  /// not scrolled past. Both are the same question, which is not "is this the
  /// answer I last asked for" but "is the list I was answering still on
  /// screen".
  int _listEpoch = 0;
  bool _isCreating = false;

  /// The highlighted row: the hovered one, or the one the keyboard moved to.
  int _hoveredIndex = -1;

  /// Whether a keyboard move still has to scroll its row into view.
  ///
  /// While raised, every row the list builds hands its context to
  /// [_revealRows] from the [Builder] that wraps it, which is how the
  /// post-frame reveal finds the target's render object without a key per row,
  /// and which rows are built when the target is not one of them.
  bool _revealPending = false;
  bool _revealDownward = true;
  int _revealIndex = -1;

  /// The contexts of the rows built since the reveal was requested, by index.
  final Map<int, BuildContext> _revealRows = {};

  /// Whether the reveal spent its one proportional jump.
  bool _revealJumped = false;

  /// The direction the reveal steps in once it walks the list a viewport at a
  /// time: 1 down, -1 up, 0 before the first step.
  int _revealStep = 0;

  /// Whether a reveal attempt is already queued for the next frame, so two
  /// key presses inside one frame do not run two walks side by side.
  bool _revealScheduled = false;

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(_syncKeyboardFocus);
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChange);
  }

  @override
  void didUpdateWidget(WSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.options != oldWidget.options) {
      // A parent that builds `options` inline hands over a new list on every
      // rebuild, including the one a multi-select toggle triggers, so the
      // highlight follows its option into the new list instead of resetting.
      final SelectOption<T>? highlighted =
          _hoveredIndex >= 0 && _hoveredIndex < _filteredOptions.length
          ? _filteredOptions[_hoveredIndex]
          : null;
      _filteredOptions = widget.options;
      // The other place the list is replaced wholesale, and the epoch covers
      // it for the same reason it covers the open: a page or a search captured
      // against the previous list must not write into this one. A caller
      // refreshing `options` while the menu is open is narrower than a reopen
      // but the symptom is identical, rows from a list nobody is looking at.
      //
      // Lowering the flag is not optional here, and the bump is exactly why.
      // The resolve path is the only place that lowers it and it is guarded on
      // the epoch, so bumping without this strands the menu on a spinner: a
      // search for the empty query has nothing behind it to raise and lower
      // the flag again, since the re-filter below only runs for a non-empty
      // one. The open branch lowers it for the same reason.
      _listEpoch++;
      _isSearching = false;
      // The query did not change, so a re-filter carries the highlight over to
      // the filtered list rather than resetting it the way typing does.
      if (_searchQuery.isEmpty) {
        _hoveredIndex = _indexOfOption(_filteredOptions, highlighted);
      } else {
        _filterOptions(_searchQuery, highlighted: highlighted);
      }
    }
  }

  /// The index of the option sharing [option]'s value in [options], or -1 when
  /// [option] is null or absent.
  int _indexOfOption(List<SelectOption<T>> options, SelectOption<T>? option) {
    if (option == null) return -1;

    return options.indexWhere(
      (SelectOption<T> candidate) => candidate.value == option.value,
    );
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChange);
    _focusNode.removeListener(_syncKeyboardFocus);
    _focusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onHighlightModeChange(FocusHighlightMode mode) => _syncKeyboardFocus();

  void _syncKeyboardFocus() {
    final bool hasKeyboardFocus =
        !widget.disabled &&
        _focusNode.hasFocus &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

    if (hasKeyboardFocus != _hasKeyboardFocus) {
      setState(() => _hasKeyboardFocus = hasKeyboardFocus);
    }
  }

  /// Handle scroll for infinite scroll pagination
  void _onScroll() {
    if (!widget.hasMore || _isLoadingMore || widget.onLoadMore == null) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 50) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || widget.onLoadMore == null) return;

    final int epoch = _listEpoch;

    setState(() => _isLoadingMore = true);
    try {
      final moreOptions = await widget.onLoadMore!();
      if (mounted) {
        setState(() {
          // The flag is lowered either way: a discarded page still ends the
          // request, and leaving it raised would refuse every later scroll.
          if (epoch == _listEpoch) {
            _filteredOptions = [..._filteredOptions, ...moreOptions];
          }
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// Opens or closes the menu.
  ///
  /// A [keyboard] open starts with the highlight on the selected option (the
  /// first enabled one when nothing is selected); a pointer open leaves the
  /// highlight to the hover.
  void _toggleMenu({bool keyboard = false}) {
    if (widget.disabled) return;

    if (!_isOpen) {
      // Calculate whether to open upward based on available space
      final RenderBox? triggerBox =
          _triggerKey.currentContext?.findRenderObject() as RenderBox?;
      if (triggerBox != null) {
        final triggerPosition = triggerBox.localToGlobal(Offset.zero);
        final screenHeight = MediaQuery.sizeOf(context).height;
        final spaceBelow =
            screenHeight - triggerPosition.dy - triggerBox.size.height;
        final menuMaxHeight = widget.maxMenuHeight;
        _openUpward =
            spaceBelow < menuMaxHeight && triggerPosition.dy > spaceBelow;
      }
    }

    final bool isOpening = !_isOpen;

    setState(() {
      _isOpen = isOpening;
      if (_isOpen) {
        _searchQuery = '';
        _filteredOptions = widget.options;
        _hoveredIndex = keyboard ? _initialHighlight() : -1;
        // A selected option far down a long list opens off screen otherwise.
        _requestReveal(_hoveredIndex, downward: true);
        // The query and the list are back to their defaults, so the search
        // that was in flight against the old query no longer owns this menu.
        // Leaving the flag set stranded the reopened menu on a spinner:
        // `_filterOptions` only lowers it when the response still matches
        // `_searchQuery`, and the reset above guarantees it never will.
        _isSearching = false;
        _listEpoch++;
        // Defer the overlay mount to the next frame so the opening tap's own
        // pointer-up is fully dispatched BEFORE the overlay's TapRegion exists.
        // OverlayPortal mounts synchronously, so showing it now routes that
        // same pointer-up to the fresh overlay's onTapOutside, closing the menu
        // on the frame it opened (a one-frame suppress guard is not enough).
        // The shared groupId still stops a trigger re-tap from self-closing.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_isOpen) return;
          _overlayController.show();
          // The overlay builds on the frame after `show`, so the reveal waits
          // for that one.
          if (_revealPending) _scheduleReveal();
        });
      } else {
        _overlayController.hide();
      }
    });

    // Outside the `setState`, and for the same reason every other caller
    // callback in this file is: a caller that throws here would otherwise
    // abandon the closure half done, leaving the menu marked open with its
    // overlay mount never scheduled. The visible list is back to `options` by
    // now, so a caller's pagination cursor is ahead of what the reader can
    // see, which is what this call is telling it.
    if (isOpening) widget.onOpen?.call();

    // A pointer open leaves focus wherever the tap put it, and the keys only
    // reach this widget from its trigger. A searchable menu hands focus to its
    // own search field instead, and the field's autofocus only wins when
    // nothing in the scope holds focus, so the trigger lets go of it first.
    if (!isOpening) return;
    if (widget.searchable) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  /// Closes the menu. [restoreFocus] hands focus back to the trigger first,
  /// which a keyboard close needs and a tap outside must not do.
  void _closeMenu({bool restoreFocus = false}) {
    if (_isOpen) {
      if (restoreFocus) _focusNode.requestFocus();
      setState(() {
        _isOpen = false;
        _overlayController.hide();
      });
    }
  }

  void _selectOption(SelectOption<T> option, {bool restoreFocus = false}) {
    if (option.disabled) return;

    if (widget.isMulti) {
      _toggleMultiSelection(option);
    } else {
      widget.onChange?.call(option.value);
      _closeMenu(restoreFocus: restoreFocus);
    }
  }

  /// The row a keyboard open highlights: the first enabled option that is
  /// selected, else the first enabled option, else -1.
  int _initialHighlight() {
    final int firstEnabled = _enabledIndexFrom(-1, 1);
    final int selected = widget.options.indexWhere(
      (SelectOption<T> option) =>
          !option.disabled && _isValueSelected(option.value),
    );

    return selected != -1 ? selected : firstEnabled;
  }

  /// The nearest enabled index after [from] in direction [step] (1 or -1) in
  /// the visible list, or -1 when there is none.
  int _enabledIndexFrom(int from, int step) {
    final List<SelectOption<T>> options = _isOpen
        ? _filteredOptions
        : widget.options;

    for (int i = from + step; i >= 0 && i < options.length; i += step) {
      if (!options[i].disabled) return i;
    }

    return -1;
  }

  /// Enter and the D-pad centre or gamepad A key of a TV remote, the keys the
  /// framework's own `ActivateIntent` binds besides Space.
  bool _isActivateKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.gameButtonA;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.disabled) return KeyEventResult.ignored;
    // This `Focus` also sits above a custom trigger's own focusable (a text
    // field, say), whose Space and Enter belong to it.
    if (node == _focusNode && !node.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }

    final LogicalKeyboardKey key = event.logicalKey;
    final bool isArrow =
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp;
    if (event is! KeyDownEvent && !(isArrow && event is KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }

    return _isOpen ? _onOpenKey(key) : _onClosedKey(key);
  }

  KeyEventResult _onClosedKey(LogicalKeyboardKey key) {
    final bool opens =
        _isActivateKey(key) ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.arrowDown;
    if (!opens) return KeyEventResult.ignored;

    _toggleMenu(keyboard: true);

    return KeyEventResult.handled;
  }

  KeyEventResult _onOpenKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(_enabledIndexFrom(_hoveredIndex, 1));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(
        _enabledIndexFrom(
          _hoveredIndex < 0 ? _filteredOptions.length : _hoveredIndex,
          -1,
        ),
      );
    } else if (key == LogicalKeyboardKey.escape) {
      _closeMenu(restoreFocus: true);
    } else if (_isActivateKey(key)) {
      _selectHighlighted();
    } else if (widget.searchable) {
      // Space types a space and Home/End move the caret in the search field.
      return KeyEventResult.ignored;
    } else if (key == LogicalKeyboardKey.space) {
      _selectHighlighted();
    } else if (key == LogicalKeyboardKey.home) {
      _moveHighlight(_enabledIndexFrom(-1, 1));
    } else if (key == LogicalKeyboardKey.end) {
      _moveHighlight(_enabledIndexFrom(_filteredOptions.length, -1));
    } else {
      return KeyEventResult.ignored;
    }

    return KeyEventResult.handled;
  }

  void _selectHighlighted() {
    if (_isSearching ||
        _hoveredIndex < 0 ||
        _hoveredIndex >= _filteredOptions.length) {
      return;
    }

    _selectOption(_filteredOptions[_hoveredIndex], restoreFocus: true);
  }

  /// Moves the highlight to [index] and scrolls its row into view. A -1 (no
  /// enabled option in that direction) leaves the highlight where it is, so it
  /// stops at the ends rather than wrapping.
  void _moveHighlight(int index) {
    // While a search is in flight the spinner hides rows that still sit in
    // `_filteredOptions`, and a key must not land on one of them.
    if (_isSearching || index == -1 || index == _hoveredIndex) return;

    setState(() {
      final bool downward = index > _hoveredIndex;
      _hoveredIndex = index;
      _requestReveal(index, downward: downward);
    });
    _scheduleReveal();
  }

  /// Starts a reveal of the row at [index] (none for -1). Called inside a
  /// `setState`, so the rebuild it triggers has every live row report itself.
  void _requestReveal(int index, {required bool downward}) {
    _revealIndex = index;
    _revealDownward = downward;
    _revealPending = index >= 0;
    _revealJumped = false;
    _revealStep = 0;
    _revealRows.clear();
  }

  void _endReveal() {
    _revealPending = false;
    _revealRows.clear();
  }

  /// Queues one reveal attempt for after the next frame, once per frame.
  void _scheduleReveal() {
    if (_revealScheduled) return;

    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      _revealHighlight();
    });
  }

  /// Scrolls the highlighted row into view once the frame that built it ran.
  ///
  /// A row the list has not built yet has no context to reveal. The first miss
  /// jumps to a proportional offset, which lands on or near the row when rows
  /// share a height; every later miss scrolls one viewport toward the row and
  /// tries again on the next frame. The built rows say which way the row lies,
  /// so variable-height rows only cost more steps. The walk ends once the row
  /// is revealed, once the target is gone (menu closed, highlight moved, list
  /// shortened), or once a step cannot move the list or would turn back, so it
  /// is bounded by real scroll progress rather than a retry count.
  void _revealHighlight() {
    if (!mounted || !_revealPending) return;

    // 1. The request outlived its target.
    if (!_isOpen ||
        _revealIndex != _hoveredIndex ||
        _revealIndex >= _filteredOptions.length ||
        !_scrollController.hasClients) {
      _endReveal();

      return;
    }

    // 2. The row is built, so it can be revealed exactly.
    _revealRows.removeWhere((_, BuildContext row) => !row.mounted);
    final BuildContext? row = _revealRows[_revealIndex];
    if (row != null) {
      Scrollable.ensureVisible(
        row,
        duration: Duration.zero,
        alignmentPolicy: _revealDownward
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
      _endReveal();

      return;
    }

    // 3. Move the list toward the row and look again on the next frame.
    final ScrollPosition position = _scrollController.position;
    double? next = _revealJumped ? null : _proportionalRevealOffset(position);
    _revealJumped = true;
    if (next == null || next == position.pixels) {
      next = _stepRevealOffset(position);
    }
    if (next == null || next == position.pixels) {
      _endReveal();

      return;
    }

    _scrollController.jumpTo(next);
    _scheduleReveal();
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// The offset the target would sit at if every row shared one height.
  double? _proportionalRevealOffset(ScrollPosition position) {
    final int count = _filteredOptions.length;
    if (count < 2) return null;

    return (position.maxScrollExtent * _revealIndex / (count - 1)).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  /// One viewport toward the target, judged from the rows that are built, or
  /// null when no built row says which way it lies or the walk would turn
  /// back on itself (the list moved under it).
  double? _stepRevealOffset(ScrollPosition position) {
    if (_revealRows.isEmpty) return null;

    int first = _revealRows.keys.first;
    int last = first;
    for (final int index in _revealRows.keys) {
      if (index < first) first = index;
      if (index > last) last = index;
    }

    final int step = _revealIndex > last
        ? 1
        : _revealIndex < first
        ? -1
        : 0;
    if (step == 0 || (_revealStep != 0 && step != _revealStep)) return null;

    _revealStep = step;

    return (position.pixels + step * position.viewportDimension).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  void _toggleMultiSelection(SelectOption<T> option) {
    final currentValues = List<T>.from(widget.values ?? []);
    final isSelected = currentValues.contains(option.value);

    if (isSelected) {
      currentValues.remove(option.value);
    } else {
      currentValues.add(option.value);
    }

    widget.onMultiChange?.call(currentValues);
    // Don't close menu in multi-select
  }

  void _removeValue(T value) {
    final currentValues = List<T>.from(widget.values ?? []);
    currentValues.remove(value);
    widget.onMultiChange?.call(currentValues);
  }

  /// Deferred setState for hovering to avoid mouse_tracker conflicts
  void _setHovering(bool value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isHovering != value) {
        setState(() => _isHovering = value);
      }
    });
  }

  /// Deferred setState for hovered index to avoid mouse_tracker conflicts
  void _setHoveredIndex(int value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hoveredIndex != value) {
        setState(() => _hoveredIndex = value);
      }
    });
  }

  Future<void> _createOption() async {
    if (widget.onCreateOption == null || _searchQuery.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final newOption = await widget.onCreateOption!(_searchQuery);
      if (mounted) {
        _selectOption(newOption);
        setState(() {
          _searchQuery = '';
          _isCreating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  /// Filters the visible list by [query].
  ///
  /// A typed query starts the highlight over. [highlighted] is the option a
  /// re-filter under the unchanged query keeps highlighted, found by value in
  /// the new list (none when it dropped out of it).
  Future<void> _filterOptions(
    String query, {
    SelectOption<T>? highlighted,
  }) async {
    _searchQuery = query;

    if (widget.onSearch != null) {
      final int epoch = _listEpoch;

      setState(() {
        _isSearching = true;
        _hoveredIndex = -1;
      });
      try {
        final results = await widget.onSearch!(query);
        if (mounted && epoch == _listEpoch && _searchQuery == query) {
          setState(() {
            _filteredOptions = results;
            _hoveredIndex = _indexOfOption(results, highlighted);
            _isSearching = false;
          });
        }
      } catch (_) {
        // Guarded like the success path, and for the same reason: a request
        // that fails after a newer one went out, or after the list was
        // replaced, no longer owns this flag. Lowering it anyway dropped the
        // spinner while the newer search was still in flight, leaving the
        // pre-search list on screen looking settled until it landed.
        if (mounted && epoch == _listEpoch && _searchQuery == query) {
          setState(() => _isSearching = false);
        }
      }
    } else {
      // Local filtering
      setState(() {
        if (query.isEmpty) {
          _filteredOptions = widget.options;
        } else {
          _filteredOptions = widget.options
              .where(
                (opt) => opt.label.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
        }
        _hoveredIndex = _indexOfOption(_filteredOptions, highlighted);
      });
    }
  }

  SelectOption<T>? get _selectedOption {
    if (widget.value == null) return null;
    try {
      return widget.options.firstWhere((opt) => opt.value == widget.value);
    } catch (_) {
      return null;
    }
  }

  List<SelectOption<T>> get _selectedOptions {
    if (widget.values == null || widget.values!.isEmpty) return [];
    return widget.options
        .where((opt) => widget.values!.contains(opt.value))
        .toList();
  }

  bool _isValueSelected(T value) {
    if (widget.isMulti) {
      return widget.values?.contains(value) ?? false;
    }
    return widget.value == value;
  }

  /// Resolves the Semantics label for the closed-trigger state.
  ///
  /// The name follows the trigger's visible text: the selected option's label
  /// (labels joined with ', ' for a multi select), and the `placeholder` only
  /// while nothing is selected. An empty placeholder with no selection leaves
  /// the trigger unnamed (`null`).
  String? _resolveSemanticsLabel() {
    final String? selectedLabel = widget.isMulti
        ? _selectedOptions.map((SelectOption<T> opt) => opt.label).join(', ')
        : _selectedOption?.label;

    if (selectedLabel != null && selectedLabel.isNotEmpty) {
      return selectedLabel;
    }

    return widget.placeholder.isEmpty ? null : widget.placeholder;
  }

  @override
  Widget build(BuildContext context) {
    WindPerfCounters.recordWidgetBuild('WSelect');

    // Accessibility: the closed trigger is ONE `button` SemanticsNode labelled
    // with the selected option label (the placeholder while nothing is
    // selected), so Playwright `getByRole('button', { name: ... })` resolves on
    // the collapsed dropdown and a screen reader announces it once.
    //
    // The previous shape wrapped a MergeSemantics inside this `container`
    // node. A container is a boundary, so the merge became a SECOND boundary
    // instead of folding up: the outer node had the label and button flag but
    // no action, the inner one the merged text, the tap and the focus. Both are
    // sent to the platform (neither is `isMergedIntoParent`), so the control
    // was announced twice and an agent could pick the action-less one.
    //
    // Now the outer node carries everything and `ExcludeSemantics` drops the
    // trigger subtree below it, the explicit-label path of `WAnchor`
    // (`w_anchor.dart`). The tap is lifted onto this node because the excluded
    // GestureDetector's own action goes with it; it is absent when disabled.
    // `Focus` sits OUTSIDE the exclusion so its `focusable` / `focused` /
    // `onFocus` still merge into this node, which is why the exclusion is a
    // widget of its own instead of `excludeSemantics:` on this `Semantics`.
    //
    // Nothing a user can reach is lost. The multi select chips (and their
    // remove taps) and a custom `triggerBuilder`'s content were already
    // merged into the inner node and never published on their own, and the
    // search field lives in the OverlayPortal overlay, a separate subtree this
    // exclusion does not touch.
    return Semantics(
      container: true,
      button: true,
      enabled: !widget.disabled,
      label: _resolveSemanticsLabel(),
      onTap: widget.disabled ? null : _toggleMenu,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: _buildOverlay,
        child: CompositedTransformTarget(
          link: _layerLink,
          child: Focus(
            focusNode: _focusNode,
            onKeyEvent: _onKeyEvent,
            canRequestFocus: !widget.disabled,
            // A custom trigger can carry its own focus node.
            descendantsAreFocusable: !widget.disabled,
            child: ExcludeSemantics(
              child: KeyedSubtree(
                key: _triggerKey,
                child: _buildTrigger(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrigger(BuildContext context) {
    // Custom trigger builders. Tag them with the shared tap group too, so the
    // open menu's onTapOutside ignores the tap that lands on a custom trigger
    // (a bare GestureDetector would be seen as an outside tap and self-close).
    if (widget.isMulti && widget.multiTriggerBuilder != null) {
      return TapRegion(
        groupId: _tapGroupId,
        child: GestureDetector(
          onTap: _toggleMenu,
          child: MouseRegion(
            onEnter: (_) => _setHovering(true),
            onExit: (_) => _setHovering(false),
            cursor: widget.disabled
                ? SystemMouseCursors.forbidden
                : SystemMouseCursors.click,
            child: widget.multiTriggerBuilder!(
              context,
              _selectedOptions,
              _isOpen,
            ),
          ),
        ),
      );
    }

    if (!widget.isMulti && widget.triggerBuilder != null) {
      return TapRegion(
        groupId: _tapGroupId,
        child: GestureDetector(
          onTap: _toggleMenu,
          child: MouseRegion(
            onEnter: (_) => _setHovering(true),
            onExit: (_) => _setHovering(false),
            cursor: widget.disabled
                ? SystemMouseCursors.forbidden
                : SystemMouseCursors.click,
            child: widget.triggerBuilder!(context, _selectedOption, _isOpen),
          ),
        ),
      );
    }

    // Build active states (auto-managed states + user's custom states)
    final bool hasSelection = widget.isMulti
        ? (widget.values?.isNotEmpty ?? false)
        : widget.value != null;

    final bool isFocused = !widget.disabled && (_isOpen || _hasKeyboardFocus);

    final Set<String> activeStates = {
      ...?widget.states,
      if (widget.disabled) 'disabled',
      if (_isHovering) 'hover',
      if (isFocused) 'focus',
      if (_isOpen) 'open',
      if (hasSelection) 'selected',
    };

    final String triggerClassName =
        widget.className ??
        '''
          bg-white dark:bg-gray-800
          border border-gray-300 dark:border-gray-600
          rounded-lg p-3
        ''';

    // Logger integration
    final styles = WindParser.parse(
      triggerClassName,
      context,
      states: activeStates,
    );
    final logger = WindLogger(
      debug: styles.debug,
      widgetName: "WSelect (Trigger)",
    );

    if (styles.debug) {
      logger.logStep("ClassName", "'$triggerClassName'");
      logger.setCoreWidget("WDiv -> Trigger Content");
      logger.printFinalCode();
    }

    // Default trigger rendering. Tag it with the shared tap group so the open
    // menu's onTapOutside ignores the tap that opened it.
    return TapRegion(
      groupId: _tapGroupId,
      child: GestureDetector(
        onTap: _toggleMenu,
        child: MouseRegion(
          onEnter: (_) => _setHovering(true),
          onExit: (_) => _setHovering(false),
          cursor: widget.disabled
              ? SystemMouseCursors.forbidden
              : SystemMouseCursors.click,
          // A `focus:` class makes the trigger div wrap itself in a WAnchor,
          // and with no provider above it that anchor became a second Tab
          // stop, one that a disabled select kept. Publishing this trigger's
          // state makes it inherit instead of competing for focus.
          child: WindAnchorStateProvider(
            state: WindAnchorState(
              isHovering: _isHovering,
              isFocused: isFocused,
              hasPrimaryFocus: isFocused,
              isDisabled: widget.disabled,
            ),
            child: WDiv(
              className: triggerClassName,
              states: activeStates,
              children: [
                WDiv(
                  className: 'flex items-center gap-2',
                  children: [
                    WDiv(
                      className: 'flex-1',
                      child: widget.isMulti
                          ? _buildMultiSelectTriggerContent()
                          : _buildSingleSelectTriggerContent(),
                    ),
                    Icon(
                      _isOpen
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: _paired(
                        light: Colors.grey.shade600,
                        dark: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleSelectTriggerContent() {
    final textColor = _selectedOption != null
        ? 'text-gray-800 dark:text-gray-100'
        : 'text-gray-400 dark:text-gray-500';
    return WText(
      _selectedOption?.label ?? widget.placeholder,
      className: '$textColor truncate',
    );
  }

  Widget _buildMultiSelectTriggerContent() {
    if (_selectedOptions.isEmpty) {
      return WText(
        widget.placeholder,
        className: 'text-gray-400 dark:text-gray-500 truncate',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: WDiv(
        className: 'flex gap-1',
        children: _selectedOptions.map((opt) {
          if (widget.selectedChipBuilder != null) {
            return widget.selectedChipBuilder!(
              context,
              opt,
              () => _removeValue(opt.value),
            );
          }
          return _buildDefaultChip(opt);
        }).toList(),
      ),
    );
  }

  Widget _buildDefaultChip(SelectOption<T> option) {
    return WDiv(
      className: '''
        flex items-center gap-1 bg-primary-100 dark:bg-primary-900/40
        rounded px-2 py-0.5
      ''',
      children: [
        WText(
          option.label,
          className: 'text-primary-800 dark:text-primary-200 text-sm',
        ),
        GestureDetector(
          onTap: () => _removeValue(option.value),
          child: Icon(
            Icons.close,
            size: 14,
            color: _paired(light: _primaryShade(700), dark: _primaryShade(300)),
          ),
        ),
      ],
    );
  }

  /// The menu surface for the active brightness. Parsed rather than hard-coded
  /// so the light colour stays the theme's white and the dark one its gray 800.
  Color get _menuSurface =>
      WindParser.parse('bg-white dark:bg-gray-800', context).decoration!.color!;

  /// The decoration of the open menu.
  ///
  /// A user [parsed] decoration with a background (colour or gradient) wins
  /// untouched. One without (radius or shadow only) gets the default surface,
  /// and none at all gets the full default box.
  BoxDecoration _menuDecoration(
    BoxDecoration? parsed,
    BorderRadius borderRadius,
  ) {
    if (parsed != null) {
      return parsed.color == null && parsed.gradient == null
          ? parsed.copyWith(color: _menuSurface)
          : parsed;
    }

    return BoxDecoration(
      color: _menuSurface,
      border: Border.all(
        color: _paired(
          light: Colors.grey.shade200,
          dark: context.windColors['gray']?[700] ?? Colors.grey.shade700,
        ),
      ),
      borderRadius: borderRadius,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: context.windIsDark ? 0.4 : 0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final RenderBox? triggerBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final double triggerWidth = triggerBox?.size.width ?? 200;

    final WindStyle menuStyles = widget.menuClassName != null
        ? WindParser.parse(widget.menuClassName!, context)
        : const WindStyle();

    final double menuWidth =
        widget.menuWidth ?? menuStyles.width ?? triggerWidth;
    final double maxHeight =
        menuStyles.constraints?.maxHeight ?? widget.maxMenuHeight;
    final BorderRadius borderRadius =
        (menuStyles.decoration?.borderRadius as BorderRadius?) ??
        BorderRadius.circular(8);

    // Logger integration for Menu
    final logger = WindLogger(
      debug: menuStyles.debug,
      widgetName: "WSelect (Menu)",
    );

    if (menuStyles.debug) {
      logger.logStep("Menu ClassName", "'${widget.menuClassName}'");
      logger.setCoreWidget("OverlayPortal -> Container -> Column");
      logger.printFinalCode();
    }

    // The follower is anchored to the trigger's left edge, so a menu wider than
    // the room to the right of the trigger would run off the window. The same
    // clamp WPopover applies pulls it back 8px inside the edge.
    final Offset baseOffset = Offset(0, _openUpward ? -4 : 4);
    final double dx = triggerBox != null && triggerBox.hasSize
        ? computeHorizontalClamp(
            alignment: _openUpward
                ? PopoverAlignment.topLeft
                : PopoverAlignment.bottomLeft,
            triggerPosition: triggerBox.localToGlobal(Offset.zero),
            triggerSize: triggerBox.size,
            popoverWidth: menuWidth,
            screenSize: MediaQuery.sizeOf(context),
            offset: baseOffset,
          )
        : 0;

    return CompositedTransformFollower(
      link: _layerLink,
      targetAnchor: _openUpward ? Alignment.topLeft : Alignment.bottomLeft,
      followerAnchor: _openUpward ? Alignment.bottomLeft : Alignment.topLeft,
      offset: Offset(dx, baseOffset.dy),
      child: Align(
        alignment: _openUpward ? Alignment.bottomLeft : Alignment.topLeft,
        widthFactor: 1,
        heightFactor: 1,
        child: TapRegion(
          groupId: _tapGroupId,
          onTapOutside: (_) => _closeMenu(),
          // The overlay is a sibling of the trigger's Focus, so a key from the
          // focused search field never bubbles through the trigger. This one
          // takes no focus and only catches what the field leaves unhandled.
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _onKeyEvent,
            child: Material(
              elevation: 0,
              color: Colors.transparent,
              child: Container(
                width: menuWidth,
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: _menuDecoration(
                  menuStyles.decoration,
                  borderRadius,
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: WDiv(
                    className: 'flex flex-col',
                    children: [
                      if (widget.searchable) _buildSearchInput(),
                      Flexible(child: _buildOptionsContent()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return WDiv(
      className: 'p-2',
      child: WInput(
        placeholder: widget.searchPlaceholder,
        autofocus: true,
        className:
            'p-2 border border-gray-300 dark:border-gray-600 rounded text-sm',
        onChanged: _filterOptions,
      ),
    );
  }

  Widget _buildOptionsContent() {
    if (_isSearching) {
      return widget.loadingBuilder?.call(context) ?? _buildLoadingIndicator();
    }

    if (_filteredOptions.isEmpty) {
      return WDiv(
        className: 'flex flex-col',
        children: [
          widget.emptyBuilder?.call(context, _searchQuery) ??
              _buildEmptyState(),
          if (widget.onCreateOption != null && _searchQuery.isNotEmpty)
            _buildCreateButton(),
        ],
      );
    }

    return _buildOptionsList();
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return WDiv(
      className: 'p-4',
      child: WText(
        'No options found',
        className: 'text-gray-500 dark:text-gray-400',
      ),
    );
  }

  Widget _buildCreateButton() {
    if (widget.createOptionBuilder != null) {
      return widget.createOptionBuilder!(context, _searchQuery, _createOption);
    }

    return GestureDetector(
      onTap: _isCreating ? null : _createOption,
      child: WDiv(
        className: '''
          w-full flex items-center gap-2 px-3 py-2
          hover:bg-gray-50 dark:hover:bg-slate-700
        ''',
        children: [
          if (_isCreating)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.add, size: 16, color: _primaryShade(400)),
          WText(
            'Create "$_searchQuery"',
            className: 'text-primary-500 dark:text-primary-400 font-medium',
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsList() {
    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _filteredOptions.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading at bottom for pagination
        if (index == _filteredOptions.length) {
          return _buildLoadingIndicator();
        }

        final option = _filteredOptions[index];
        final isSelected = _isValueSelected(option.value);
        final isHovered = index == _hoveredIndex;

        final Widget row = _buildOptionItem(
          option,
          isSelected,
          isHovered,
          index,
        );

        // Every row gets the same wrapper, so the one being revealed keeps its
        // element (and any state its `itemBuilder` row holds) as the highlight
        // moves on.
        return Builder(
          builder: (BuildContext rowContext) {
            if (_revealPending) _revealRows[index] = rowContext;

            return row;
          },
        );
      },
    );
  }

  Widget _buildOptionItem(
    SelectOption<T> option,
    bool isSelected,
    bool isHovered,
    int index,
  ) {
    if (widget.itemBuilder != null) {
      return GestureDetector(
        onTap: () => _selectOption(option),
        child: MouseRegion(
          onEnter: (_) => _setHoveredIndex(index),
          onExit: (_) => _setHoveredIndex(-1),
          cursor: option.disabled
              ? SystemMouseCursors.forbidden
              : SystemMouseCursors.click,
          child: widget.itemBuilder!(context, option, isSelected, isHovered),
        ),
      );
    }

    // The resting arm carries no class rather than `bg-transparent`. Both paint
    // nothing, but a resolved transparent colour is still a colour: it builds a
    // `BoxDecoration`, which trips `WDiv`'s `needsContainer` and wraps every
    // unselected option in a `DecoratedBox` that paints nothing, once per row
    // for the length of the list.
    final String bgClass = isSelected
        ? 'bg-primary-50 dark:bg-primary-900/30'
        : isHovered
        ? 'bg-gray-100 dark:bg-slate-700'
        : '';
    final String textColorClass = option.disabled
        ? 'text-gray-400 dark:text-gray-500'
        : isSelected
        ? 'text-primary-700 dark:text-primary-300 font-medium'
        : 'text-gray-800 dark:text-gray-200';

    return WindAnchorStateProvider(
      state: WindAnchorState(
        isHovering: isHovered,
        isFocused: false,
        isDisabled: option.disabled,
      ),
      child: GestureDetector(
        onTap: () => _selectOption(option),
        child: MouseRegion(
          onEnter: (_) => _setHoveredIndex(index),
          onExit: (_) => _setHoveredIndex(-1),
          cursor: option.disabled
              ? SystemMouseCursors.forbidden
              : SystemMouseCursors.click,
          child: WDiv(
            className: 'flex items-center gap-2 px-3 py-2 $bgClass',
            children: [
              if (widget.isMulti)
                Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: isSelected
                      ? _paired(
                          light: _primaryShade(600),
                          dark: _primaryShade(400),
                        )
                      : _paired(
                          light: Colors.grey.shade400,
                          dark: Colors.grey.shade600,
                        ),
                ),
              if (option.icon != null) option.icon!,
              WDiv(
                className: 'flex-1',
                child: WText(option.label, className: textColorClass),
              ),
              if (!widget.isMulti && isSelected)
                Icon(
                  Icons.check,
                  size: 18,
                  color: _paired(
                    light: _primaryShade(600),
                    dark: _primaryShade(400),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
