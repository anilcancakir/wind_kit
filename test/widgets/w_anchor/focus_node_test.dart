import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wind_kit/wind_kit.dart';

/// A node that counts its listeners, because `ChangeNotifier.hasListeners` is
/// protected and a leaked listener is otherwise invisible to a test.
class _CountingNode extends FocusNode {
  int listenerCount = 0;

  @override
  void addListener(VoidCallback listener) {
    listenerCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listenerCount--;
    super.removeListener(listener);
  }
}

/// Reads the anchor state published below it.
class _StateReader extends StatelessWidget {
  const _StateReader();

  @override
  Widget build(BuildContext context) {
    final WindAnchorState? state = WindAnchorStateProvider.of(context);

    return Text('focus:${state?.isFocused} primary:${state?.hasPrimaryFocus}');
  }
}

Widget wrapWithTheme(Widget child) {
  return MaterialApp(
    home: WindTheme(
      data: WindThemeData(),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// The `Focus` the anchor under test installed, not one from the app shell.
Finder anchorFocus() {
  return find.descendant(
    of: find.byType(WAnchor),
    matching: find.byType(Focus),
  );
}

void main() {
  setUp(WindParser.clearCache);

  group('WAnchor focusNode', () {
    testWidgets('an external node focuses the anchor and flips its state '
        '(#329)', (tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        wrapWithTheme(WAnchor(focusNode: node, child: const _StateReader())),
      );

      expect(find.text('focus:false primary:false'), findsOneWidget);

      node.requestFocus();
      await tester.pumpAndSettle();

      expect(node.hasPrimaryFocus, isTrue);
      expect(find.text('focus:true primary:true'), findsOneWidget);

      node.unfocus();
      await tester.pumpAndSettle();

      expect(find.text('focus:false primary:false'), findsOneWidget);
    });

    testWidgets('the anchor hands the given node to its Focus (#329)', (
      tester,
    ) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        wrapWithTheme(WAnchor(focusNode: node, child: const _StateReader())),
      );

      expect(tester.widget<Focus>(anchorFocus()).focusNode, same(node));
    });

    testWidgets('an already focused node styles the first frame (#329)', (
      tester,
    ) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);

      // The node holds focus under a plain Focus, then the anchor takes it
      // over: a node focused before the anchor builds must style frame one.
      await tester.pumpWidget(
        wrapWithTheme(
          Focus(focusNode: node, autofocus: true, child: const Text('plain')),
        ),
      );
      await tester.pumpAndSettle();
      expect(node.hasPrimaryFocus, isTrue);

      await tester.pumpWidget(
        wrapWithTheme(WAnchor(focusNode: node, child: const _StateReader())),
      );

      expect(find.text('focus:true primary:true'), findsOneWidget);
    });

    testWidgets('a disabled anchor with a node cannot take focus (#329)', (
      tester,
    ) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        wrapWithTheme(
          WAnchor(
            focusNode: node,
            isDisabled: true,
            child: const _StateReader(),
          ),
        ),
      );

      node.requestFocus();
      await tester.pumpAndSettle();

      expect(node.hasFocus, isFalse);
      expect(tester.widget<Focus>(anchorFocus()).canRequestFocus, isFalse);
      expect(find.text('focus:false primary:false'), findsOneWidget);
    });
  });

  group('WAnchor autofocus', () {
    testWidgets('autofocus focuses the anchor after the first frame (#329)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(WAnchor(autofocus: true, child: const _StateReader())),
      );
      await tester.pumpAndSettle();

      expect(find.text('focus:true primary:true'), findsOneWidget);
    });

    testWidgets('autofocus focuses the given node (#329)', (tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        wrapWithTheme(
          WAnchor(
            focusNode: node,
            autofocus: true,
            child: const _StateReader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(node.hasPrimaryFocus, isTrue);
      expect(find.text('focus:true primary:true'), findsOneWidget);
    });
  });

  group('WAnchor focus node lifecycle', () {
    testWidgets('unmounting disposes the owned node and spares the given one '
        '(#329)', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(WAnchor(onTap: () {}, child: const _StateReader())),
      );
      final FocusNode owned = tester.widget<Focus>(anchorFocus()).focusNode!;

      await tester.pumpWidget(const SizedBox());

      expect(() => owned.addListener(() {}), throwsFlutterError);

      final _CountingNode external = _CountingNode();
      addTearDown(external.dispose);

      await tester.pumpWidget(
        wrapWithTheme(
          WAnchor(focusNode: external, child: const _StateReader()),
        ),
      );
      await tester.pumpWidget(const SizedBox());

      expect(external.listenerCount, 0);
      expect(() => external.addListener(() {}), returnsNormally);
      expect(external.requestFocus, returnsNormally);
    });

    testWidgets('swapping one node for another moves the listener (#329)', (
      tester,
    ) async {
      final _CountingNode a = _CountingNode();
      final _CountingNode b = _CountingNode();
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      Widget anchor(FocusNode node) =>
          wrapWithTheme(WAnchor(focusNode: node, child: const _StateReader()));

      await tester.pumpWidget(anchor(a));
      a.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('focus:true primary:true'), findsOneWidget);

      await tester.pumpWidget(anchor(b));

      // The new node drives the flags, so the old node's focus is not carried.
      expect(find.text('focus:false primary:false'), findsOneWidget);
      expect(a.listenerCount, 0);

      b.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('focus:true primary:true'), findsOneWidget);

      a.requestFocus();
      await tester.pumpAndSettle();
      expect(a.hasFocus, isFalse);
    });

    testWidgets('swapping the owned node for a given one disposes the owned '
        'node (#329)', (tester) async {
      final FocusNode external = FocusNode();
      addTearDown(external.dispose);

      await tester.pumpWidget(
        wrapWithTheme(WAnchor(onTap: () {}, child: const _StateReader())),
      );
      final FocusNode owned = tester.widget<Focus>(anchorFocus()).focusNode!;

      await tester.pumpWidget(
        wrapWithTheme(
          WAnchor(
            onTap: () {},
            focusNode: external,
            child: const _StateReader(),
          ),
        ),
      );

      expect(() => owned.addListener(() {}), throwsFlutterError);
      expect(tester.widget<Focus>(anchorFocus()).focusNode, same(external));

      external.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('focus:true primary:true'), findsOneWidget);
    });

    testWidgets('swapping a given node for none creates an owned node and '
        'frees the given one (#329)', (tester) async {
      final _CountingNode external = _CountingNode();
      addTearDown(external.dispose);

      await tester.pumpWidget(
        wrapWithTheme(
          WAnchor(
            onTap: () {},
            focusNode: external,
            child: const _StateReader(),
          ),
        ),
      );
      external.requestFocus();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        wrapWithTheme(WAnchor(onTap: () {}, child: const _StateReader())),
      );

      final FocusNode owned = tester.widget<Focus>(anchorFocus()).focusNode!;
      expect(owned, isNot(same(external)));
      expect(external.listenerCount, 0);
      expect(() => external.addListener(() {}), returnsNormally);

      owned.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('focus:true primary:true'), findsOneWidget);
    });
  });

  group('WAnchor Focus gate', () {
    testWidgets('a gestureless anchor with a node builds a Focus even without '
        'trackFocus (#329)', (tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        wrapWithTheme(
          WAnchor(
            focusNode: node,
            trackFocus: false,
            child: const _StateReader(),
          ),
        ),
      );

      expect(anchorFocus(), findsOneWidget);
      expect(tester.widget<Focus>(anchorFocus()).canRequestFocus, isTrue);
    });

    testWidgets('a gestureless anchor with only autofocus builds a Focus '
        '(#329)', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WAnchor(
            autofocus: true,
            trackFocus: false,
            child: const _StateReader(),
          ),
        ),
      );

      expect(anchorFocus(), findsOneWidget);
      expect(tester.widget<Focus>(anchorFocus()).autofocus, isTrue);
    });

    testWidgets('a gestureless anchor with neither builds no Focus (#329)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(WAnchor(trackFocus: false, child: const _StateReader())),
      );

      expect(anchorFocus(), findsNothing);
    });
  });
}
