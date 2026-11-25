import 'dart:async';

import 'package:flutter/services.dart';
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
  SelectOption(value: 'banana', label: 'Banana', disabled: true),
  SelectOption(value: 'cherry', label: 'Cherry'),
  SelectOption(value: 'date', label: 'Date'),
  SelectOption(value: 'elder', label: 'Elder', disabled: true),
];

/// Builds rows that record the `isHovered` they were last built with.
SelectItemBuilder<String> _recording(Map<String, bool> seen) {
  return (context, option, isSelected, isHovered) {
    seen[option.label] = isHovered;
    return SizedBox(height: 32, child: Text(option.label));
  };
}

/// The labels of the rows currently drawn as highlighted.
List<String> _highlighted(Map<String, bool> seen) {
  return seen.entries
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toList();
}

WSelect<String> _select({
  required Map<String, bool> seen,
  String? value,
  ValueChanged<String>? onChange,
  bool searchable = false,
  bool disabled = false,
  List<SelectOption<String>> options = _options,
  double maxMenuHeight = 300,
}) {
  return WSelect<String>(
    options: options,
    value: value,
    onChange: onChange ?? (_) {},
    searchable: searchable,
    disabled: disabled,
    maxMenuHeight: maxMenuHeight,
    itemBuilder: _recording(seen),
  );
}

Future<void> _tapOpen(WidgetTester tester) async {
  await tester.tap(find.text('Select an option'));
  await tester.pumpAndSettle();
}

