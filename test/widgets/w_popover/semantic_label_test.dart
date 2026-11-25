import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
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

/// A popover with an icon-only trigger, the shape that has no visible text to
/// take an accessible name from.
Widget iconPopover({String? semanticLabel, bool enableTriggerOnTap = true}) {
  return WPopover(
    semanticLabel: semanticLabel,
    enableTriggerOnTap: enableTriggerOnTap,
    triggerBuilder: (context, isOpen, isHovering) => WDiv(
      className: 'w-10 h-10 bg-white dark:bg-gray-800',
      child: const WIcon(Icons.notifications),
    ),
    contentBuilder: (context, close) => const Text('Content'),
  );
}

/// The button nodes assistive technology sees under the popover. Nodes merged
/// into a parent are not separate, so only the surviving nodes count.
List<SemanticsData> buttonNodes(WidgetTester tester) {
  final List<SemanticsData> buttons = <SemanticsData>[];
  void collect(SemanticsNode node) {
    final SemanticsData data = node.getSemanticsData();
    if (!node.isMergedIntoParent && data.flagsCollection.isButton) {
      buttons.add(data);
    }
    node.visitChildren((SemanticsNode child) {
      collect(child);
      return true;
    });
  }

  collect(tester.getSemantics(find.byType(WPopover)));

  return buttons;
}

void main() {
  setUp(WindParser.clearCache);

  group('WPopover semanticLabel', () {
    testWidgets('names the one button node of an icon-only trigger (#326)', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      try {
        await tester.pumpWidget(
          wrapWithTheme(iconPopover(semanticLabel: 'Notifications')),
        );

        final List<SemanticsData> buttons = buttonNodes(tester);

        expect(buttons, hasLength(1));
        expect(buttons.single.label, 'Notifications');
        expect(buttons.single.hasAction(SemanticsAction.tap), isTrue);
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
      'adds no duplicate button node over a callback-less WButton (#326)',
      (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        try {
          await tester.pumpWidget(
            wrapWithTheme(
              WPopover(
                semanticLabel: 'Notifications',
                triggerBuilder: (context, isOpen, isHovering) =>
                    WButton(onTap: null, child: const WText('Open Menu')),
                contentBuilder: (context, close) => const Text('Content'),
              ),
            ),
          );

          expect(buttonNodes(tester), hasLength(1));
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets('reports the trigger as collapsed while closed (#326)', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      try {
        await tester.pumpWidget(
          wrapWithTheme(iconPopover(semanticLabel: 'Notifications')),
        );

        expect(
          buttonNodes(tester).single.flagsCollection.isExpanded,
          Tristate.isFalse,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('reports the trigger as expanded once opened (#326)', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      try {
        await tester.pumpWidget(
          wrapWithTheme(iconPopover(semanticLabel: 'Notifications')),
        );

        await tester.tap(find.byType(WIcon));
        await tester.pumpAndSettle();

        expect(find.text('Content'), findsOneWidget);
        expect(
          buttonNodes(tester).first.flagsCollection.isExpanded,
          Tristate.isTrue,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
      'adds no button node and no label when enableTriggerOnTap is false (#326)',
      (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        try {
          await tester.pumpWidget(
            wrapWithTheme(
              iconPopover(
                semanticLabel: 'Notifications',
                enableTriggerOnTap: false,
              ),
            ),
          );

          expect(buttonNodes(tester), isEmpty);
          expect(find.bySemanticsLabel('Notifications'), findsNothing);
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'keeps the trigger text label when semanticLabel is null (#326)',
      (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        try {
          await tester.pumpWidget(
            wrapWithTheme(
              WPopover(
                triggerBuilder: (context, isOpen, isHovering) =>
                    WButton(onTap: null, child: const WText('Open Menu')),
                contentBuilder: (context, close) => const Text('Content'),
              ),
            ),
          );

          final List<SemanticsData> buttons = buttonNodes(tester);

          expect(buttons, hasLength(1));
          expect(buttons.single.label, 'Open Menu');
        } finally {
          handle.dispose();
        }
      },
    );
  });
}
