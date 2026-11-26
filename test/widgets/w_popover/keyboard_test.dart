import 'package:flutter/gestures.dart';
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

/// A popover whose trigger is a plain, non-interactive box, which is the shape
/// the class doc recommends and the one a bell or an avatar menu takes.
Widget popover({
  bool disabled = false,
  bool enableTriggerOnTap = true,
  String triggerClassName = 'w-10 h-10 bg-white',
  Widget content = const Text('Content'),
}) {
  return WPopover(
    disabled: disabled,
    enableTriggerOnTap: enableTriggerOnTap,
    triggerBuilder: (context, isOpen, isHovering) =>
        WDiv(className: triggerClassName, child: const Text('Trigger')),
    contentBuilder: (context, close) => content,
  );
}

/// Clicks the trigger with a mouse, the pointer of a desktop or web viewer. A
/// touch open on a phone moves no focus, so the pointer-open focus cases need
/// a mouse.
Future<void> click(WidgetTester tester) =>
    tester.tap(find.text('Trigger'), kind: PointerDeviceKind.mouse);

/// The colour the trigger box paints, read from the nearest `DecoratedBox`
/// above the trigger's text.
Color? triggerColor(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text('Trigger'), matching: find.byType(DecoratedBox))
        .first,
  );

  return (box.decoration as BoxDecoration).color;
}