Future<void> _focusTrigger(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

/// Whether the primary focus is the select's own trigger focus node.
bool _triggerHasPrimaryFocus() {
  final BuildContext? context = FocusManager.instance.primaryFocus?.context;

  return context != null &&
      context.widget is Focus &&
      context.findAncestorWidgetOfExactType<WSelect<String>>() != null;
}

FocusNode _searchFocusNode(WidgetTester tester) {
  return tester.widget<EditableText>(find.byType(EditableText)).focusNode;
}

void main() {
  setUp(WindParser.clearCache);

  group('WSelect keyboard', () {
    testWidgets('opens on Enter when the trigger has focus (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      await tester.pumpWidget(wrapWithTheme(_select(seen: seen)));

      await _focusTrigger(tester);
      await _press(tester, LogicalKeyboardKey.enter);

      expect(find.text('Cherry'), findsOneWidget);
    });

    testWidgets('opens on Space when the trigger has focus (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      await tester.pumpWidget(wrapWithTheme(_select(seen: seen)));

      await _focusTrigger(tester);
      await _press(tester, LogicalKeyboardKey.space);

      expect(find.text('Cherry'), findsOneWidget);
    });

    testWidgets('opens on ArrowDown when the trigger has focus (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      await tester.pumpWidget(wrapWithTheme(_select(seen: seen)));

      await _focusTrigger(tester);
      await _press(tester, LogicalKeyboardKey.arrowDown);

      expect(find.text('Cherry'), findsOneWidget);
    });

    testWidgets('leaves ArrowUp on a closed select to focus traversal (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      final FocusNode after = FocusNode(debugLabel: 'after');
      addTearDown(after.dispose);

      await tester.pumpWidget(
        wrapWithTheme(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _select(seen: seen),
              Focus(focusNode: after, child: const SizedBox(height: 10)),
            ],
          ),
        ),
      );

      await _focusTrigger(tester);
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(find.text('Cherry'), findsNothing);

      await _press(tester, LogicalKeyboardKey.tab);
      expect(after.hasPrimaryFocus, isTrue);
    });

    testWidgets(
      'highlights the first enabled option then skips a disabled one (#322)',
      (tester) async {
        final Map<String, bool> seen = {};
        await tester.pumpWidget(wrapWithTheme(_select(seen: seen)));

        await _tapOpen(tester);
        expect(_highlighted(seen), isEmpty);

        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(_highlighted(seen), ['Apple']);

        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(_highlighted(seen), ['Cherry']);
      },
    );

    testWidgets('moves the highlight back up on ArrowUp (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      await tester.pumpWidget(wrapWithTheme(_select(seen: seen)));

      await _tapOpen(tester);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.arrowUp);

      expect(_highlighted(seen), ['Apple']);
    });

    testWidgets('starts from the last enabled option on ArrowUp (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      await tester.pumpWidget(wrapWithTheme(_select(seen: seen)));

      await _tapOpen(tester);
      await _press(tester, LogicalKeyboardKey.arrowUp);

      expect(_highlighted(seen), ['Date']);
    });

    testWidgets('stops at the first and last enabled option (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      await tester.pumpWidget(wrapWithTheme(_select(seen: seen)));

      await _tapOpen(tester);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_highlighted(seen), ['Apple']);

      await _press(tester, LogicalKeyboardKey.end);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_highlighted(seen), ['Date']);
    });

    testWidgets(
      'jumps to the first and last enabled option on Home and End (#322)',
      (tester) async {
        final Map<String, bool> seen = {};
        await tester.pumpWidget(wrapWithTheme(_select(seen: seen)));

        await _tapOpen(tester);
        await _press(tester, LogicalKeyboardKey.end);
        expect(_highlighted(seen), ['Date']);

        await _press(tester, LogicalKeyboardKey.home);
        expect(_highlighted(seen), ['Apple']);
      },
    );

    testWidgets('selects the highlighted option on Enter (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      final List<String> changes = [];
      await tester.pumpWidget(
        wrapWithTheme(_select(seen: seen, onChange: changes.add)),
      );

      await _tapOpen(tester);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.enter);

      expect(changes, ['cherry']);
      expect(find.text('Cherry'), findsNothing);
      expect(_triggerHasPrimaryFocus(), isTrue);
    });

    testWidgets('selects the highlighted option on Space (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      final List<String> changes = [];
      await tester.pumpWidget(
        wrapWithTheme(_select(seen: seen, onChange: changes.add)),
      );

      await _tapOpen(tester);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.space);

      expect(changes, ['apple']);
      expect(find.text('Cherry'), findsNothing);
    });

    testWidgets('does nothing on Enter while no option is highlighted (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      final List<String> changes = [];
      await tester.pumpWidget(
        wrapWithTheme(_select(seen: seen, onChange: changes.add)),
      );

      await _tapOpen(tester);
      await _press(tester, LogicalKeyboardKey.enter);

      expect(changes, isEmpty);
      expect(find.text('Cherry'), findsOneWidget);
    });

    testWidgets(
      'toggles a multi option on Enter and keeps the menu open (#322)',
      (tester) async {
        final Map<String, bool> seen = {};
        final List<List<String>> changes = [];
        await tester.pumpWidget(
          wrapWithTheme(
            WSelect<String>(
              options: _options,
              isMulti: true,
              values: const [],
              onMultiChange: changes.add,
              itemBuilder: _recording(seen),
            ),
          ),
        );

        await _focusTrigger(tester);
        await _press(tester, LogicalKeyboardKey.enter);
        await _press(tester, LogicalKeyboardKey.enter);

        expect(changes, [
          ['apple'],
        ]);
        expect(find.text('Cherry'), findsOneWidget);
        expect(_highlighted(seen), ['Apple']);
      },
    );

    testWidgets('closes on Escape and returns focus to the trigger (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      await tester.pumpWidget(wrapWithTheme(_select(seen: seen)));

      await _tapOpen(tester);
      await _press(tester, LogicalKeyboardKey.escape);

      expect(find.text('Cherry'), findsNothing);
      expect(_triggerHasPrimaryFocus(), isTrue);
    });

    testWidgets(
      'keeps a sibling focus node out of reach on ArrowDown while open (#322)',
      (tester) async {
        final Map<String, bool> seen = {};
        final FocusNode after = FocusNode(debugLabel: 'after');
        addTearDown(after.dispose);

        await tester.pumpWidget(
          wrapWithTheme(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _select(seen: seen),
                Focus(focusNode: after, child: const SizedBox(height: 10)),
              ],
            ),
          ),
        );

        await _tapOpen(tester);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.arrowDown);

        expect(after.hasFocus, isFalse);
        expect(_highlighted(seen), ['Cherry']);
      },
    );

    testWidgets('ignores Enter on a disabled select (#322)', (tester) async {
      final Map<String, bool> seen = {};
      await tester.pumpWidget(
        wrapWithTheme(_select(seen: seen, disabled: true)),
      );

      await _focusTrigger(tester);
      await _press(tester, LogicalKeyboardKey.enter);

      expect(find.text('Cherry'), findsNothing);
    });

    testWidgets('highlights on ArrowDown after a mouse open (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      await tester.pumpWidget(wrapWithTheme(_select(seen: seen)));

      await _tapOpen(tester);
      expect(_triggerHasPrimaryFocus(), isTrue);

      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_highlighted(seen), ['Apple']);
    });

    testWidgets('highlights the selected option after a keyboard open (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      await tester.pumpWidget(
        wrapWithTheme(_select(seen: seen, value: 'cherry')),
      );

      await _focusTrigger(tester);
      await _press(tester, LogicalKeyboardKey.enter);

      expect(_highlighted(seen), ['Cherry']);
    });

    testWidgets('scrolls the last row into view on End in a long list (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      final List<SelectOption<String>> many = List.generate(
        60,
        (int i) => SelectOption(value: 'o$i', label: 'Option $i'),
      );
      await tester.pumpWidget(
        wrapWithTheme(_select(seen: seen, options: many, maxMenuHeight: 200)),
      );

      await _tapOpen(tester);
      await _press(tester, LogicalKeyboardKey.end);

      final Rect menu = tester.getRect(
        find
            .ancestor(
              of: find.text('Option 59'),
              matching: find.byType(Container),
            )
            .first,
      );
      final Rect last = tester.getRect(find.text('Option 59'));
      expect(_highlighted(seen), ['Option 59']);
      expect(menu.contains(last.topLeft), isTrue);
      expect(menu.contains(last.bottomRight), isTrue);
    });

    testWidgets('scrolls a selected option far down into view on open (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      final List<SelectOption<String>> many = List.generate(
        60,
        (int i) => SelectOption(value: 'o$i', label: 'Option $i'),
      );
      await tester.pumpWidget(
        wrapWithTheme(
          _select(seen: seen, options: many, value: 'o40', maxMenuHeight: 200),
        ),
      );

      await _focusTrigger(tester);
      await _press(tester, LogicalKeyboardKey.enter);

      final Rect menu = tester.getRect(
        find
            .ancestor(
              of: find.text('Option 40').last,
              matching: find.byType(Container),
            )
            .first,
      );
      final Rect row = tester.getRect(find.text('Option 40').last);
      expect(_highlighted(seen), contains('Option 40'));
      expect(menu.contains(row.topLeft), isTrue);
      expect(menu.contains(row.bottomRight), isTrue);
    });

    testWidgets('opens on the D-pad select key (#322)', (tester) async {
      final Map<String, bool> seen = {};
      await tester.pumpWidget(wrapWithTheme(_select(seen: seen)));

      await _focusTrigger(tester);
      await _press(tester, LogicalKeyboardKey.select);

      expect(find.text('Cherry'), findsOneWidget);
    });

    testWidgets('selects the highlighted option on NumpadEnter (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      String? chosen;
      await tester.pumpWidget(
        wrapWithTheme(_select(seen: seen, onChange: (v) => chosen = v)),
      );

      await _tapOpen(tester);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.numpadEnter);

      expect(chosen, 'apple');
    });

    testWidgets('keeps moving the highlight on a held arrow key (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      await tester.pumpWidget(wrapWithTheme(_select(seen: seen)));

      await _tapOpen(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(_highlighted(seen), ['Cherry']);
    });

    testWidgets(
      'keeps the highlight on its option when options change (#322)',
      (tester) async {
        final Map<String, bool> seen = {};
        await tester.pumpWidget(wrapWithTheme(_select(seen: seen)));

        await _tapOpen(tester);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(_highlighted(seen), ['Cherry']);

        await tester.pumpWidget(
          wrapWithTheme(_select(seen: seen, options: [..._options])),
        );
        await tester.pumpAndSettle();

        expect(_highlighted(seen), ['Cherry']);
      },
    );
  });

  group('WSelect searchable keyboard', () {
    testWidgets(
      'keeps primary focus in the search field on a keyboard open (#322)',
      (tester) async {
        final Map<String, bool> seen = {};
        await tester.pumpWidget(
          wrapWithTheme(_select(seen: seen, searchable: true)),
        );

        await _focusTrigger(tester);
        await _press(tester, LogicalKeyboardKey.enter);

        expect(_searchFocusNode(tester).hasPrimaryFocus, isTrue);
      },
    );

    testWidgets('highlights from the search field on ArrowDown (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      await tester.pumpWidget(
        wrapWithTheme(_select(seen: seen, searchable: true)),
      );

      await _tapOpen(tester);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.arrowDown);

      expect(_highlighted(seen), ['Cherry']);
      expect(_searchFocusNode(tester).hasPrimaryFocus, isTrue);
    });

    testWidgets(
      'selects the highlighted option on Enter from the search field (#322)',
      (tester) async {
        final Map<String, bool> seen = {};
        final List<String> changes = [];
        await tester.pumpWidget(
          wrapWithTheme(
            _select(seen: seen, searchable: true, onChange: changes.add),
          ),
        );

        await _tapOpen(tester);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.enter);

        expect(changes, ['apple']);
        expect(find.text('Cherry'), findsNothing);
        expect(_triggerHasPrimaryFocus(), isTrue);
      },
    );

    testWidgets('closes on Escape from the search field (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      await tester.pumpWidget(
        wrapWithTheme(_select(seen: seen, searchable: true)),
      );

      await _tapOpen(tester);
      await _press(tester, LogicalKeyboardKey.escape);

      expect(find.text('Cherry'), findsNothing);
      expect(_triggerHasPrimaryFocus(), isTrue);
    });

    testWidgets(
      'leaves Space to the search field instead of selecting (#322)',
      (tester) async {
        final Map<String, bool> seen = {};
        final List<String> changes = [];
        await tester.pumpWidget(
          wrapWithTheme(
            _select(seen: seen, searchable: true, onChange: changes.add),
          ),
        );

        await _tapOpen(tester);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.space);

        expect(changes, isEmpty);
        expect(find.text('Cherry'), findsOneWidget);
        expect(_searchFocusNode(tester).hasPrimaryFocus, isTrue);
      },
    );

    testWidgets('leaves Home to the search field caret (#322)', (tester) async {
      final Map<String, bool> seen = {};
      await tester.pumpWidget(
        wrapWithTheme(_select(seen: seen, searchable: true)),
      );

      await _tapOpen(tester);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.home);

      expect(_highlighted(seen), ['Cherry']);
    });

    testWidgets('resets the highlight when a filter is typed (#322)', (
      tester,
    ) async {
      final Map<String, bool> seen = {};
      await tester.pumpWidget(
        wrapWithTheme(_select(seen: seen, searchable: true)),
      );

      await _tapOpen(tester);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_highlighted(seen), ['Apple']);

      await tester.enterText(find.byType(EditableText), 'a');
      await tester.pumpAndSettle();

      expect(_highlighted(seen), isEmpty);
    });

    testWidgets(
      'ignores the arrows and Enter while a search is pending (#322)',
      (tester) async {
        final Map<String, bool> seen = {};
        final Completer<List<SelectOption<String>>> pending =
            Completer<List<SelectOption<String>>>();
        String? chosen;
        await tester.pumpWidget(
          wrapWithTheme(
            WSelect<String>(
              options: _options,
              searchable: true,
              onChange: (v) => chosen = v,
              onSearch: (_) => pending.future,
              itemBuilder: _recording(seen),
            ),
          ),
        );

        await _tapOpen(tester);
        await tester.enterText(find.byType(EditableText), 'a');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(chosen, isNull);

        pending.complete(_options);
        await tester.pumpAndSettle();

        expect(_highlighted(seen), isEmpty);
      },
    );
  });
}
