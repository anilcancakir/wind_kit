import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wind_kit/src/parser/wind_parser.dart';
import 'package:wind_kit/src/parser/wind_style.dart';
import 'package:wind_kit/src/theme/wind_theme.dart';
import 'package:wind_kit/src/theme/wind_theme_data.dart';
import 'package:wind_kit/src/widgets/w_div.dart';

/// Wraps [child] in a [WindTheme] carrying the supplied [aliases] so
/// `WindParser.parse` resolves them through the real `parse()` path.
///
/// [brightness] forces the theme brightness (system sync is switched off so it
/// sticks); omitted, the theme keeps its defaults.
Widget wrapWithAliases(
  Map<String, String> aliases,
  Widget child, {
  Brightness? brightness,
}) {
  return MaterialApp(
    home: WindTheme(
      data: WindThemeData(
        screens: const {'sm': 640, 'md': 768, 'lg': 1024, 'xl': 1280},
        aliases: aliases,
        brightness: brightness ?? Brightness.light,
        syncWithSystem: brightness == null,
      ),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(() {
    WindParser.clearCache();
  });

  group('WindParser alias expansion', () {
    testWidgets(
      'expands an alias before parsing so it yields a flex/row style',
      (tester) async {
        late WindStyle style;

        await tester.pumpWidget(
          wrapWithAliases(
            const {'row': 'flex flex-row'},
            Builder(
              builder: (context) {
                style = WindParser.parse('row', context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(style.displayType, WindDisplayType.flex);
        expect(style.flexDirection, Axis.horizontal);
      },
    );

    testWidgets('expands recursively before parsing', (tester) async {
      late WindStyle style;

      await tester.pumpWidget(
        wrapWithAliases(
          const {'row': 'flex flex-row', 'row-c': 'row items-center'},
          Builder(
            builder: (context) {
              style = WindParser.parse('row-c', context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(style.displayType, WindDisplayType.flex);
      expect(style.flexDirection, Axis.horizontal);
      expect(style.crossAxisAlignment, CrossAxisAlignment.center);
    });

    testWidgets(
      'two themes with different alias maps keep distinct cache entries',
      (tester) async {
        late WindStyle rowStyle;

        await tester.pumpWidget(
          wrapWithAliases(
            const {'box': 'flex flex-row'},
            Builder(
              builder: (context) {
                rowStyle = WindParser.parse('box', context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(rowStyle.flexDirection, Axis.horizontal);
        final sizeAfterRow = WindParser.cacheSize;

        late WindStyle colStyle;

        await tester.pumpWidget(
          wrapWithAliases(
            const {'box': 'flex flex-col'},
            Builder(
              builder: (context) {
                colStyle = WindParser.parse('box', context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        // Same raw className `box`, different alias values: the cache key is
        // computed from the expanded string, so the two produce distinct entries
        // and distinct results rather than a stale cache hit.
        expect(colStyle.flexDirection, Axis.vertical);
        expect(WindParser.cacheSize, greaterThan(sizeAfterRow));
      },
    );

    testWidgets('a WDiv with className:row renders a horizontal Flex', (
      tester,
    ) async {
      // The central-injection smoke: a real widget, not just a parse() call,
      // proves the alias resolves through the rendering path.
      await tester.pumpWidget(
        wrapWithAliases(const {
          'row': 'flex flex-row',
        }, const WDiv(className: 'row', children: [Text('a'), Text('b')])),
      );

      // A horizontal flex renders as a concrete Row (find.byType matches the
      // exact runtime type, not the Flex superclass).
      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(Column), findsNothing);
    });
  });

  group('WindParser alias debug diagnostics', () {
    // These diagnostics are kDebugMode-gated; flutter test runs in debug mode,
    // so the branches execute. We capture debugPrint to assert they fire.
    testWidgets('warns once when an alias key shadows a built-in token', (
      tester,
    ) async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');

      try {
        await tester.pumpWidget(
          wrapWithAliases(
            const {'flex': 'flex-row'},
            Builder(
              builder: (context) {
                WindParser.parse('flex', context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      } finally {
        debugPrint = original;
      }

      expect(
        logs.where((l) => l.contains("alias 'flex' shadows a built-in")).length,
        1,
      );
    });

    testWidgets('warns when a cyclic alias is expanded through parse', (
      tester,
    ) async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');

      try {
        await tester.pumpWidget(
          wrapWithAliases(
            const {'a': 'a'},
            Builder(
              builder: (context) {
                WindParser.parse('a', context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      } finally {
        debugPrint = original;
      }

      expect(logs.any((l) => l.contains("alias 'a' forms a cycle")), isTrue);
    });
  });

  group('WindParser alias opacity modifier', () {
    /// Pumps a theme carrying [aliases] and parses each of [classNames] in
    /// order through the real `parse()` path, returning the styles.
    Future<List<WindStyle>> parseAll(
      WidgetTester tester,
      Map<String, String> aliases,
      List<String> classNames, {
      Brightness? brightness,
      Set<String>? states,
    }) async {
      final styles = <WindStyle>[];

      await tester.pumpWidget(
        wrapWithAliases(
          aliases,
          Builder(
            builder: (context) {
              for (final className in classNames) {
                styles.add(
                  WindParser.parse(className, context, states: states),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          brightness: brightness,
        ),
      );

      return styles;
    }

    testWidgets('applies /N to the colour of a bg alias (#324)', (
      tester,
    ) async {
      final styles = await parseAll(
        tester,
        const {'bg-brand': 'bg-[#336699]'},
        const ['bg-brand/50'],
      );

      expect(styles.single.decoration?.color, const Color(0x80336699));
    });

    testWidgets('applies /N to the dark: peer in a dark theme (#324)', (
      tester,
    ) async {
      const aliases = {'bg-brand': 'bg-[#336699] dark:bg-[#99ccff]'};

      final dark = await parseAll(tester, aliases, const [
        'bg-brand/50',
      ], brightness: Brightness.dark);
      expect(dark.single.decoration?.color, const Color(0x8099ccff));

      WindParser.clearCache();

      final light = await parseAll(tester, aliases, const [
        'bg-brand/50',
      ], brightness: Brightness.light);
      expect(light.single.decoration?.color, const Color(0x80336699));
    });

    testWidgets('keeps a state prefix and applies /N to it (#324)', (
      tester,
    ) async {
      final styles = await parseAll(
        tester,
        const {'bg-brand': 'bg-[#336699] dark:bg-[#99ccff]'},
        const ['hover:bg-brand/50'],
        states: const {'hover'},
      );

      expect(styles.single.decoration?.color, const Color(0x80336699));
    });

    testWidgets('leaves non-colour classes of the alias untouched (#324)', (
      tester,
    ) async {
      final styles = await parseAll(
        tester,
        const {'label': 'text-lg text-blue-500'},
        const ['label/50'],
      );

      final style = styles.single;
      expect(style.fontSize, WindThemeData().fontSizes['lg']);
      expect(style.color, isNotNull);
      expect(style.color!.a, closeTo(0x80 / 255, 0.001));
      expect(style.heightLine, isNull);
    });

    testWidgets('caches each /N expansion under its own key (#324)', (
      tester,
    ) async {
      final styles = await parseAll(
        tester,
        const {'bg-brand': 'bg-[#336699]'},
        const ['bg-brand/50', 'bg-brand/20'],
      );

      expect(styles[0].decoration?.color, isNot(styles[1].decoration?.color));
      expect(WindParser.cacheSize, 2);

      final plain = await parseAll(
        tester,
        const {'bg-brand': 'bg-[#336699]'},
        const ['bg-brand'],
      );

      expect(plain.single.decoration?.color, const Color(0xFF336699));
    });

    testWidgets('ignores /N on an alias with no colour class (#324)', (
      tester,
    ) async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');

      late final List<WindStyle> styles;
      try {
        styles = await parseAll(
          tester,
          const {'card': 'p-4 rounded-lg'},
          const ['card/50'],
        );
      } finally {
        debugPrint = original;
      }

      // The alias still expands (padding is set) and the `/50` is dropped
      // with a diagnostic instead of changing any class.
      expect(styles.single.padding, const EdgeInsets.all(16));
      expect(
        logs.where((l) => l.contains("alias 'card' has no colour class")),
        hasLength(1),
      );
    });
  });
}