void main() {
  setUp(WindParser.clearCache);

  group('WPopover keyboard', () {
    group('Activation', () {
      testWidgets('Tab reaches the trigger and Enter opens the popover', (
        tester,
      ) async {
        await tester.pumpWidget(wrapWithTheme(popover()));

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(find.text('Content'), findsOneWidget);
      });

      testWidgets('Space opens the popover and Enter closes it again', (
        tester,
      ) async {
        await tester.pumpWidget(wrapWithTheme(popover()));

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();

        expect(find.text('Content'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(find.text('Content'), findsNothing);
      });

      testWidgets('a disabled popover is no keyboard stop', (tester) async {
        await tester.pumpWidget(wrapWithTheme(popover(disabled: true)));

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(find.text('Content'), findsNothing);
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<WPopover>(),
          isNull,
        );
      });

      testWidgets('enableTriggerOnTap false leaves the keys to the caller', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(popover(enableTriggerOnTap: false)),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(find.text('Content'), findsNothing);
      });
    });

    group('Dismissal', () {
      testWidgets('Escape closes an open popover', (tester) async {
        await tester.pumpWidget(wrapWithTheme(popover()));

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(find.text('Content'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(find.text('Content'), findsNothing);
      });

      testWidgets('Escape closes it from a focused item inside the panel', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            popover(
              content: WAnchor(onTap: () {}, child: const Text('Item')),
            ),
          ),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<WAnchor>(),
          isNotNull,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(find.text('Item'), findsNothing);
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<WPopover>(),
          isNotNull,
          reason: 'focus returns to the trigger it was opened from',
        );
      });

      testWidgets('Escape on a closed popover travels on to the page', (
        tester,
      ) async {
        int dismissed = 0;
        await tester.pumpWidget(
          wrapWithTheme(
            Actions(
              actions: <Type, Action<Intent>>{
                DismissIntent: CallbackAction<DismissIntent>(
                  onInvoke: (_) => dismissed++,
                ),
              },
              child: popover(),
            ),
          ),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        expect(dismissed, 1);
      });
    });

    group('Focus after a keyboard open', () {
      testWidgets('takes focus back once when it drops to the page', (
        tester,
      ) async {
        await tester.pumpWidget(wrapWithTheme(popover()));

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final FocusNode trigger = FocusManager.instance.primaryFocus!;
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // What a web build does as the panel mounts: the browser drops the
        // focused element and the framework falls back to the scope.
        trigger.unfocus();
        await tester.pumpAndSettle();

        expect(trigger.hasPrimaryFocus, isTrue);

        // Only once: a second drop is the viewer's, and is left alone.
        trigger.unfocus();
        await tester.pumpAndSettle();

        expect(trigger.hasPrimaryFocus, isFalse);
      });

      testWidgets(
        'Escape in a dialog closes the popover and keeps the dialog',
        (tester) async {
          // One press, one layer. A key handler outside the focus tree cannot
          // consume the key, so the dialog's own Escape popped it as well.
          await tester.pumpWidget(
            wrapWithTheme(
              Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      child: WindTheme(data: WindThemeData(), child: popover()),
                    ),
                  ),
                  child: const Text('Open dialog'),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open dialog'));
          await tester.pumpAndSettle();

          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();

          expect(find.text('Content'), findsOneWidget);

          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();

          expect(find.text('Content'), findsNothing);
          expect(find.byType(Dialog), findsOneWidget);
        },
      );

      testWidgets('a page pushed over a keyboard-opened popover keeps focus', (
        tester,
      ) async {
        bool? open;
        await tester.pumpWidget(
          wrapWithTheme(
            WPopover(
              triggerBuilder: (context, isOpen, isHovering) {
                open = isOpen;
                return const WDiv(
                  className: 'w-10 h-10 bg-white',
                  child: Text('Trigger'),
                );
              },
              contentBuilder: (context, close) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: WAnchor(onTap: () {}, child: const Text('Page')),
                    ),
                  ),
                ),
                child: const Text('Push'),
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Push'), kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final FocusNode? onPage = FocusManager.instance.primaryFocus;

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(open, isTrue);
        expect(FocusManager.instance.primaryFocus, same(onPage));
      });

      testWidgets('Escape on a route pushed over an open popover leaves it', (
        tester,
      ) async {
        // A panel item that pushes a page without closing the popover: the
        // page's Escape is the page's, and the hidden trigger must not take
        // focus out from under it.
        bool? open;
        await tester.pumpWidget(
          wrapWithTheme(
            WPopover(
              triggerBuilder: (context, isOpen, isHovering) {
                open = isOpen;
                return const WDiv(
                  className: 'w-10 h-10 bg-white',
                  child: Text('Trigger'),
                );
              },
              contentBuilder: (context, close) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: WAnchor(onTap: () {}, child: const Text('Page')),
                    ),
                  ),
                ),
                child: const Text('Push'),
              ),
            ),
          ),
        );
        await click(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Push'));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final FocusNode? onPage = FocusManager.instance.primaryFocus;

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(open, isTrue);
        expect(FocusManager.instance.primaryFocus, same(onPage));
      });

      testWidgets(
        'Tab goes into the panel before a control beside the trigger',
        (tester) async {
          // Reading order alone ranks by position: the control on the trigger's
          // row comes before the panel below it, so a keyboard user left the
          // open panel behind. A host app's phone shell never reached its rows.
          await tester.pumpWidget(
            wrapWithTheme(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  popover(
                    content: WAnchor(onTap: () {}, child: const Text('Item')),
                  ),
                  WAnchor(onTap: () {}, child: const Text('Beside')),
                ],
              ),
            ),
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();

          final BuildContext focused =
              FocusManager.instance.primaryFocus!.context!;
          expect(
            find.descendant(
              of: find.byWidget(focused.widget),
              matching: find.text('Item'),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets('Tab goes into a panel that opened above the trigger', (
        tester,
      ) async {
        // A trigger at the foot of a rail flips its panel upward, and reading
        // order then ranked the whole panel BEFORE the trigger: Tab from the
        // trigger left the group and the panel was reachable only backwards.
        await tester.pumpWidget(
          wrapWithTheme(
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                WPopover(
                  alignment: PopoverAlignment.topLeft,
                  maxHeight: 200,
                  triggerBuilder: (context, isOpen, isHovering) => const WDiv(
                    className: 'w-10 h-10 bg-white',
                    child: Text('Trigger'),
                  ),
                  contentBuilder: (context, close) =>
                      WAnchor(onTap: () {}, child: const Text('Item')),
                ),
                WAnchor(onTap: () {}, child: const Text('Below')),
              ],
            ),
          ),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(
          tester.getTopLeft(find.text('Item')).dy,
          lessThan(tester.getTopLeft(find.text('Trigger')).dy),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        final BuildContext focused =
            FocusManager.instance.primaryFocus!.context!;
        expect(
          find.descendant(
            of: find.byWidget(focused.widget),
            matching: find.text('Item'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('Tab goes from the trigger into the panel before the page', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            Column(
              children: [
                popover(
                  content: WAnchor(onTap: () {}, child: const Text('Item')),
                ),
                const SizedBox(height: 300),
                WAnchor(onTap: () {}, child: const Text('Below')),
              ],
            ),
          ),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        final BuildContext focused =
            FocusManager.instance.primaryFocus!.context!;
        expect(
          find.descendant(
            of: find.byWidget(focused.widget),
            matching: find.text('Item'),
          ),
          findsOneWidget,
        );
      });
    });

    group('Pointer open', () {
      testWidgets('Escape closes a popover a pointer opened (#347)', (
        tester,
      ) async {
        await tester.pumpWidget(wrapWithTheme(popover()));

        await click(tester);
        await tester.pumpAndSettle();
        expect(find.text('Content'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(find.text('Content'), findsNothing);
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<WPopover>(),
          isNotNull,
          reason: 'focus stays on the trigger the pointer opened',
        );
      });

      testWidgets('takes focus back once when it drops to the page (#347)', (
        tester,
      ) async {
        await tester.pumpWidget(wrapWithTheme(popover()));

        await click(tester);
        await tester.pumpAndSettle();
        final FocusNode trigger = FocusManager.instance.primaryFocus!;
        expect(
          trigger.context?.findAncestorWidgetOfExactType<WPopover>(),
          isNotNull,
        );

        // What a web build does as the panel mounts.
        trigger.unfocus();
        await tester.pumpAndSettle();

        expect(trigger.hasPrimaryFocus, isTrue);

        trigger.unfocus();
        await tester.pumpAndSettle();

        expect(trigger.hasPrimaryFocus, isFalse);
      });

      testWidgets('leaves focus a viewer moved after a pointer open', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            Column(
              children: [
                popover(),
                WAnchor(onTap: () {}, child: const Text('Next')),
              ],
            ),
          ),
        );

        await click(tester);
        await tester.pumpAndSettle();
        await click(tester);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<WAnchor>(),
          isNotNull,
        );
      });

      testWidgets(
        'leaves a pointer-opened, Tab-focused trigger to the viewer',
        (tester) async {
          await tester.pumpWidget(wrapWithTheme(popover()));

          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final FocusNode trigger = FocusManager.instance.primaryFocus!;
          await click(tester);
          await tester.pumpAndSettle();
          trigger.unfocus();
          await tester.pumpAndSettle();

          expect(trigger.hasPrimaryFocus, isFalse);
        },
      );

      testWidgets('a touch open on a phone leaves a focused field alone', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            Column(children: [const TextField(autofocus: true), popover()]),
          ),
        );
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<EditableText>(),
          isNotNull,
        );

        // A touch outside a field keeps its focus and its keyboard on a
        // phone, so opening a popover beside it must not take either.
        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        expect(find.text('Content'), findsOneWidget);
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<EditableText>(),
          isNotNull,
        );
      });

      testWidgets('a pointer open lights no focus: class (#347)', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            popover(triggerClassName: 'w-10 h-10 bg-white focus:bg-black'),
          ),
        );

        await click(tester);
        await tester.pumpAndSettle();

        expect(triggerColor(tester), Colors.white);

        // Closing with the pointer keeps the focus a pointer gave.
        await click(tester);
        await tester.pumpAndSettle();

        expect(triggerColor(tester), Colors.white);
      });

      testWidgets('the first key after a pointer open lights it (#347)', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            popover(triggerClassName: 'w-10 h-10 bg-white focus:bg-black'),
          ),
        );

        await click(tester);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(triggerColor(tester), Colors.black);
      });

      testWidgets('a pointer open keeps the ring of a Tab-focused trigger', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            popover(triggerClassName: 'w-10 h-10 bg-white focus:bg-black'),
          ),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await click(tester);
        await tester.pumpAndSettle();

        expect(triggerColor(tester), Colors.black);
      });
    });

    group('Focus state', () {
      testWidgets('a focus: class on the trigger lights while it has focus', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            popover(triggerClassName: 'w-10 h-10 bg-white focus:bg-black'),
          ),
        );

        expect(triggerColor(tester), Colors.white);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(triggerColor(tester), Colors.black);
      });

      testWidgets('the focus: class goes dark again when focus leaves', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            Column(
              children: [
                popover(triggerClassName: 'w-10 h-10 bg-white focus:bg-black'),
                WAnchor(onTap: () {}, child: const Text('Next')),
              ],
            ),
          ),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(triggerColor(tester), Colors.white);
      });
    });
  });
}
