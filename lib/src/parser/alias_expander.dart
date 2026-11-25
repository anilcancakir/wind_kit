/// Maximum expansion depth before resolution stops.
///
/// Eight levels cover any realistic alias chain (an alias whose value is an
/// alias whose value is an alias, etc.); a deeper chain almost certainly means
/// a misconfiguration, so the cap is a backstop alongside the per-chain cycle
/// guard rather than the primary termination mechanism.
const int _maxExpansionDepth = 8;

/// Maximum number of expanded output tokens before expansion stops.
///
/// The depth cap and cycle guard bound chain LENGTH, not branching WIDTH: an
/// acyclic map whose values each reference several further multi-token aliases
/// (`{a: 'b b', b: 'c c', ...}`) fans out as O(width^depth) and would still
/// blow up under the depth cap alone. This total-output budget bounds the
/// worst case to a constant regardless of map shape. A real className carries
/// at most a few dozen utility tokens, so the cap sits far above any legitimate
/// use. On exhaustion the remaining tokens are dropped and [onWarn] fires once;
/// the function never throws.
const int _maxOutputTokens = 256;

/// The two `/N` opacity suffix forms the colour parsers read: an integer
/// percentage (`50`) or a bracketed fraction (`[0.5]`).
final RegExp _opacitySuffix = RegExp(r'^(?:[0-9]+|\[[0-9]*\.?[0-9]+\])$');

