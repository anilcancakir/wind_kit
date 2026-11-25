import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wind_kit/src/state/wind_min_width_scroll_scope.dart';
import 'package:wind_kit/wind_kit.dart';

/// `h-full` below a vertical scroll.
///
/// A vertical scroll installs a scope that flags its content as living on an
/// unbounded height. The flag says only that SOME ancestor is unbounded, not
/// that the incoming constraints of the `h-full` element are: a `h-40` or a
/// `SizedBox(height: 200)` in between bounds them again, and `h-full` then has
/// something to fill. The assert therefore has to read the constraints it is
/// laid out under, which only the render layer can do.
void main() {
  setUp(WindParser.clearCache);

  /// Pumps [child] in a 300 by 400 viewport so the scroll under test has a
  /// known width.
  Future<void> pumpScroll(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: WindTheme(
          data: WindThemeData(),
          child: Center(child: SizedBox(width: 300, height: 400, child: child)),
        ),
      ),
    );
  }

  group('h-full below a vertical scroll', () {
    testWidgets('fills a fixed-height WDiv in between (#318)', (tester) async {
      await pumpScroll(
        tester,
        const WDiv(
          className: 'overflow-y-auto',
          child: WDiv(
            className: 'h-40',
            child: WDiv(className: 'h-full', child: _Probe()),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(_Probe)).height, 160);
    });

    testWidgets(
      'asserts as a direct child of the scroll, pointing at a bounded '
      'column with the scroll on its body (#318)',
      (tester) async {
        await pumpScroll(
          tester,
          const WDiv(
            className: 'overflow-y-auto',
            child: WDiv(className: 'h-full', child: _Probe()),
          ),
        );

        final Object? error = tester.takeException();
        expect(error, isA<AssertionError>());
        expect(error.toString(), contains('`flex flex-col h-full`'));
        expect(error.toString(), contains('`flex-1 overflow-y-auto`'));
        expect(error.toString(), isNot(contains('scroll on the column')));
      },
    );

    testWidgets('fills a SizedBox in between (#318)', (tester) async {
      await pumpScroll(
        tester,
        const WDiv(
          className: 'overflow-y-auto',
          child: SizedBox(
            height: 200,
            child: WDiv(className: 'h-full', child: _Probe()),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(_Probe)).height, 200);
    });

    testWidgets('fills a Positioned.fill inside a Stack (#318)', (
      tester,
    ) async {
      await pumpScroll(
        tester,
        const WDiv(
          className: 'overflow-y-auto',
          child: SizedBox(
            height: 200,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: WDiv(className: 'h-full', child: _Probe()),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(_Probe)).height, 200);
    });

    testWidgets('keeps a w-full sibling at the viewport width in overflow-auto '
        '(#318)', (tester) async {
      const Key wide = ValueKey<String>('wide');
      const Key fill = ValueKey<String>('fill');

      // Both axes scroll, so the probe's width is unbounded: it takes a fixed
      // width and only fills the height.
      await pumpScroll(
        tester,
        const WDiv(
          className: 'overflow-auto flex flex-col',
          children: <Widget>[
            WDiv(key: wide, className: 'w-full', child: SizedBox(height: 10)),
            WDiv(
              className: 'h-40',
              child: WDiv(
                className: 'h-full',
                child: SizedBox(key: fill, width: 50, height: double.infinity),
              ),
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(wide)).width, 300);
      expect(tester.getSize(find.byKey(fill)).height, 160);
    });

    testWidgets(
      'w-full h-full fills the viewport width in overflow-auto when a '
      'parent loosens the minimum width (#318)',
      (tester) async {
        const Key fill = ValueKey<String>('fill');

        // `Align` drops the inherited minimum width, so the only thing left to
        // size the box against is the viewport the scroll publishes.
        await pumpScroll(
          tester,
          const WDiv(
            className: 'overflow-auto',
            child: SizedBox(
              height: 160,
              child: Align(
                alignment: Alignment.topLeft,
                child: WDiv(
                  className: 'w-full h-full',
                  child: SizedBox(key: fill, width: 50, height: 10),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byKey(fill)).width, 300);
      },
    );

    testWidgets('a padding-only WDiv in between still reports, since it passes '
        'the unbounded height on (#318)', (tester) async {
      await pumpScroll(
        tester,
        const WDiv(
          className: 'overflow-y-auto',
          child: WDiv(
            className: 'p-4',
            child: WDiv(className: 'h-full', child: _Probe()),
          ),
        ),
      );

      final Object? error = tester.takeException();
      expect(error, isA<AssertionError>());
      expect(error.toString(), contains('flex-1'));
    });

    testWidgets('re-evaluates when the scroll flag flips in place (#318)', (
      tester,
    ) async {
      // Same tree shape both times, so the render object is updated rather
      // than rebuilt: the flag has to reach it through `updateRenderObject`.
      Widget tree({required bool inScroll}) => MaterialApp(
        home: WindTheme(
          data: WindThemeData(),
          child: WindMinWidthScrollScope(
            verticalUnbounded: inScroll,
            child: const Column(
              children: <Widget>[WDiv(className: 'h-full', child: _Probe())],
            ),
          ),
        ),
      );

      await tester.pumpWidget(tree(inScroll: true));
      final Object? error = tester.takeException();
      expect(error, isA<AssertionError>());
      expect(error.toString(), contains('flex-1'));

      await tester.pumpWidget(tree(inScroll: false));
      expect(tester.takeException(), isNull);
    });

    testWidgets('still asserts under a Column that offers an unbounded height '
        '(#318)', (tester) async {
      await pumpScroll(
        tester,
        const WDiv(
          className: 'overflow-y-auto',
          child: WDiv(
            className: 'flex flex-col',
            children: <Widget>[WDiv(className: 'h-full', child: _Probe())],
          ),
        ),
      );

      final Object? error = tester.takeException();
      expect(error, isA<AssertionError>());
      expect(error.toString(), contains('flex-1'));
    });
  });
}

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
