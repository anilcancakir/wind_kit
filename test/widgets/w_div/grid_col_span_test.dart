import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wind_kit/wind_kit.dart';

Widget wrapWithTheme(
  Widget child, {
  double width = 600,
  Map<String, String> aliases = const {},
}) => MaterialApp(
  home: WindTheme(
    data: WindThemeData(aliases: aliases),
    child: Scaffold(
      body: SizedBox(width: width, child: child),
    ),
  ),
);

/// A grid cell with a fixed-height body, found by [id].
Widget cell(String id, String? className, {double height = 50}) => WDiv(
  key: Key(id),
  className: className,
  child: SizedBox(height: height),
);

Finder at(String id) => find.byKey(Key(id));

/// The two layout paths a grid can take: the Wrap default and the equal-height
/// `items-stretch` Column of rows.
const paths = <(String, String)>[
  ('Wrap', ''),
  ('items-stretch', ' items-stretch'),
];

void main() {
  setUp(WindParser.clearCache);

  for (final (label, extra) in paths) {
    group('col-span on the $label path', () {
      testWidgets('a span of 2 is two columns plus the gap between (#328)', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WDiv(
              className: 'grid grid-cols-4 gap-4$extra',
              children: [cell('a', 'col-span-2'), cell('b', null)],
            ),
            width: 400,
          ),
        );

        expect(tester.takeException(), isNull);
        // (400 - 3 * 16) / 4 = 88 per column; 2 * 88 + 16 = 192.
        expect(tester.getSize(at('a')).width, 192);
        expect(tester.getSize(at('b')).width, 88);
      });

      testWidgets(
        'col-span-full fills the row and shares it with no one (#328)',
        (tester) async {
          await tester.pumpWidget(
            wrapWithTheme(
              WDiv(
                className: 'grid grid-cols-4 gap-4$extra',
                children: [
                  cell('a', null),
                  cell('b', 'col-span-full'),
                  cell('c', null),
                ],
              ),
              width: 400,
            ),
          );

          expect(tester.getSize(at('b')).width, 400);
          expect(tester.getTopLeft(at('b')).dx, 0);
          expect(
            tester.getTopLeft(at('b')).dy,
            greaterThan(tester.getTopLeft(at('a')).dy),
          );
          expect(
            tester.getTopLeft(at('c')).dy,
            greaterThan(tester.getTopLeft(at('b')).dy),
          );
        },
      );

      testWidgets(
        'a span beyond the column count caps at the full width (#328)',
        (tester) async {
          await tester.pumpWidget(
            wrapWithTheme(
              WDiv(
                className: 'grid grid-cols-4 gap-4$extra',
                children: [cell('a', 'col-span-9')],
              ),
              width: 400,
            ),
          );

          expect(tester.getSize(at('a')).width, 400);
        },
      );

      testWidgets('col-span-0 clamps to one column (#328)', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WDiv(
              className: 'grid grid-cols-4 gap-4$extra',
              children: [cell('a', 'col-span-0')],
            ),
            width: 400,
          ),
        );

        expect(tester.getSize(at('a')).width, 88);
      });

      testWidgets('md:col-span-2 is one column below the breakpoint (#328)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(600, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          wrapWithTheme(
            WDiv(
              className: 'grid grid-cols-4 gap-4$extra',
              children: [cell('a', 'md:col-span-2')],
            ),
            width: 400,
          ),
        );

        expect(tester.getSize(at('a')).width, 88);
      });

      testWidgets('md:col-span-2 is two columns above the breakpoint (#328)', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WDiv(
              className: 'grid grid-cols-4 gap-4$extra',
              children: [cell('a', 'md:col-span-2')],
            ),
            width: 400,
          ),
        );

        expect(tester.getSize(at('a')).width, 192);
      });

      testWidgets('a theme alias that expands to a span still spans (#328)', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WDiv(
              className: 'grid grid-cols-4 gap-4$extra',
              children: [cell('a', 'wide-tile'), cell('b', null)],
            ),
            width: 400,
            aliases: const {'wide-tile': 'col-span-2'},
          ),
        );

        expect(tester.getSize(at('a')).width, 192);
        expect(tester.getSize(at('b')).width, 88);
      });

      testWidgets('a grid narrower than its gaps collapses every cell (#328)', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WDiv(
              className: 'grid grid-cols-12 gap-4$extra',
              children: [
                WDiv(
                  key: const Key('a'),
                  className: 'col-span-full',
                  child: const SizedBox(width: 100, height: 50),
                ),
                WDiv(
                  key: const Key('b'),
                  child: const SizedBox(width: 100, height: 50),
                ),
              ],
            ),
            width: 150,
          ),
        );

        expect(tester.takeException(), isNull);
        expect(tester.getSize(at('a')).width, 0);
        expect(tester.getSize(at('b')).width, 0);
      });

      testWidgets('an awkward width keeps a full row on one line (#328)', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WDiv(
              className: 'grid grid-cols-3 gap-[7px]$extra',
              children: [
                cell('a', 'col-span-2'),
                cell('b', null),
                cell('c', 'col-span-full'),
              ],
            ),
            width: 333.3,
          ),
        );

        expect(tester.takeException(), isNull);
        expect(tester.getTopLeft(at('b')).dy, tester.getTopLeft(at('a')).dy);
        expect(tester.getSize(at('c')).width, closeTo(333.3, 1e-9));
        expect(
          tester.getTopLeft(at('c')).dy,
          greaterThan(tester.getTopLeft(at('b')).dy),
        );
      });

      testWidgets('gap-x offsets and the gap-y row distance are exact (#328)', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WDiv(
              className: 'grid grid-cols-4 gap-x-4 gap-y-8$extra',
              children: [
                cell('a', 'col-span-2'),
                cell('b', null),
                cell('c', null),
                cell('d', 'col-span-2'),
                cell('e', null),
              ],
            ),
            width: 400,
          ),
        );

        expect(tester.getTopLeft(at('a')), Offset.zero);
        expect(tester.getTopLeft(at('b')), const Offset(208, 0));
        expect(tester.getTopLeft(at('c')), const Offset(312, 0));
        // Row height 50 plus gap-y-8 (32).
        expect(tester.getTopLeft(at('d')), const Offset(0, 82));
        expect(tester.getTopLeft(at('e')), const Offset(208, 82));
      });

      testWidgets('a child that is not a Wind widget keeps one column (#328)', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WDiv(
              className: 'grid grid-cols-4 gap-4$extra',
              children: [
                const SizedBox(key: Key('a'), height: 50),
                cell('b', 'col-span-2'),
              ],
            ),
            width: 400,
          ),
        );

        expect(tester.getSize(at('a')).width, 88);
        expect(tester.getSize(at('b')).width, 192);
      });

      testWidgets(
        'packing is sparse: a span that does not fit starts a row (#328)',
        (tester) async {
          await tester.pumpWidget(
            wrapWithTheme(
              WDiv(
                className: 'grid grid-cols-4 gap-4$extra',
                children: [
                  cell('a', null),
                  cell('b', null),
                  cell('c', null),
                  cell('d', 'col-span-2'),
                ],
              ),
              width: 400,
            ),
          );

          expect(tester.getTopLeft(at('c')).dy, 0);
          // Row height 50 plus gap-4 (16).
          expect(tester.getTopLeft(at('d')), const Offset(0, 66));
        },
      );
    });
  }

  group('col-span parent-side resolution', () {
    for (final (label, crossAxis) in <(String, CrossAxisAlignment?)>[
      ('Wrap', null),
      ('items-stretch', CrossAxisAlignment.stretch),
    ]) {
      testWidgets(
        'an explicit-style $label grid builds without a WindTheme (#328)',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 400,
                  child: WDiv(
                    style: WindStyle(
                      displayType: WindDisplayType.grid,
                      gridCols: 4,
                      gapX: 16,
                      crossAxisAlignment: crossAxis,
                    ),
                    children: const [
                      SizedBox(key: Key('a'), height: 50),
                      SizedBox(key: Key('b'), height: 50),
                    ],
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(tester.getSize(at('a')).width, 88);
        },
      );

      testWidgets(
        'disabled:col-span-2 spans under a disabled anchor on the $label '
        'path (#328)',
        (tester) async {
          await tester.pumpWidget(
            wrapWithTheme(
              WAnchor(
                isDisabled: true,
                child: WDiv(
                  className:
                      'grid grid-cols-4 gap-4'
                      '${crossAxis == null ? '' : ' items-stretch'}',
                  children: [cell('a', 'disabled:col-span-2'), cell('b', null)],
                ),
              ),
              width: 400,
            ),
          );

          expect(tester.getSize(at('a')).width, 192);
          expect(tester.getSize(at('b')).width, 88);
        },
      );

      testWidgets(
        'a custom anchor state drives a span on the $label path (#328)',
        (tester) async {
          await tester.pumpWidget(
            wrapWithTheme(
              WAnchor(
                states: const {'wide'},
                child: WDiv(
                  className:
                      'grid grid-cols-4 gap-4'
                      '${crossAxis == null ? '' : ' items-stretch'}',
                  children: [cell('a', 'wide:col-span-2'), cell('b', null)],
                ),
              ),
              width: 400,
            ),
          );

          expect(tester.getSize(at('a')).width, 192);
        },
      );
    }
  });

  group('col-span on the items-stretch path only', () {
    testWidgets('cells with spans share one row height (#328)', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WDiv(
            className: 'grid grid-cols-3 gap-4 items-stretch',
            children: [
              cell('a', 'col-span-2', height: 40),
              cell('b', null, height: 120),
            ],
          ),
          width: 400,
        ),
      );

      expect(tester.getSize(at('a')).height, 120);
      expect(tester.getSize(at('b')).height, 120);
      // (400 - 2 * 16) / 3 columns, so a is 2 * 122.67 + 16 wide.
      expect(tester.getSize(at('a')).width, closeTo(261.3333, 1e-3));
    });
  });
}
