import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wind_kit/wind_kit.dart';

Widget wrapWithTheme(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    home: WindTheme(
      data: WindThemeData(brightness: brightness, syncWithSystem: false),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
}

const List<SelectOption<String>> _options = [
  SelectOption(value: 'apple', label: 'Apple'),
  SelectOption(value: 'banana', label: 'Banana'),
];

void _useWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Places [child] against the right edge of the padded body.
Widget _atRight(Widget child) {
  return SizedBox(
    width: double.infinity,
    child: Align(alignment: Alignment.topRight, child: child),
  );
}

WSelect<String> _select({String? menuClassName, double? menuWidth}) {
  return WSelect<String>(
    options: _options,
    onChange: (_) {},
    className: 'w-32 p-3 border rounded-lg',
    menuClassName: menuClassName,
    menuWidth: menuWidth,
  );
}

Rect _menuRect(WidgetTester tester) {
  return tester.getRect(
    find
        .ancestor(of: find.text('Apple'), matching: find.byType(Container))
        .first,
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Select an option'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(WindParser.clearCache);

  group('WSelect menu position', () {
    testWidgets('pulls a wide menu back inside the right edge (#319)', (
      tester,
    ) async {
      _useWindow(tester);
      await tester.pumpWidget(
        wrapWithTheme(_atRight(_select(menuClassName: 'w-64'))),
      );
      await _open(tester);

      final Rect menu = _menuRect(tester);
      expect(menu.right, closeTo(792, 0.5));
      expect(menu.right, lessThanOrEqualTo(800));
      expect(menu.width, closeTo(256, 0.5));
    });

    testWidgets('leaves a menu flush with the trigger left in place (#319)', (
      tester,
    ) async {
      _useWindow(tester);
      await tester.pumpWidget(wrapWithTheme(_select()));
      await _open(tester);

      final Rect trigger = tester.getRect(find.byType(WSelect<String>));
      expect(_menuRect(tester).left, closeTo(trigger.left, 0.5));
    });

    testWidgets('keeps a menu narrower than the trigger aligned left (#319)', (
      tester,
    ) async {
      _useWindow(tester);
      await tester.pumpWidget(wrapWithTheme(_atRight(_select(menuWidth: 100))));
      await _open(tester);

      final Rect trigger = tester.getRect(find.byType(WSelect<String>));
      final Rect menu = _menuRect(tester);
      expect(menu.left, closeTo(trigger.left, 0.5));
      expect(menu.width, closeTo(100, 0.5));
      expect(menu.right, lessThanOrEqualTo(800));
    });

    testWidgets('clamps an upward menu inside the right edge (#319)', (
      tester,
    ) async {
      _useWindow(tester);
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            width: double.infinity,
            height: 568,
            child: Align(
              alignment: Alignment.bottomRight,
              child: _select(menuClassName: 'w-64'),
            ),
          ),
        ),
      );
      await _open(tester);

      final Rect trigger = tester.getRect(find.byType(WSelect<String>));
      final Rect menu = _menuRect(tester);
      expect(menu.bottom, lessThanOrEqualTo(trigger.top));
      expect(menu.right, lessThanOrEqualTo(800));
      expect(menu.right, closeTo(792, 0.5));
    });
  });
}
