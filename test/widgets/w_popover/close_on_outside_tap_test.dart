import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wind_kit/wind_kit.dart';

/// Helper to wrap widget in MaterialApp with WindTheme
Widget wrapWithTheme(Widget child) {
  return MaterialApp(
    home: WindTheme(
      data: WindThemeData(),
      child: Scaffold(body: child),
    ),
  );
}

/// A centred popover, so the top-left corner of the screen is clear of both
/// the trigger and the panel.
Widget popover({bool closeOnOutsideTap = true, PopoverController? controller}) {
  return Center(
    child: WPopover(
      controller: controller,
      closeOnOutsideTap: closeOnOutsideTap,
      triggerBuilder: (context, isOpen, isHovering) => WDiv(
        className: 'w-10 h-10 bg-white dark:bg-gray-800',
        child: const Text('Trigger'),
      ),
      contentBuilder: (context, close) => SizedBox(
        height: 100,
        child: Column(
          children: <Widget>[
            const Text('Content'),
            GestureDetector(onTap: close, child: const Text('Dismiss')),
          ],
        ),
      ),
    ),
  );
}

/// Opens the popover with the keyboard, which leaves focus on the trigger so
/// that Escape reaches the popover.
Future<void> openByKeyboard(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

/// A centred popover over a button in the top-left corner, clear of both the
/// trigger and the panel, which counts its taps in [taps].
Widget popoverOverButton(
  List<int> taps, {
  bool consumeOutsideTap = false,
  bool closeOnOutsideTap = true,
}) {
  return Stack(
    children: <Widget>[
      Positioned(
        left: 0,
        top: 0,
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => taps.add(1),
          child: const ColoredBox(color: Colors.transparent),
        ),
      ),
      Center(
        child: WPopover(
          consumeOutsideTap: consumeOutsideTap,
          closeOnOutsideTap: closeOnOutsideTap,
          triggerBuilder: (context, isOpen, isHovering) => WDiv(
            className: 'w-10 h-10 bg-white dark:bg-gray-800',
            child: const Text('Trigger'),
          ),
          contentBuilder: (context, close) =>
              const SizedBox(height: 100, child: Text('Content')),
        ),
      ),
    ],
  );
}

void main() {
  setUp(WindParser.clearCache);

  group('WPopover consumeOutsideTap', () {
    testWidgets('an outside tap reaches the widget below by default (#348)', (
      tester,
    ) async {
      final List<int> taps = <int>[];
      await tester.pumpWidget(wrapWithTheme(popoverOverButton(taps)));

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Content'), findsNothing);
      expect(taps, hasLength(1));
    });

    testWidgets('true closes the popover and keeps the tap (#348)', (
      tester,
    ) async {
      final List<int> taps = <int>[];
      await tester.pumpWidget(
        wrapWithTheme(popoverOverButton(taps, consumeOutsideTap: true)),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Content'), findsNothing);
      expect(taps, isEmpty);

      // Closed, the popover consumes nothing.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(taps, hasLength(1));
    });

    testWidgets('true still toggles from the trigger (#348)', (tester) async {
      final List<int> taps = <int>[];
      await tester.pumpWidget(
        wrapWithTheme(popoverOverButton(taps, consumeOutsideTap: true)),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsOneWidget);

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Content'), findsNothing);
    });

    testWidgets('keeps a dialog a panel item opened usable (#348)', (
      tester,
    ) async {
      int confirmed = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          Center(
            child: WPopover(
              consumeOutsideTap: true,
              triggerBuilder: (context, isOpen, isHovering) => WDiv(
                className: 'w-10 h-10 bg-white dark:bg-gray-800',
                child: const Text('Trigger'),
              ),
              contentBuilder: (context, close) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => Center(
                    child: TextButton(
                      onPressed: () => confirmed++,
                      child: const Text('Confirm'),
                    ),
                  ),
                ),
                child: const Text('Ask'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();
      expect(find.text('Ask'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(confirmed, 1);
      expect(
        find.text('Ask'),
        findsOneWidget,
        reason: 'a tap on a route above is not an outside tap',
      );
    });

    testWidgets('has no effect when closeOnOutsideTap is false (#348)', (
      tester,
    ) async {
      final List<int> taps = <int>[];
      await tester.pumpWidget(
        wrapWithTheme(
          popoverOverButton(
            taps,
            consumeOutsideTap: true,
            closeOnOutsideTap: false,
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Content'), findsOneWidget);
      expect(taps, hasLength(1));
    });
  });

  group('WPopover closeOnOutsideTap', () {
    testWidgets('closes on an outside tap by default (#327)', (tester) async {
      await tester.pumpWidget(wrapWithTheme(popover()));

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Content'), findsNothing);
    });

    testWidgets('stays open on an outside tap when false (#327)', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWithTheme(popover(closeOnOutsideTap: false)));

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('closes on Escape by default (#327)', (tester) async {
      await tester.pumpWidget(wrapWithTheme(popover()));

      await openByKeyboard(tester);
      expect(find.text('Content'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Content'), findsNothing);
    });

    testWidgets('closes on Escape when false (#327)', (tester) async {
      await tester.pumpWidget(wrapWithTheme(popover(closeOnOutsideTap: false)));

      await openByKeyboard(tester);
      expect(find.text('Content'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Content'), findsNothing);
    });

    testWidgets('closes through PopoverController.hide when false (#327)', (
      tester,
    ) async {
      final PopoverController controller = PopoverController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrapWithTheme(
          popover(closeOnOutsideTap: false, controller: controller),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsOneWidget);

      controller.hide();
      await tester.pumpAndSettle();

      expect(find.text('Content'), findsNothing);
    });

    testWidgets('closes when the trigger is tapped again and false (#327)', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWithTheme(popover(closeOnOutsideTap: false)));

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsOneWidget);

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Content'), findsNothing);
    });

    testWidgets('closes through the close callback when false (#327)', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWithTheme(popover(closeOnOutsideTap: false)));

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsOneWidget);

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(find.text('Content'), findsNothing);
    });
  });
}
