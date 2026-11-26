import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wind_kit/wind_kit.dart';

const Key _bodyKey = Key('popover-body');

/// A 390x844 phone surface with a 40x40 trigger whose top sits at [top].
Widget _host({required double top, required WPopover popover}) => MaterialApp(
  home: WindTheme(
    data: WindThemeData(),
    child: Scaffold(
      body: Stack(
        children: <Widget>[Positioned(left: 300, top: top, child: popover)],
      ),
    ),
  ),
);

WPopover _popover({required double bodyHeight, bool autoFlip = true}) {
  return WPopover(
    alignment: PopoverAlignment.bottomRight,
    autoFlip: autoFlip,
    className: 'bg-white dark:bg-gray-800',
    width: 200,
    triggerBuilder: (context, isOpen, isHovering) =>
        const SizedBox(width: 40, height: 40, child: WText('Trigger')),
    contentBuilder: (context, close) =>
        SizedBox(key: _bodyKey, height: bodyHeight, child: const WText('Body')),
  );
}

void main() {
  setUp(WindParser.clearCache);

  Future<void> pumpPhone(WidgetTester tester, WPopover popover) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(top: 520, popover: popover));
  }

  Rect trigger(WidgetTester tester) => tester.getRect(find.text('Trigger'));

  Rect panel(WidgetTester tester) => tester.getRect(find.byKey(_bodyKey));

  /// The opacity of the nearest [Opacity] above the panel body, or 1 when
  /// there is none.
  double panelOpacity(WidgetTester tester) {
    final Iterable<Opacity> opacities = tester.widgetList<Opacity>(
      find.ancestor(of: find.byKey(_bodyKey), matching: find.byType(Opacity)),
    );

    return opacities.isEmpty ? 1 : opacities.first.opacity;
  }

  group('WPopover auto-flip on the measured panel height', () {
    testWidgets('a short panel in the lower half opens below its trigger', (
      tester,
    ) async {
      // 140 px fits in the 280 px below the trigger, although the 400 px
      // maxHeight estimate does not.
      await pumpPhone(tester, _popover(bodyHeight: 140));
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(panel(tester).top, greaterThanOrEqualTo(trigger(tester).bottom));
      expect(panel(tester).height, 140);
      expect(panelOpacity(tester), 1);
    });

    testWidgets('no frame paints the short panel above its trigger', (
      tester,
    ) async {
      await pumpPhone(tester, _popover(bodyHeight: 140));
      await tester.tap(find.text('Trigger'));

      for (int frame = 0; frame < 3; frame++) {
        await tester.pump();
        final bool painted = panelOpacity(tester) > 0;
        final bool below = panel(tester).top >= trigger(tester).bottom;
        expect(
          !painted || below,
          isTrue,
          reason: 'frame $frame painted the panel above the trigger',
        );
      }
      expect(panelOpacity(tester), 1);
    });

    testWidgets('a panel taller than the room below still flips above', (
      tester,
    ) async {
      // 400 px (capped from 500) against 280 below and 516 above.
      await pumpPhone(tester, _popover(bodyHeight: 500));
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(panel(tester).bottom, lessThanOrEqualTo(trigger(tester).top));
      expect(panel(tester).height, 400);
      expect(panelOpacity(tester), 1);
    });

    testWidgets('re-opening measures the content again', (tester) async {
      double bodyHeight = 140;
      final PopoverController controller = PopoverController();
      addTearDown(controller.dispose);
      await pumpPhone(
        tester,
        WPopover(
          controller: controller,
          alignment: PopoverAlignment.bottomRight,
          className: 'bg-white dark:bg-gray-800',
          width: 200,
          triggerBuilder: (context, isOpen, isHovering) =>
              const SizedBox(width: 40, height: 40, child: WText('Trigger')),
          contentBuilder: (context, close) => SizedBox(
            key: _bodyKey,
            height: bodyHeight,
            child: const WText('Body'),
          ),
        ),
      );

      controller.show();
      await tester.pumpAndSettle();
      expect(panel(tester).top, greaterThanOrEqualTo(trigger(tester).bottom));

      controller.hide();
      await tester.pumpAndSettle();
      bodyHeight = 500;
      controller.show();
      await tester.pumpAndSettle();
      expect(panel(tester).bottom, lessThanOrEqualTo(trigger(tester).top));
    });

    testWidgets('autoFlip false keeps the requested side without measuring', (
      tester,
    ) async {
      await pumpPhone(tester, _popover(bodyHeight: 500, autoFlip: false));
      await tester.tap(find.text('Trigger'));
      await tester.pump();

      // Painted on the first frame, below the trigger, at its full height.
      expect(panelOpacity(tester), 1);
      expect(panel(tester).top, greaterThanOrEqualTo(trigger(tester).bottom));
      expect(panel(tester).height, 400);
    });
  });
}
