import 'package:flutter_test/flutter_test.dart';
import 'package:wind_kit/src/parser/alias_expander.dart';

void main() {
  group('expandAliases', () {
    test('returns the input unchanged when the alias map is empty', () {
      expect(expandAliases('flex p-4', const {}), 'flex p-4');
    });

    test('expands a single alias into its tokens', () {
      expect(
        expandAliases('row', const {'row': 'flex flex-row'}),
        'flex flex-row',
      );
    });

    test(
      'expands recursively when an alias value references another alias',
      () {
        final result = expandAliases('row-c', const {
          'row': 'flex flex-row',
          'row-c': 'row items-center',
        });

        expect(result, 'flex flex-row items-center');
      },
    );

    test('terminates on a self-cycle without hanging', () {
      // A self-referential alias must not loop; the offending token is left
      // unexpanded once it is detected as already visited.
      expect(expandAliases('a', const {'a': 'a'}), 'a');
    });

    test('terminates on a mutual cycle without hanging', () {
      // a -> b -> a forms a loop; 'a' expands to 'b', 'b' expands back to 'a'
      // which is already on the chain, so the repeated 'a' is left verbatim.
      expect(expandAliases('a', const {'a': 'b', 'b': 'a'}), 'a');
    });

    test('passes an unknown token through unchanged', () {
      expect(expandAliases('foo', const {'row': 'flex flex-row'}), 'foo');
    });

    test('expands a prefixed token whose body is an alias, re-applying the '
        'prefix to each produced token', () {
      // The prefix is peeled off, the bare body matches the key, and the prefix
      // is re-applied to every produced token (#124).
      expect(
        expandAliases('md:row', const {'row': 'flex flex-row'}),
        'md:flex md:flex-row',
      );
    });

    test('re-applies a state prefix across an alias value that has its own '
        'dark pair', () {
      // hover:bg-surface -> the surface alias tokens, each carrying hover:.
      // hover: over the value's dark: yields hover:dark:..., which the parser
      // resolves regardless of prefix order.
      expect(
        expandAliases('hover:bg-surface', const {
          'bg-surface': 'bg-gray-100 dark:bg-gray-800',
        }),
        'hover:bg-gray-100 hover:dark:bg-gray-800',
      );
    });

    test('expands a stacked-prefix token through an alias', () {
      expect(
        expandAliases('dark:hover:row', const {'row': 'flex flex-row'}),
        'dark:hover:flex dark:hover:flex-row',
      );
    });

    test('detects a cycle reached through a prefixed token', () {
      // a -> hover:a re-enters key 'a' on the chain; the repeat is left as the
      // original prefixed token rather than looping.
      final warnings = <String>[];
      final result = expandAliases('a', const {
        'a': 'hover:a',
      }, onWarn: warnings.add);
      expect(result, 'hover:a');
      expect(warnings.any((w) => w.contains('cycle')), isTrue);
    });

    test('leaves a prefixed token verbatim when its body is not an alias', () {
      expect(
        expandAliases('hover:bg-blue-500', const {'row': 'flex flex-row'}),
        'hover:bg-blue-500',
      );
    });

    test('never expands a prefixed token even when a prefixed key exists', () {
      // A prefixed token is ineligible regardless of the map: a `md:row` key is
      // not bare, so the bare-token contract leaves the token unexpanded.
      expect(
        expandAliases('md:row', const {'md:row': 'flex flex-row'}),
        'md:row',
      );
    });

    test('passes a prefixed token inside an alias value through as-is', () {
      expect(
        expandAliases('card', const {'card': 'dark:bg-gray-900'}),
        'dark:bg-gray-900',
      );
    });

    test('preserves duplicate tokens and their order (no dedup)', () {
      expect(expandAliases('p-2 p-4 p-2', const {}), 'p-2 p-4 p-2');
    });

    test('preserves order when expanding alongside non-alias tokens', () {
      expect(
        expandAliases('p-4 row m-2', const {'row': 'flex flex-row'}),
        'p-4 flex flex-row m-2',
      );
    });

    test('invokes onWarn when a cycle is detected', () {
      final warnings = <String>[];

      expandAliases('a', const {'a': 'a'}, onWarn: warnings.add);

      expect(warnings, hasLength(1));
      expect(warnings.single, contains('cycle'));
    });

    test('stops at the depth cap on an acyclic chain longer than the cap', () {
      // A non-cyclic chain (every link is a distinct key, so the per-chain
      // visited-set never trips) longer than the cap exercises the depth
      // backstop: resolution stops, leaves the deep token unexpanded, and warns.
      // The chain length (12) must stay greater than _maxExpansionDepth (8) for
      // this test to keep hitting the cap branch; widen it if the cap is raised.
      const chain = {
        'a1': 'a2',
        'a2': 'a3',
        'a3': 'a4',
        'a4': 'a5',
        'a5': 'a6',
        'a6': 'a7',
        'a7': 'a8',
        'a8': 'a9',
        'a9': 'a10',
        'a10': 'a11',
        'a11': 'a12',
        'a12': 'leaf',
      };
      final warnings = <String>[];

      final result = expandAliases('a1', chain, onWarn: warnings.add);

      // The cap trips before the chain resolves to its 'leaf' tail; the
      // offending token is kept verbatim rather than expanded further.
      expect(result, isNot(contains('leaf')));
      expect(result.split(' '), hasLength(1));
      expect(warnings, isNotEmpty);
      expect(warnings.any((w) => w.contains('expansion cap')), isTrue);
    });

    test('bounds an acyclic fan-out map by the output-token budget', () {
      // The depth cap and cycle guard bound chain length, not branching width.
      // This map is acyclic (distinct keys) and each value fans out to 4 tokens,
      // so unbounded it would emit thousands of tokens. The output budget must
      // cap it and warn. The literal 256 mirrors the private _maxOutputTokens;
      // keep them in sync.
      const fanOut = {
        'a': 'b b b b',
        'b': 'c c c c',
        'c': 'd d d d',
        'd': 'e e e e',
        'e': 'f f f f',
        'f': 'leaf',
      };
      final warnings = <String>[];

      final result = expandAliases('a', fanOut, onWarn: warnings.add);

      // The budget caps the output (proving termination: an unbounded fan-out
      // would emit thousands of tokens) and warns. No wall-clock assertion: the
      // bounded count is the deterministic termination signal, not elapsed time.
      final tokens = result.split(' ').where((t) => t.isNotEmpty);
      expect(tokens.length, lessThanOrEqualTo(256));
      expect(warnings.any((w) => w.contains('budget')), isTrue);
    });
  });

  group('expandAliases opacity modifier', () {
    bool isColorClass(String bareClass) => bareClass.startsWith('bg-');

    test('appends the opacity to a one-colour alias (#324)', () {
      expect(
        expandAliases('bg-brand/50', const {
          'bg-brand': 'bg-red-500',
        }, isColorClass: isColorClass),
        'bg-red-500/50',
      );
    });

    test('appends the opacity to the dark peer of the expansion (#324)', () {
      expect(
        expandAliases('bg-surface/50', const {
          'bg-surface': 'bg-white dark:bg-gray-900',
        }, isColorClass: isColorClass),
        'bg-white/50 dark:bg-gray-900/50',
      );
    });

    test('keeps a state prefix on each token that receives the opacity '
        '(#324)', () {
      expect(
        expandAliases('hover:bg-surface/50', const {
          'bg-surface': 'bg-white dark:bg-gray-900',
        }, isColorClass: isColorClass),
        'hover:bg-white/50 hover:dark:bg-gray-900/50',
      );
    });

    test('appends the opacity only to the colour classes of a mixed alias '
        '(#324)', () {
      expect(
        expandAliases('chip/50', const {
          'chip': 'px-4 bg-blue-500',
        }, isColorClass: isColorClass),
        'px-4 bg-blue-500/50',
      );
    });

    test('replaces an inner opacity with the outer one (#324)', () {
      expect(
        expandAliases('bg-brand/50', const {
          'bg-brand': 'bg-red-500/30',
        }, isColorClass: isColorClass),
        'bg-red-500/50',
      );
    });

    test('passes the opacity down through a nested alias (#324)', () {
      const aliases = {'card': 'p-4 bg-brand/20', 'bg-brand': 'bg-red-500'};

      expect(
        expandAliases('card/50', aliases, isColorClass: isColorClass),
        'p-4 bg-red-500/50',
      );
      expect(
        expandAliases('card', aliases, isColorClass: isColorClass),
        'p-4 bg-red-500/20',
      );
    });

    test('prefers an exact key that contains a slash (#324)', () {
      expect(
        expandAliases('bg-brand/50', const {
          'bg-brand/50': 'bg-green-500',
          'bg-brand': 'bg-red-500',
        }, isColorClass: isColorClass),
        'bg-green-500',
      );
    });

    test('leaves an unknown alias with an opacity verbatim (#324)', () {
      expect(
        expandAliases('bg-nope/50', const {
          'bg-brand': 'bg-red-500',
        }, isColorClass: isColorClass),
        'bg-nope/50',
      );
    });

    test('leaves an alias with an opacity verbatim without a predicate '
        '(#324)', () {
      expect(
        expandAliases('bg-brand/50', const {'bg-brand': 'bg-red-500'}),
        'bg-brand/50',
      );
    });

    test('carries an arbitrary bracket opacity (#324)', () {
      expect(
        expandAliases('bg-brand/[0.5]', const {
          'bg-brand': 'bg-red-500/30',
        }, isColorClass: isColorClass),
        'bg-red-500/[0.5]',
      );
    });

    test('leaves a token whose suffix is not an opacity verbatim (#324)', () {
      expect(
        expandAliases('bg-brand/abc', const {
          'bg-brand': 'bg-red-500',
        }, isColorClass: isColorClass),
        'bg-brand/abc',
      );
    });

    test('expands a colourless alias, drops the opacity and warns (#324)', () {
      final warnings = <String>[];

      final result = expandAliases(
        'row/50',
        const {'row': 'flex flex-row'},
        onWarn: warnings.add,
        isColorClass: isColorClass,
      );

      expect(result, 'flex flex-row');
      expect(warnings, hasLength(1));
      expect(warnings.single, contains("'row'"));
      expect(warnings.single, contains("'/50'"));
    });

    test('terminates on a cycle reached through an opacity token (#324)', () {
      final warnings = <String>[];

      final result = expandAliases(
        'a/50',
        const {'a': 'a'},
        onWarn: warnings.add,
        isColorClass: isColorClass,
      );

      expect(result, 'a');
      expect(warnings.any((w) => w.contains('cycle')), isTrue);
    });
  });
}
