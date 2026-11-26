import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wind_kit/wind_kit.dart';

void main() {
  setUp(WindParser.clearCache);

  Future<void> pumpDiv(WidgetTester tester, WDiv div) {
    return tester.pumpWidget(
      MaterialApp(
        home: WindTheme(data: WindThemeData(), child: div),
      ),
    );
  }

  group('WDiv semanticLabel', () {
    testWidgets('publishes one label node that is not a button (#325)', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpDiv(
          tester,
          const WDiv(
            semanticLabel: 'Status: operational',
            children: [WText('Up')],
          ),
        );

        final Finder labelled = find.bySemanticsLabel('Status: operational');
        expect(labelled, findsOneWidget);
        expect(tester.getSemantics(labelled).flagsCollection.isButton, isFalse);
        expect(find.bySemanticsLabel('Up'), findsNothing);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('publishes no label node for a hidden WDiv (#325)', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpDiv(
          tester,
          const WDiv(
            className: 'hidden',
            semanticLabel: 'Status: operational',
            children: [WText('Up')],
          ),
        );

        expect(find.bySemanticsLabel('Status: operational'), findsNothing);
        expect(find.byType(SizedBox), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('stays a single non-button node under hover: classes (#325)', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpDiv(
          tester,
          const WDiv(
            className: 'hover:bg-slate-100 dark:hover:bg-slate-800',
            semanticLabel: 'Status: operational',
            children: [WText('Up')],
          ),
        );

        final Finder labelled = find.bySemanticsLabel('Status: operational');
        expect(labelled, findsOneWidget);
        expect(tester.getSemantics(labelled).flagsCollection.isButton, isFalse);
        expect(find.bySemanticsLabel('Up'), findsNothing);
        expect(
          find.semantics.byPredicate(
            (SemanticsNode node) => node.flagsCollection.isButton,
          ),
          findsNothing,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('stays a single non-button node under focus: classes (#325)', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpDiv(
          tester,
          const WDiv(
            className: 'focus:ring-2 dark:focus:ring-slate-500',
            semanticLabel: 'Status: operational',
            children: [WText('Up')],
          ),
        );

        final Finder labelled = find.bySemanticsLabel('Status: operational');
        expect(labelled, findsOneWidget);
        expect(tester.getSemantics(labelled).flagsCollection.isButton, isFalse);
        expect(find.bySemanticsLabel('Up'), findsNothing);
      } finally {
        handle.dispose();
      }
    });
  });

  group('WDiv excludeSemantics', () {
    testWidgets('hides the descendant text from the semantics tree (#325)', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpDiv(
          tester,
          const WDiv(excludeSemantics: true, children: [WText('Up')]),
        );

        expect(find.text('Up'), findsOneWidget);
        expect(find.bySemanticsLabel('Up'), findsNothing);
      } finally {
        handle.dispose();
      }
    });

    test('rejects semanticLabel together with excludeSemantics (#325)', () {
      expect(
        () => WDiv(semanticLabel: 'Status', excludeSemantics: true),
        throwsAssertionError,
      );
    });
  });

  group('WDiv semantics inside a flex parent', () {
    // `flex-1` makes the pipeline return an `Expanded`, a ParentDataWidget that
    // must sit directly under the `Flex`, so the semantics wrapper has to go
    // beneath it rather than around it.
    for (final String flexClass in <String>['flex-1', 'grow', 'flex-auto']) {
      testWidgets('a labelled $flexClass child of a row builds (#325)', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await pumpDiv(
            tester,
            WDiv(
              className: 'flex flex-row',
              children: [
                WDiv(
                  className: flexClass,
                  semanticLabel: 'Status: operational',
                  children: const [WText('Up')],
                ),
              ],
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.bySemanticsLabel('Status: operational'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    }

    testWidgets('an excluded flex-1 child of a column builds (#325)', (
      tester,
    ) async {
      await pumpDiv(
        tester,
        const WDiv(
          className: 'flex flex-col h-40',
          children: [
            WDiv(
              className: 'flex-1',
              excludeSemantics: true,
              children: [WText('Up')],
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('WDiv without semantics props', () {
    testWidgets('leaves the descendant text speaking (#325)', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpDiv(tester, const WDiv(children: [WText('Up')]));

        expect(find.bySemanticsLabel('Up'), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });
  });
}
