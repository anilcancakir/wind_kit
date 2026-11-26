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

Future<void> _open(WidgetTester tester, String triggerText) async {
  await tester.tap(find.text(triggerText));
  await tester.pumpAndSettle();
}

/// The decoration of the menu surface: the [Container] above [optionText]
/// that carries a [BoxDecoration].
BoxDecoration _menuDecoration(WidgetTester tester, String optionText) {
  final Finder surface = find.ancestor(
    of: find.text(optionText),
    matching: find.byWidgetPredicate(
      (Widget w) => w is Container && w.decoration is BoxDecoration,
    ),
  );
  return tester.widget<Container>(surface.first).decoration! as BoxDecoration;
}

/// The colour painted by the nearest decorated box above [of] that has one.
Color? _nearestFill(WidgetTester tester, Finder of) {
  for (final Element element
      in find
          .ancestor(of: of, matching: find.byType(DecoratedBox))
          .evaluate()) {
    final Decoration decoration = (element.widget as DecoratedBox).decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration.color;
    }
  }
  return null;
}

Color _border(BoxDecoration decoration) =>
    (decoration.border! as Border).top.color;

void main() {
  setUp(WindParser.clearCache);

  final WindThemeData darkTheme = WindThemeData(brightness: Brightness.dark);
  final Color gray800 = darkTheme.colors['gray']![800]!;
  final Color gray700 = darkTheme.colors['gray']![700]!;
  final Color gray600 = darkTheme.colors['gray']![600]!;
  final Color gray400 = darkTheme.colors['gray']![400]!;
  final MaterialColor primary = darkTheme.colors['primary']!;

  group('WSelect dark defaults', () {
    testWidgets('paints the menu surface with the dark gray (#320)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WSelect<String>(options: _options, onChange: (_) {}),
          brightness: Brightness.dark,
        ),
      );
      await _open(tester, 'Select an option');

      expect(_menuDecoration(tester, 'Apple').color, gray800);
    });

    testWidgets('paints the menu border with gray 700 in dark (#320)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WSelect<String>(options: _options, onChange: (_) {}),
          brightness: Brightness.dark,
        ),
      );
      await _open(tester, 'Select an option');

      expect(_border(_menuDecoration(tester, 'Apple')), gray700);
    });

    testWidgets('deepens the menu shadow to alpha 0.4 in dark (#320)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WSelect<String>(options: _options, onChange: (_) {}),
          brightness: Brightness.dark,
        ),
      );
      await _open(tester, 'Select an option');

      final BoxShadow shadow = _menuDecoration(
        tester,
        'Apple',
      ).boxShadow!.single;
      expect(shadow.color.a, closeTo(0.4, 0.01));
    });

    testWidgets('paints the default trigger with the dark gray (#320)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WSelect<String>(options: _options, onChange: (_) {}),
          brightness: Brightness.dark,
        ),
      );

      expect(_nearestFill(tester, find.text('Select an option')), gray800);
    });

    testWidgets('lightens the chevron in dark (#320)', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WSelect<String>(options: _options, onChange: (_) {}),
          brightness: Brightness.dark,
        ),
      );

      final Icon chevron = tester.widget<Icon>(
        find.byIcon(Icons.keyboard_arrow_down),
      );
      expect(chevron.color, Colors.grey.shade400);
    });

    testWidgets('paints default chips with the dark primary pair (#320)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WSelect<String>(
            isMulti: true,
            values: const ['apple'],
            options: _options,
            onMultiChange: (_) {},
          ),
          brightness: Brightness.dark,
        ),
      );

      final Color chipFill = _nearestFill(tester, find.text('Apple'))!;
      expect(chipFill.withValues(alpha: 1), primary[900]);
      expect(chipFill.a, closeTo(0.4, 0.01));
      expect(tester.widget<Icon>(find.byIcon(Icons.close)).color, primary[300]);
    });

    testWidgets('draws the search input border in gray 600 in dark (#320)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WSelect<String>(
            searchable: true,
            options: _options,
            onChange: (_) {},
          ),
          brightness: Brightness.dark,
        ),
      );
      await _open(tester, 'Select an option');

      Color? borderColour;
      for (final Element element
          in find
              .ancestor(
                of: find.byType(EditableText),
                matching: find.byType(DecoratedBox),
              )
              .evaluate()) {
        final Decoration decoration =
            (element.widget as DecoratedBox).decoration;
        if (decoration is BoxDecoration && decoration.border is Border) {
          borderColour = (decoration.border! as Border).top.color;
          break;
        }
      }
      expect(borderColour, gray600);
    });

    testWidgets('lightens the empty state text in dark (#320)', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WSelect<String>(options: const [], onChange: (_) {}),
          brightness: Brightness.dark,
        ),
      );
      await _open(tester, 'Select an option');

      expect(
        tester.widget<Text>(find.text('No options found')).style?.color,
        gray400,
      );
    });

    testWidgets('lifts the check icon to primary 400 in dark (#320)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WSelect<String>(value: 'apple', options: _options, onChange: (_) {}),
          brightness: Brightness.dark,
        ),
      );
      await _open(tester, 'Apple');

      expect(tester.widget<Icon>(find.byIcon(Icons.check)).color, primary[400]);
    });

    testWidgets('swaps the multi checkbox shades in dark (#320)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WSelect<String>(
            isMulti: true,
            values: const ['apple'],
            options: _options,
            onMultiChange: (_) {},
          ),
          brightness: Brightness.dark,
        ),
      );
      await _open(tester, 'Apple');

      expect(
        tester.widget<Icon>(find.byIcon(Icons.check_box)).color,
        primary[400],
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.check_box_outline_blank)).color,
        Colors.grey.shade600,
      );
    });
  });

  group('WSelect light defaults', () {
    testWidgets('keeps the white surface, border, shadow and chevron (#320)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(WSelect<String>(options: _options, onChange: (_) {})),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.keyboard_arrow_down)).color,
        Colors.grey.shade600,
      );
      await _open(tester, 'Select an option');

      final BoxDecoration decoration = _menuDecoration(tester, 'Apple');
      expect(decoration.color, const Color(0xFFFFFFFF));
      expect(_border(decoration), Colors.grey.shade200);
      final BoxShadow shadow = decoration.boxShadow!.single;
      expect(shadow.color.withValues(alpha: 1), Colors.black);
      expect(shadow.color.a, closeTo(0.1, 0.01));
    });
  });

  group('WSelect menuClassName', () {
    testWidgets('keeps the rounded-xl radius and fills the surface (#320)', (
      tester,
    ) async {
      for (final Brightness brightness in Brightness.values) {
        WindParser.clearCache();
        await tester.pumpWidget(
          wrapWithTheme(
            WSelect<String>(
              options: _options,
              onChange: (_) {},
              menuClassName: 'rounded-xl',
            ),
            brightness: brightness,
          ),
        );
        await _open(tester, 'Select an option');

        final BoxDecoration decoration = _menuDecoration(tester, 'Apple');
        expect(decoration.borderRadius, BorderRadius.circular(12));
        expect(
          decoration.color,
          brightness == Brightness.dark ? gray800 : const Color(0xFFFFFFFF),
        );

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('lets a user background win in dark (#320)', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WSelect<String>(
            options: _options,
            onChange: (_) {},
            menuClassName: 'bg-red-500',
          ),
          brightness: Brightness.dark,
        ),
      );
      await _open(tester, 'Select an option');

      expect(
        _menuDecoration(tester, 'Apple').color,
        darkTheme.colors['red']![500],
      );
    });

    testWidgets('gives a width-only class the full default decoration (#320)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WSelect<String>(
            options: _options,
            onChange: (_) {},
            menuClassName: 'w-64',
          ),
          brightness: Brightness.dark,
        ),
      );
      await _open(tester, 'Select an option');

      final BoxDecoration decoration = _menuDecoration(tester, 'Apple');
      expect(decoration.color, gray800);
      expect(_border(decoration), gray700);
      expect(decoration.boxShadow, isNotEmpty);
    });
  });
}
