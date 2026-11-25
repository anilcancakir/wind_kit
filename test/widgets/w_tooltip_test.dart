import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wind_kit/wind_kit.dart';

const String _message = 'Save changes';
const Key _triggerKey = Key('trigger');

Widget wrapWithTheme(
  Widget child, {
  Brightness brightness = Brightness.light,
  Alignment placement = Alignment.topLeft,
}) {
  return MaterialApp(
    home: WindTheme(
      data: WindThemeData(brightness: brightness, syncWithSystem: false),
      child: Scaffold(
        body: Align(
          alignment: placement,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
}

Widget _tooltip({
  String message = _message,
  String? className,
  PopoverAlignment alignment = PopoverAlignment.bottomCenter,
  Offset offset = const Offset(0, 4),
  Duration hoverDelay = const Duration(milliseconds: 500),
}) {
  return WTooltip(
    message: message,
    className: className,
    alignment: alignment,
    offset: offset,
    hoverDelay: hoverDelay,
    child: const SizedBox(
      key: _triggerKey,
      width: 40,
      height: 40,
      child: ColoredBox(color: Color(0x00000000)),
    ),
  );
}

/// Parks a mouse pointer away from the trigger and returns it.
Future<TestGesture> _mouse(WidgetTester tester) async {
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  addTearDown(gesture.removePointer);
  await gesture.addPointer(location: Offset.zero);
  await tester.pump();
  return gesture;
}

/// Hovers the trigger and waits past the default delay and the fade-in.
Future<TestGesture> _showByHover(WidgetTester tester) async {
  final TestGesture gesture = await _mouse(tester);
  await gesture.moveTo(tester.getCenter(find.byKey(_triggerKey)));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 200));
  return gesture;
}

/// The colour painted by the nearest decorated box above the tooltip text.
Color? _boxFill(WidgetTester tester) {
  for (final Element element
      in find
          .ancestor(
            of: find.text(_message),
            matching: find.byType(DecoratedBox),
          )
          .evaluate()) {
    final Decoration decoration = (element.widget as DecoratedBox).decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration.color;
    }
  }
  return null;
}

/// The rect of the tooltip box, the nearest decorated box above the text.
Rect _boxRect(WidgetTester tester) {
  return tester.getRect(
    find
        .ancestor(of: find.text(_message), matching: find.byType(DecoratedBox))
        .first,
  );
}

/// Sizes the view to [size] at a pixel ratio of 1, so overlay and view
/// coordinates are the same logical pixels.
void _sizeView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(WindParser.clearCache);

  final WindThemeData lightTheme = WindThemeData(brightness: Brightness.light);
  final WindThemeData darkTheme = WindThemeData(brightness: Brightness.dark);

  group('WTooltip', () {
    group('Triggers', () {
      testWidgets('shows the message after the hover delay (#323)', (
        tester,
      ) async {
        await tester.pumpWidget(wrapWithTheme(_tooltip()));
        final TestGesture gesture = await _mouse(tester);

        await gesture.moveTo(tester.getCenter(find.byKey(_triggerKey)));
        await tester.pump(const Duration(milliseconds: 499));
        expect(find.text(_message), findsNothing);

        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text(_message), findsOneWidget);
      });

      testWidgets('hides the message after the pointer leaves (#323)', (
        tester,
      ) async {
        await tester.pumpWidget(wrapWithTheme(_tooltip()));
        final TestGesture gesture = await _showByHover(tester);
        expect(find.text(_message), findsOneWidget);

        await gesture.moveTo(const Offset(700, 500));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text(_message), findsNothing);
      });

      testWidgets(
        'shows on long press and hides after the touch delay (#323)',
        (tester) async {
          await tester.pumpWidget(wrapWithTheme(_tooltip()));

          await tester.longPress(find.byKey(_triggerKey));
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.text(_message), findsOneWidget);

          await tester.pump(const Duration(milliseconds: 1000));
          expect(find.text(_message), findsOneWidget);

          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.text(_message), findsNothing);
        },
      );
    });

    group('Semantics', () {
      testWidgets('reports the message as the child tooltip (#323)', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(wrapWithTheme(_tooltip()));

          final SemanticsNode node = tester.getSemantics(
            find.byKey(_triggerKey),
          );

          expect(node.getSemanticsData().tooltip, _message);
        } finally {
          handle.dispose();
        }
      });

      testWidgets(
        'exposes no tooltip and no overlay for an empty message (#323)',
        (tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          try {
            await tester.pumpWidget(wrapWithTheme(_tooltip(message: '')));
            final TestGesture gesture = await _mouse(tester);
            await gesture.moveTo(tester.getCenter(find.byKey(_triggerKey)));
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pump(const Duration(milliseconds: 200));

            expect(find.byType(WText), findsNothing);
            expect(
              tester
                  .getSemantics(find.byKey(_triggerKey))
                  .getSemanticsData()
                  .tooltip,
              isEmpty,
            );
          } finally {
            handle.dispose();
          }
        },
      );
    });

    group('Styling', () {
      testWidgets('paints the box with gray-900 in light mode (#323)', (
        tester,
      ) async {
        await tester.pumpWidget(wrapWithTheme(_tooltip()));
        await _showByHover(tester);

        expect(_boxFill(tester), lightTheme.colors['gray']![900]);
      });

      testWidgets('paints the box with gray-100 in dark mode (#323)', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(_tooltip(), brightness: Brightness.dark),
        );
        await _showByHover(tester);

        expect(_boxFill(tester), darkTheme.colors['gray']![100]);
      });

      testWidgets('replaces the default fill with a custom className (#323)', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            _tooltip(className: 'bg-red-500 dark:bg-red-500 text-xs px-2 py-1'),
          ),
        );
        await _showByHover(tester);

        expect(_boxFill(tester), lightTheme.colors['red']![500]);
      });

      testWidgets('shrink-wraps a short message (#323)', (tester) async {
        await tester.pumpWidget(wrapWithTheme(_tooltip()));
        await _showByHover(tester);

        final Finder box = find
            .ancestor(
              of: find.text(_message),
              matching: find.byType(DecoratedBox),
            )
            .first;

        expect(tester.getSize(box).width, lessThan(200));
        expect(
          tester.getSize(box).width,
          lessThan(tester.view.physicalSize.width / 2),
        );
      });
    });

    group('Position', () {
      const Offset gap = Offset(6, 10);

      for (final PopoverAlignment alignment in PopoverAlignment.values) {
        testWidgets('places the box for $alignment (#323)', (tester) async {
          _sizeView(tester, const Size(800, 600));
          await tester.pumpWidget(
            wrapWithTheme(
              _tooltip(alignment: alignment, offset: gap),
              placement: Alignment.center,
            ),
          );
          await _showByHover(tester);

          final Rect child = tester.getRect(find.byKey(_triggerKey));
          final Rect box = _boxRect(tester);
          final String name = alignment.name;

          if (name.startsWith('bottom')) {
            expect(box.top, closeTo(child.bottom + gap.dy, 0.01));
          } else {
            expect(box.bottom, closeTo(child.top - gap.dy, 0.01));
          }

          if (name.endsWith('Left')) {
            expect(box.left, closeTo(child.left + gap.dx, 0.01));
          } else if (name.endsWith('Right')) {
            expect(box.right, closeTo(child.right + gap.dx, 0.01));
          } else {
            expect(box.center.dx, closeTo(child.center.dx + gap.dx, 0.01));
          }
        });
      }

      testWidgets(
        'keeps the box inside a narrow view at the right edge (#323)',
        (tester) async {
          _sizeView(tester, const Size(300, 600));
          await tester.pumpWidget(
            wrapWithTheme(_tooltip(), placement: Alignment.centerRight),
          );
          await _showByHover(tester);

          final Rect box = _boxRect(tester);

          expect(box.left, greaterThanOrEqualTo(0));
          expect(box.right, lessThanOrEqualTo(300));
        },
      );

      testWidgets(
        'keeps the box inside a narrow view at the left edge (#323)',
        (tester) async {
          _sizeView(tester, const Size(300, 600));
          await tester.pumpWidget(
            wrapWithTheme(_tooltip(), placement: Alignment.centerLeft),
          );
          await _showByHover(tester);

          final Rect box = _boxRect(tester);

          expect(box.left, greaterThanOrEqualTo(0));
          expect(box.right, lessThanOrEqualTo(300));
        },
      );

      testWidgets(
        'opens below a top-aligned tooltip with no room above (#323)',
        (tester) async {
          _sizeView(tester, const Size(800, 600));
          await tester.pumpWidget(
            wrapWithTheme(
              _tooltip(alignment: PopoverAlignment.topCenter),
              placement: Alignment.topCenter,
            ),
          );
          await _showByHover(tester);

          final Rect child = tester.getRect(find.byKey(_triggerKey));

          expect(_boxRect(tester).top, closeTo(child.bottom + 4, 0.01));
        },
      );

      testWidgets(
        'opens above a bottom-aligned tooltip with no room below (#323)',
        (tester) async {
          _sizeView(tester, const Size(800, 600));
          await tester.pumpWidget(
            wrapWithTheme(_tooltip(), placement: Alignment.bottomCenter),
          );
          await _showByHover(tester);

          final Rect child = tester.getRect(find.byKey(_triggerKey));

          expect(_boxRect(tester).bottom, closeTo(child.top - 4, 0.01));
        },
      );

      testWidgets('keeps a box taller than both sides inside the view (#323)', (
        tester,
      ) async {
        _sizeView(tester, const Size(800, 200));
        await tester.pumpWidget(
          wrapWithTheme(
            _tooltip(className: 'bg-gray-900 dark:bg-gray-100 h-36 px-2'),
            placement: Alignment.center,
          ),
        );
        await _showByHover(tester);

        final Rect box = _boxRect(tester);

        expect(box.height, greaterThan(72));
        expect(box.top, greaterThanOrEqualTo(8));
        expect(box.bottom, lessThanOrEqualTo(200 - 8));
      });
    });
  });
}