/// Expands user-defined className aliases into their underlying tokens.
///
/// This is a PURE function: a className string plus an alias map go in, an
/// expanded className string comes out. It imports no parser, theme, or Flutter
/// symbols so it can be unit-tested in isolation.
///
/// ### Behavior
///
/// - When [aliases] is empty, the input is returned unchanged (zero-cost fast
///   path; the hot rendering path pays nothing when no aliases are configured).
/// - Otherwise the className is split on whitespace and each token is expanded
///   independently. Alias keys are always BARE (no prefix); the lookup matches
///   a token's bare body, not the prefix chain. An unprefixed token matches a
///   key directly (`row` -> key `row`). A prefixed token has its prefix chain
///   peeled off, its bare body matched against the map, and on a hit the outer
///   prefix is re-applied to every produced token (`md:row` ->
///   `md:flex md:flex-row`; `hover:bg-surface` -> the surface alias' tokens
///   each carrying `hover:`). Prefix order is irrelevant to the parser, so a
///   `hover:` re-applied over a value's own `dark:` yields `hover:dark:...`.
///   The replacement is the alias value's own tokens, which may themselves
///   contain prefixes or further aliases and are expanded recursively.
/// - Token order and duplicates are preserved (no dedup); the parser is
///   last-class-wins, so dropping a trailing duplicate would change semantics.
///   Two independent occurrences of the same alias both expand.
///
/// ### Opacity modifier
///
/// With [isColorClass] set, a token `<alias>/<N>` (N an integer or a bracketed
/// fraction such as `[0.5]`) expands the alias and appends `/N` to every colour
/// class it produces, prefixed peers and nested aliases included
/// (`bg-brand/50` over `{'bg-brand': 'bg-red-500 dark:bg-red-400'}` ->
/// `bg-red-500/50 dark:bg-red-400/50`). [isColorClass]
/// receives a class with its prefixes and its own `/M` stripped (`bg-red-500`)
/// and decides which produced classes are colours; other classes pass through
/// untouched. The outermost `/N` replaces any inner `/M`. An exact key that
/// itself contains `/` wins over this reading. When no produced class is a
/// colour the alias still expands, the `/N` is dropped and [onWarn] fires.
/// Without [isColorClass] an `<alias>/<N>` token is left verbatim.
///
/// ### Termination
///
/// Three independent guards bound the work:
/// - A per-chain visited-set: re-encountering a key already on the current
///   resolution chain (a self-cycle `a -> a` or a mutual cycle `a -> b -> a`)
///   leaves the token unexpanded instead of looping. A fresh chain copy is
///   passed down each branch so sibling occurrences of the same alias both
///   expand.
/// - [_maxExpansionDepth]: a depth backstop on chain LENGTH.
/// - [_maxOutputTokens]: a total-output budget on branching WIDTH, so a
///   fan-out map cannot explode the output exponentially.
///
/// On a cycle or depth-cap hit the offending token is kept verbatim; on a
/// budget hit the remaining tokens are dropped. Each guard invokes [onWarn]
/// (when provided, the budget warning once) with a diagnostic message. The
/// function never throws.
///
/// ### Example
///
/// ```dart
/// expandAliases('row-c', {'row': 'flex flex-row', 'row-c': 'row items-center'});
/// // -> 'flex flex-row items-center'
/// ```
String expandAliases(
  String className,
  Map<String, String> aliases, {
  void Function(String message)? onWarn,
  bool Function(String bareClass)? isColorClass,
}) {
  // Fast path: no aliases configured, nothing to expand.
  if (aliases.isEmpty) {
    return className;
  }

  final out = <String>[];
  // The budget warning fires at most once per call; it is shared across the
  // whole recursion via this closure, which is why expansion is a nested
  // function rather than a top-level one.
  var budgetWarned = false;
  // Leaf tokens that received an alias opacity so far; an alias compares it
  // before and after its expansion to tell whether its `/N` landed anywhere.
  var opacityApplied = 0;

  void expand(String token, Set<String> chain, int depth, String? opacity) {
    // Output budget: stop once the total token count is reached so an acyclic
    // fan-out map cannot grow the output without bound. Warn once.
    if (out.length >= _maxOutputTokens) {
      if (!budgetWarned) {
        budgetWarned = true;
        onWarn?.call(
          'Wind alias expansion exceeded the $_maxOutputTokens-token budget; '
          'remaining tokens were dropped.',
        );
      }
      return;
    }

    // Peel any prefix chain (everything up to and including the LAST ':') off
    // the token; alias keys are always bare, so only the body can match. A
    // prefixed token whose body is an alias expands the body and re-applies the
    // prefix to each produced token, so hover:bg-surface and md:row resolve
    // instead of silently passing through. An unprefixed token has an empty
    // prefix and matches directly.
    final colon = token.lastIndexOf(':');
    final String prefix = colon == -1 ? '' : token.substring(0, colon + 1);
    final String body = colon == -1 ? token : token.substring(colon + 1);

    // Exact lookup first, so a key that itself contains '/' wins. Only on a
    // miss, and only when colour classes can be told apart, is the body read
    // as `<alias>/<N>`.
    var key = body;
    String? ownOpacity;
    var replacement = aliases[body];
    if (replacement == null && isColorClass != null) {
      final split = _splitOpacity(body);
      final aliased = split.opacity == null ? null : aliases[split.base];
      if (aliased != null) {
        key = split.base;
        ownOpacity = split.opacity;
        replacement = aliased;
      }
    }

    // Not an alias key (unknown bare token, or a prefixed token whose body is
    // not an alias key): keep the ORIGINAL token verbatim, unless an enclosing
    // alias carries an opacity and this is a colour class, which then takes
    // that opacity in place of its own.
    if (replacement == null) {
      if (opacity != null && isColorClass != null) {
        final base = _splitOpacity(body).base;
        if (isColorClass(base)) {
          opacityApplied++;
          out.add('$prefix$base/$opacity');
          return;
        }
      }
      out.add(token);
      return;
    }

    // Cycle guard: this key is already on the current resolution chain.
    if (chain.contains(key)) {
      onWarn?.call("Wind alias '$key' forms a cycle; left unexpanded.");
      out.add(token);
      return;
    }

    // Cap guard: chain deeper than the backstop allows.
    if (depth >= _maxExpansionDepth) {
      onWarn?.call(
        "Wind alias '$key' exceeds the $_maxExpansionDepth-level "
        'expansion cap; left unexpanded.',
      );
      out.add(token);
      return;
    }

    // The outermost opacity wins over this token's own `/N`.
    final effectiveOpacity = opacity ?? ownOpacity;
    final appliedBefore = opacityApplied;
    final nextChain = {...chain, key};
    for (final inner in _tokenize(replacement)) {
      // Re-apply the outer prefix (if any) to each produced token. Prefix order
      // is irrelevant to the parser, so hover: over a value's dark: becomes
      // hover:dark:... and still resolves.
      expand(
        prefix.isEmpty ? inner : '$prefix$inner',
        nextChain,
        depth + 1,
        effectiveOpacity,
      );
    }

    // Warn where the opacity originated: a nested alias handed an outer `/N`
    // is not the token the user wrote it on.
    if (opacity == null &&
        ownOpacity != null &&
        opacityApplied == appliedBefore) {
      onWarn?.call(
        "Wind alias '$key' has no colour class; its '/$ownOpacity' opacity "
        'was ignored.',
      );
    }
  }

  for (final token in _tokenize(className)) {
    expand(token, <String>{}, 0, null);
  }

  return out.join(' ');
}

/// Splits a bare class into its base and a valid `/N` opacity suffix.
///
/// A class without a suffix, or whose text after the last '/' is not one of
/// the two opacity forms (`w-1/2` keeps `2`, but `bg-a/abc` does not match),
/// returns the class unchanged as the base and a null opacity.
({String base, String? opacity}) _splitOpacity(String bareClass) {
  final slash = bareClass.lastIndexOf('/');
  if (slash <= 0) {
    return (base: bareClass, opacity: null);
  }

  final suffix = bareClass.substring(slash + 1);
  if (!_opacitySuffix.hasMatch(suffix)) {
    return (base: bareClass, opacity: null);
  }

  return (base: bareClass.substring(0, slash), opacity: suffix);
}

/// Splits a className string on whitespace, dropping empty fragments.
///
/// Mirrors WindParser.findAndGroupClasses so multiline / multi-space input
/// tokenizes identically on both sides.
Iterable<String> _tokenize(String value) =>
    value.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
