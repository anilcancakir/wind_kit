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

void main() {
  setUp(WindParser.clearCache);

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
