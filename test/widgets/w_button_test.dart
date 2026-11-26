import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
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

void main() {
  group('WButton Widget Tests', () {
    group('Basic Rendering', () {
      testWidgets('renders child content', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(WButton(onTap: () {}, child: const Text('Click Me'))),
        );

        expect(find.text('Click Me'), findsOneWidget);
      });

      testWidgets('applies className styling', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              className: 'bg-blue-500 p-4 rounded-lg',
              child: const Text('Styled'),
            ),
          ),
        );

        expect(find.byType(Container), findsOneWidget);
      });
    });

    group('Semantics', () {
      setUp(() {
        WindParser.clearCache();
      });

      testWidgets('icon-only button exposes semanticLabel as its label', (
        tester,
      ) async {
        // An icon-only button has no text child for MergeSemantics to absorb,
        // so without an explicit label it would be a nameless button. The
        // semanticLabel must surface as the button's accessible name.
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              semanticLabel: 'Add item',
              child: const Icon(Icons.add),
            ),
          ),
        );

        final SemanticsNode node = tester.getSemantics(find.byType(WButton));
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.label, 'Add item');
      });

      testWidgets(
        'icon-only button with semanticLabel still fires onTap (Builder path)',
        (tester) async {
          // WButton routes through WAnchor via a Builder indirection. The
          // excludeSemantics: true branch drops the descendant GestureDetector
          // tap action, so onTap must be lifted onto the Semantics node for
          // activation to survive across the Builder boundary.
          var tapped = false;
          await tester.pumpWidget(
            wrapWithTheme(
              WButton(
                onTap: () => tapped = true,
                semanticLabel: 'Add item',
                child: const Icon(Icons.add),
              ),
            ),
          );

          final SemanticsNode node = tester.getSemantics(find.byType(WButton));
          expect(node.label, 'Add item');
          expect(
            node.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );

          await tester.tap(find.byType(WButton));
          await tester.pump();
          expect(tapped, isTrue);
        },
      );

      // A disabled or loading button dropped its callbacks before reaching
      // WAnchor, which then took it for a styling wrapper and published no
      // button node at all: screen readers and tapir lost the control.
      testWidgets('disabled button is a disabled button node with its label', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          var tapped = false;
          await tester.pumpWidget(
            wrapWithTheme(
              WButton(
                onTap: () => tapped = true,
                disabled: true,
                child: const Text('Save'),
              ),
            ),
          );

          final SemanticsNode node = tester.getSemantics(find.byType(WButton));
          expect(
            node,
            isSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
              label: 'Save',
              hasTapAction: false,
            ),
          );

          await tester.tap(find.text('Save'), warnIfMissed: false);
          await tester.pump();
          expect(tapped, isFalse);
        } finally {
          handle.dispose();
        }
      });

      testWidgets('loading button is a disabled button node with its label', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          var tapped = false;
          await tester.pumpWidget(
            wrapWithTheme(
              WButton(
                onTap: () => tapped = true,
                isLoading: true,
                loadingText: 'Saving',
                child: const Text('Save'),
              ),
            ),
          );

          final SemanticsNode node = tester.getSemantics(find.byType(WButton));
          expect(
            node,
            isSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
              label: 'Saving',
              hasTapAction: false,
            ),
          );

          await tester.tap(find.text('Saving'), warnIfMissed: false);
          await tester.pump();
          expect(tapped, isFalse);
        } finally {
          handle.dispose();
        }
      });

      testWidgets(
        'semanticLabel keeps the child unmounted while loading (#321)',
        (tester) async {
          await tester.pumpWidget(
            wrapWithTheme(
              WButton(
                onTap: () {},
                isLoading: true,
                semanticLabel: 'Save now',
                child: const Text('Save'),
              ),
            ),
          );

          expect(find.text('Save'), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        },
      );

      testWidgets('loading button with semanticLabel lifts no tap action', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            wrapWithTheme(
              WButton(
                onTap: () {},
                onLongPress: () {},
                isLoading: true,
                semanticLabel: 'Add item',
                child: const Icon(Icons.add),
              ),
            ),
          );

          expect(
            tester.getSemantics(find.byType(WButton)),
            isSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
              label: 'Add item',
              hasTapAction: false,
              hasLongPressAction: false,
            ),
          );
        } finally {
          handle.dispose();
        }
      });

      // The spinner used to replace the child, so a loading button with no
      // `semanticLabel` and no `loadingText` was a nameless button node.
      testWidgets('loading button keeps its child text as its label (#321)', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            wrapWithTheme(
              WButton(
                onTap: () {},
                isLoading: true,
                child: const WText('Save'),
              ),
            ),
          );

          expect(
            tester.getSemantics(find.byType(WButton)),
            isSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
              label: 'Save',
              hasTapAction: false,
            ),
          );
        } finally {
          handle.dispose();
        }
      });

      // An empty caption renders no readable text, so it cannot name the
      // button and the child has to.
      for (final String caption in <String>['', '  ']) {
        testWidgets(
          'a blank loadingText "$caption" leaves the child to name the '
          'button (#321)',
          (tester) async {
            final SemanticsHandle handle = tester.ensureSemantics();
            try {
              await tester.pumpWidget(
                wrapWithTheme(
                  WButton(
                    onTap: () {},
                    isLoading: true,
                    loadingText: caption,
                    child: const WText('Save'),
                  ),
                ),
              );

              expect(
                tester.getSemantics(find.byType(WButton)),
                isSemantics(isButton: true, label: 'Save'),
              );
            } finally {
              handle.dispose();
            }
          },
        );
      }

      testWidgets(
        'loading button without a callback keeps its child label (#321)',
        (tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              wrapWithTheme(
                const WButton(
                  onTap: null,
                  isLoading: true,
                  child: WText('Save'),
                ),
              ),
            );

            expect(
              tester.getSemantics(find.byType(WButton)),
              isSemantics(
                isButton: true,
                hasEnabledState: true,
                isEnabled: false,
                label: 'Save',
                hasTapAction: false,
              ),
            );
          } finally {
            handle.dispose();
          }
        },
      );

      testWidgets(
        'rendered loadingText names a callbackless loading button (#321)',
        (tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              wrapWithTheme(
                const WButton(
                  onTap: null,
                  isLoading: true,
                  loadingText: 'Saving',
                  child: WText('Save'),
                ),
              ),
            );

            expect(
              tester.getSemantics(find.byType(WButton)),
              isSemantics(
                isButton: true,
                hasEnabledState: true,
                isEnabled: false,
                label: 'Saving',
                hasTapAction: false,
              ),
            );
            expect(find.text('Save'), findsNothing);
          } finally {
            handle.dispose();
          }
        },
      );

      testWidgets(
        'semanticLabel alone names a loading button with a text child (#321)',
        (tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              wrapWithTheme(
                WButton(
                  onTap: () {},
                  isLoading: true,
                  semanticLabel: 'Add item',
                  child: const WText('Save'),
                ),
              ),
            );

            expect(
              tester.getSemantics(find.byType(WButton)),
              isSemantics(
                isButton: true,
                hasEnabledState: true,
                isEnabled: false,
                label: 'Add item',
                hasTapAction: false,
              ),
            );
            expect(find.text('Save'), findsNothing);
          } finally {
            handle.dispose();
          }
        },
      );

      testWidgets(
        'loadingWidget without loadingText keeps the child label (#321)',
        (tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              wrapWithTheme(
                WButton(
                  onTap: () {},
                  isLoading: true,
                  loadingWidget: const Icon(Icons.hourglass_empty),
                  child: const WText('Save'),
                ),
              ),
            );

            expect(
              tester.getSemantics(find.byType(WButton)),
              isSemantics(
                isButton: true,
                hasEnabledState: true,
                isEnabled: false,
                label: 'Save',
                hasTapAction: false,
              ),
            );
          } finally {
            handle.dispose();
          }
        },
      );

      testWidgets(
        'loadingWidget beats loadingText so the child label stays (#321)',
        (tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          try {
            // `loadingText` is never rendered beside a `loadingWidget`, so it
            // cannot name the button.
            await tester.pumpWidget(
              wrapWithTheme(
                WButton(
                  onTap: () {},
                  isLoading: true,
                  loadingText: 'Saving',
                  loadingWidget: const Icon(Icons.hourglass_empty),
                  child: const WText('Save'),
                ),
              ),
            );

            expect(
              tester.getSemantics(find.byType(WButton)),
              isSemantics(
                isButton: true,
                hasEnabledState: true,
                isEnabled: false,
                label: 'Save',
                hasTapAction: false,
              ),
            );
            expect(find.text('Saving'), findsNothing);
          } finally {
            handle.dispose();
          }
        },
      );

      testWidgets('a button that is not loading is named by its child (#321)', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            wrapWithTheme(WButton(onTap: () {}, child: const WText('Save'))),
          );

          expect(tester.getSemantics(find.byType(WButton)).label, 'Save');
          expect(
            find.descendant(
              of: find.byType(WButton),
              matching: find.byType(Opacity),
            ),
            findsNothing,
          );
        } finally {
          handle.dispose();
        }
      });

      testWidgets('loading button ignores the activation key', (tester) async {
        var tapped = false;
        final FocusNode before = FocusNode(debugLabel: 'before');
        addTearDown(before.dispose);

        await tester.pumpWidget(
          wrapWithTheme(
            Column(
              children: [
                Focus(focusNode: before, child: const SizedBox(height: 10)),
                WButton(
                  onTap: () => tapped = true,
                  isLoading: true,
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        );

        before.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(tapped, isFalse);
      });

      // The dominant call site is `disabled: !canSubmit, onTap: canSubmit ?
      // submit : null`, so an inert button usually has no callback at all, and
      // a gestureless WAnchor publishes nothing: the label read as plain text.
      testWidgets('button without a callback is one disabled button node', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            wrapWithTheme(const WButton(onTap: null, child: WText('Save'))),
          );

          final List<SemanticsNode> buttons = _buttonNodes(tester);
          expect(buttons, hasLength(1));
          expect(
            buttons.single,
            isSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
              label: 'Save',
              hasTapAction: false,
            ),
          );
        } finally {
          handle.dispose();
        }
      });

      testWidgets('disabled button without a callback is one disabled node', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            wrapWithTheme(
              const WButton(disabled: true, onTap: null, child: WText('Save')),
            ),
          );

          final List<SemanticsNode> buttons = _buttonNodes(tester);
          expect(buttons, hasLength(1));
          expect(
            buttons.single,
            isSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
              label: 'Save',
              hasTapAction: false,
            ),
          );
        } finally {
          handle.dispose();
        }
      });

      testWidgets('labelled button without a callback is not enabled', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            wrapWithTheme(
              const WButton(
                onTap: null,
                semanticLabel: 'Add item',
                child: Icon(Icons.add),
              ),
            ),
          );

          final List<SemanticsNode> buttons = _buttonNodes(tester);
          expect(buttons, hasLength(1));
          expect(
            buttons.single,
            isSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
              label: 'Add item',
              hasTapAction: false,
            ),
          );
        } finally {
          handle.dispose();
        }
      });

      testWidgets('enabled button is still exactly one button node', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            wrapWithTheme(WButton(onTap: () {}, child: const WText('Save'))),
          );

          final List<SemanticsNode> buttons = _buttonNodes(tester);
          expect(buttons, hasLength(1));
          expect(
            buttons.single,
            isSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              label: 'Save',
              hasTapAction: true,
            ),
          );
        } finally {
          handle.dispose();
        }
      });
    });

    group('Tap Interaction', () {
      testWidgets('calls onTap when pressed', (tester) async {
        bool wasTapped = false;

        await tester.pumpWidget(
          wrapWithTheme(
            WButton(onTap: () => wasTapped = true, child: const Text('Tap Me')),
          ),
        );

        await tester.tap(find.text('Tap Me'));
        await tester.pump();

        expect(wasTapped, isTrue);
      });

      testWidgets('calls onLongPress when long pressed', (tester) async {
        bool wasLongPressed = false;

        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onLongPress: () => wasLongPressed = true,
              child: const Text('Long Press'),
            ),
          ),
        );

        await tester.longPress(find.text('Long Press'));
        await tester.pump();

        expect(wasLongPressed, isTrue);
      });
    });

    group('Disabled State', () {
      testWidgets('does not call onTap when disabled', (tester) async {
        bool wasTapped = false;

        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () => wasTapped = true,
              disabled: true,
              child: const Text('Disabled'),
            ),
          ),
        );

        await tester.tap(find.text('Disabled'));
        await tester.pump();

        expect(wasTapped, isFalse);
      });

      testWidgets('applies disabled className styling', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              disabled: true,
              className: 'bg-blue-500 disabled:bg-gray-400',
              child: const Text('Disabled'),
            ),
          ),
        );

        // Widget should render
        expect(find.text('Disabled'), findsOneWidget);
      });

      // The box was built without the parsed opacity, so `disabled:opacity-50`
      // parsed and painted nothing: a disabled button looked enabled.
      testWidgets('disabled: opacity fades the button', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              disabled: true,
              className: 'bg-blue-500 disabled:opacity-50',
              child: const Text('Disabled'),
            ),
          ),
        );

        final Opacity opacity = tester.widget<Opacity>(
          find.ancestor(
            of: find.text('Disabled'),
            matching: find.byType(Opacity),
          ),
        );
        expect(opacity.opacity, 0.5);
      });

      testWidgets('an enabled button ignores its disabled: opacity', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              className: 'bg-blue-500 disabled:opacity-50',
              child: const Text('Enabled'),
            ),
          ),
        );

        expect(
          find.ancestor(
            of: find.text('Enabled'),
            matching: find.byType(Opacity),
          ),
          findsNothing,
        );
      });

      testWidgets('a transition animates the opacity', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              disabled: true,
              className: 'bg-blue-500 duration-200 disabled:opacity-50',
              child: const Text('Disabled'),
            ),
          ),
        );

        final AnimatedOpacity opacity = tester.widget<AnimatedOpacity>(
          find.ancestor(
            of: find.text('Disabled'),
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(opacity.opacity, 0.5);
      });
    });

    group('Loading State', () {
      setUp(WindParser.clearCache);

      // The unpainted child is kept for its name only; a focusable descendant
      // in it would be an invisible keyboard stop.
      testWidgets('keeps the unpainted child out of keyboard focus (#321)', (
        tester,
      ) async {
        final FocusNode inner = FocusNode();
        addTearDown(inner.dispose);

        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              isLoading: true,
              child: Focus(focusNode: inner, child: const Text('Save')),
            ),
          ),
        );

        inner.requestFocus();
        await tester.pump();

        expect(inner.hasFocus, isFalse);
        expect(find.text('Save'), findsOneWidget);
      });

      testWidgets('shows loading spinner when isLoading is true (#321)', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(onTap: () {}, isLoading: true, child: const Text('Submit')),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // The child stays mounted for its accessible name but is never painted.
        final Opacity hidden = tester.widget<Opacity>(
          find.ancestor(
            of: find.text('Submit'),
            matching: find.byType(Opacity),
          ),
        );
        expect(hidden.opacity, 0);
        expect(hidden.alwaysIncludeSemantics, isTrue);
      });

      testWidgets(
        'keeps the spinner centred and the loading size unchanged (#321)',
        (tester) async {
          await tester.pumpWidget(
            wrapWithTheme(
              Center(
                child: WButton(
                  onTap: () {},
                  isLoading: true,
                  className: 'p-2',
                  child: const WText(
                    'A long label that would widen the button',
                  ),
                ),
              ),
            ),
          );

          // Spinner box plus the padding on each side, never the child's width.
          final Size spinner = tester.getSize(
            find.byType(CircularProgressIndicator),
          );
          expect(
            tester.getSize(find.byType(WButton)),
            spinner + const Offset(16, 16),
          );
        },
      );

      testWidgets(
        'centres the spinner in a full-width fixed-height button (#321)',
        (tester) async {
          await tester.pumpWidget(
            wrapWithTheme(
              WButton(
                onTap: () {},
                isLoading: true,
                className: 'w-full h-12',
                child: const WText('Save'),
              ),
            ),
          );

          expect(
            tester.getCenter(find.byType(CircularProgressIndicator)),
            tester.getCenter(find.byType(WButton)),
          );
        },
      );

      testWidgets('unmounts the child when loadingText is rendered (#321)', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              isLoading: true,
              loadingText: 'Saving',
              child: const Text('Save'),
            ),
          ),
        );

        expect(find.text('Save'), findsNothing);
        expect(find.text('Saving'), findsOneWidget);
      });

      testWidgets('shows loadingText alongside spinner', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              isLoading: true,
              loadingText: 'Loading...',
              child: const Text('Submit'),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Loading...'), findsOneWidget);
      });

      testWidgets('shows custom loadingWidget when provided', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              isLoading: true,
              loadingWidget: const Icon(Icons.hourglass_empty),
              child: const Text('Submit'),
            ),
          ),
        );

        expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('does not call onTap when loading', (tester) async {
        bool wasTapped = false;

        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () => wasTapped = true,
              isLoading: true,
              child: const Text('Loading'),
            ),
          ),
        );

        // Try to tap the button container area (not the spinner directly)
        await tester.tap(find.byType(Container).first, warnIfMissed: false);
        await tester.pump();

        expect(wasTapped, isFalse);
      });

      testWidgets('applies loading className styling', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              isLoading: true,
              className: 'bg-blue-500 loading:opacity-50',
              child: const Text('Submit'),
            ),
          ),
        );

        // Widget should render
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Interaction Blocking', () {
      testWidgets('disabled button blocks interactions', (tester) async {
        bool wasTapped = false;

        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () => wasTapped = true,
              disabled: true,
              child: const Text('Disabled'),
            ),
          ),
        );

        await tester.tap(find.text('Disabled'));
        await tester.pump();

        // onTap should not be called
        expect(wasTapped, isFalse);
      });

      testWidgets('loading button blocks interactions', (tester) async {
        bool wasTapped = false;

        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () => wasTapped = true,
              isLoading: true,
              loadingText: 'Loading...',
              child: const Text('Submit'),
            ),
          ),
        );

        await tester.tap(find.text('Loading...'));
        await tester.pump();

        // onTap should not be called
        expect(wasTapped, isFalse);
      });
    });

    group('Hover State', () {
      testWidgets('hover state is applied on mouse enter', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              className: 'bg-blue-500 hover:bg-red-500',
              child: const Text('Hover Me'),
            ),
          ),
        );

        // Find the MouseRegion (internal to WAnchor)
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);

        // Move mouse over the button
        await gesture.moveTo(tester.getCenter(find.text('Hover Me')));
        await tester.pump();

        // Button should still render (hover styling applied)
        expect(find.text('Hover Me'), findsOneWidget);
      });

      testWidgets('hover state triggers rebuild with different style', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              className: 'bg-blue-500 hover:bg-red-500 p-4 rounded-lg',
              child: const Text('Hover Me'),
            ),
          ),
        );

        // Get initial container
        final containerBefore = tester.widget<Container>(
          find.byType(Container).first,
        );
        final decorationBefore = containerBefore.decoration as BoxDecoration?;
        final colorBefore = decorationBefore?.color;

        // Simulate hover
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(find.text('Hover Me')));
        await tester.pump(); // First pump processes hover event
        await tester.pump(); // Second pump processes postFrameCallback setState

        // Get container after hover
        final containerAfter = tester.widget<Container>(
          find.byType(Container).first,
        );
        final decorationAfter = containerAfter.decoration as BoxDecoration?;
        final colorAfter = decorationAfter?.color;

        // Colors should be different (blue -> red)
        expect(colorBefore, isNotNull);
        expect(colorAfter, isNotNull);
        expect(colorBefore, isNot(equals(colorAfter)));
      });
    });

    group('Custom States', () {
      testWidgets('custom states are applied via states parameter', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              className: 'bg-blue-500 error:bg-red-500 p-4',
              states: {'error'},
              child: const Text('Error Button'),
            ),
          ),
        );

        // Get container
        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        final decoration = container.decoration as BoxDecoration?;

        // Color should be red (error state active)
        expect(decoration?.color, isNotNull);
        expect(find.text('Error Button'), findsOneWidget);
      });

      testWidgets('multiple custom states can be active', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              className: 'bg-blue-500 error:bg-red-500 success:text-green-500',
              states: {'error', 'success'},
              child: const Text('Mixed States'),
            ),
          ),
        );

        expect(find.text('Mixed States'), findsOneWidget);
      });
    });

    group('Cursor Delegation', () {
      testWidgets('uses click cursor when interactive', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(onTap: () {}, child: const Text('Interactive')),
          ),
        );

        final mouseRegion = tester.widget<MouseRegion>(
          find
              .descendant(
                of: find.byType(WButton),
                matching: find.byType(MouseRegion),
              )
              .first,
        );
        expect(mouseRegion.cursor, equals(SystemMouseCursors.click));
      });

      testWidgets('uses forbidden cursor when disabled', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              disabled: true,
              child: const Text('Disabled'),
            ),
          ),
        );

        final mouseRegion = tester.widget<MouseRegion>(
          find
              .descendant(
                of: find.byType(WButton),
                matching: find.byType(MouseRegion),
              )
              .first,
        );
        expect(mouseRegion.cursor, equals(SystemMouseCursors.forbidden));
      });

      testWidgets('uses forbidden cursor when loading', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              isLoading: true,
              child: const Text('Loading'),
            ),
          ),
        );

        final mouseRegion = tester.widget<MouseRegion>(
          find
              .descendant(
                of: find.byType(WButton),
                matching: find.byType(MouseRegion),
              )
              .first,
        );
        expect(mouseRegion.cursor, equals(SystemMouseCursors.forbidden));
      });
    });

    group('onDoubleTap Callback', () {
      testWidgets('calls onDoubleTap when double tapped', (tester) async {
        bool wasDoubleTapped = false;

        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onDoubleTap: () => wasDoubleTapped = true,
              child: const Text('Double Tap'),
            ),
          ),
        );

        await tester.tap(find.text('Double Tap'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('Double Tap'));
        await tester.pumpAndSettle();

        expect(wasDoubleTapped, isTrue);
      });

      testWidgets('does not call onDoubleTap when disabled', (tester) async {
        bool wasDoubleTapped = false;

        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onDoubleTap: () => wasDoubleTapped = true,
              disabled: true,
              child: const Text('Disabled'),
            ),
          ),
        );

        await tester.tap(find.text('Disabled'), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('Disabled'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(wasDoubleTapped, isFalse);
      });

      testWidgets('does not call onDoubleTap when loading', (tester) async {
        bool wasDoubleTapped = false;

        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onDoubleTap: () => wasDoubleTapped = true,
              isLoading: true,
              loadingText: 'Loading...',
              child: const Text('Submit'),
            ),
          ),
        );

        await tester.tap(find.text('Loading...'), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('Loading...'), warnIfMissed: false);
        // Use pump with fixed duration instead of pumpAndSettle
        // because CircularProgressIndicator animation never settles
        await tester.pump(const Duration(milliseconds: 500));

        expect(wasDoubleTapped, isFalse);
      });
    });

    group('Loading Spinner Color', () {
      testWidgets(
        'uses contrasting color on light background when no text color set',
        (tester) async {
          // BUG: White bg + no text color => spinner defaults to
          // Colors.white => invisible on white background.
          await tester.pumpWidget(
            wrapWithTheme(
              WButton(
                onTap: () {},
                isLoading: true,
                className: 'bg-white p-3 rounded-xl',
                child: const Text('Social Login'),
              ),
            ),
          );

          final indicator = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          );

          final animation =
              indicator.valueColor as AlwaysStoppedAnimation<Color>;
          final spinnerColor = animation.value;

          // Spinner should NOT be white on a white background.
          expect(
            spinnerColor,
            isNot(equals(Colors.white)),
            reason: 'Loading spinner should use a contrasting color, not white on white bg',
          );
        },
      );

      testWidgets(
        'uses contrasting color on dark background when no text color set',
        (tester) async {
          await tester.pumpWidget(
            wrapWithTheme(
              WButton(
                onTap: () {},
                isLoading: true,
                className: 'bg-gray-900 p-3 rounded-xl',
                child: const Text('Dark Button'),
              ),
            ),
          );

          final indicator = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          );

          final animation =
              indicator.valueColor as AlwaysStoppedAnimation<Color>;
          final spinnerColor = animation.value;

          // On dark background, spinner should be light (white is fine).
          expect(
            spinnerColor,
            equals(Colors.white),
            reason: 'Loading spinner should be white on dark background',
          );
        },
      );

      testWidgets('uses explicit text color from className for spinner', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              isLoading: true,
              className: 'bg-white text-blue-600 p-3 rounded-xl',
              child: const Text('Styled Button'),
            ),
          ),
        );

        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );

        final animation = indicator.valueColor as AlwaysStoppedAnimation<Color>;
        final spinnerColor = animation.value;

        // When text color is set, spinner should use it.
        expect(
          spinnerColor,
          isNot(equals(Colors.white)),
          reason: 'Loading spinner should use the explicit text color from className',
        );
      });

      testWidgets(
        'falls through to contrast when the text color is transparent',
        (tester) async {
          // `loading:text-transparent` was the pattern this widget's own class
          // doc recommended, and it was inert while `transparent` was missing
          // from the palette. Reading it as a spinner color paints nothing for
          // the whole loading state, which is what the contrast fallback
          // exists to prevent.
          await tester.pumpWidget(
            wrapWithTheme(
              WButton(
                onTap: () {},
                isLoading: true,
                className:
                    'bg-gray-900 p-3 rounded-xl loading:text-transparent',
                child: const Text('Ghost Button'),
              ),
            ),
          );

          final indicator = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          );
          final animation =
              indicator.valueColor as AlwaysStoppedAnimation<Color>;

          expect(animation.value.a, greaterThan(0));
          expect(animation.value, equals(Colors.white));
        },
      );

      testWidgets('an explicit transparent loadingColor is still honoured', (
        tester,
      ) async {
        // The fall-through above reads a text color, never an explicit ask.
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              isLoading: true,
              loadingColor: const Color(0x00000000),
              className: 'bg-gray-900 p-3 rounded-xl',
              child: const Text('Invisible Spinner'),
            ),
          ),
        );

        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        final animation = indicator.valueColor as AlwaysStoppedAnimation<Color>;

        expect(animation.value, equals(const Color(0x00000000)));
      });

      testWidgets('uses explicit loadingColor over all fallbacks', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              isLoading: true,
              loadingColor: Colors.red,
              className: 'bg-white p-3 rounded-xl',
              child: const Text('Custom Color'),
            ),
          ),
        );

        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );

        final animation = indicator.valueColor as AlwaysStoppedAnimation<Color>;
        final spinnerColor = animation.value;

        // Explicit loadingColor should take precedence.
        expect(spinnerColor, equals(Colors.red));
      });
    });

    group('Letter Spacing', () {
      setUp(() {
        WindParser.clearCache();
      });

      testWidgets('resolves em tracking against the label text size', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              className: 'text-sm tracking-wide',
              child: const Text('Save'),
            ),
          ),
        );

        final double? letterSpacing = tester
            .renderObject<RenderParagraph>(find.text('Save'))
            .text
            .style
            ?.letterSpacing;

        expect(letterSpacing, closeTo(0.35, 1e-9));
      });
    });

    // The button's box was built from the parsed decoration alone, so a ring
    // and a shadow in its className parsed and painted nothing: a host app's
    // dialog buttons showed no focus while Tab moved between them.
    group('Ring and shadow', () {
      setUp(WindParser.clearCache);

      testWidgets('a focus: ring outlines the button while it has focus', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithTheme(
            Center(
              child: WButton(
                onTap: () {},
                className:
                    'px-4 py-2 bg-white focus:ring-2 focus:ring-blue-500',
                child: const Text('Save'),
              ),
            ),
          ),
        );

        Border? ring() {
          final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
            find.ancestor(
              of: find.text('Save'),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is DecoratedBox &&
                    w.position == DecorationPosition.foreground,
              ),
            ),
          );

          return boxes.isEmpty
              ? null
              : (boxes.first.decoration as BoxDecoration).border as Border?;
        }

        expect(ring(), isNull);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(ring()?.top.width, 2);
        expect(ring()?.top.strokeAlign, BorderSide.strokeAlignOutside);
      });

      testWidgets('a shadow class casts a shadow', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              className: 'px-4 py-2 bg-white shadow-md',
              child: const Text('Save'),
            ),
          ),
        );

        final Container box = tester.widget<Container>(
          find
              .ancestor(of: find.text('Save'), matching: find.byType(Container))
              .first,
        );

        expect((box.decoration! as BoxDecoration).boxShadow, isNotEmpty);
      });
    });

    group('Focus node', () {
      setUp(WindParser.clearCache);

      const String focusClasses =
          'px-4 py-2 bg-blue-600 focus:bg-blue-700 '
          'dark:bg-blue-500 dark:focus:bg-blue-400';

      Color? paintedColor(WidgetTester tester) {
        final Container box = tester.widget<Container>(
          find
              .ancestor(of: find.text('Save'), matching: find.byType(Container))
              .first,
        );

        return (box.decoration! as BoxDecoration).color;
      }

      testWidgets('an external node requested to focus applies the focus: '
          'class (#329)', (tester) async {
        final FocusNode node = FocusNode();
        addTearDown(node.dispose);

        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              focusNode: node,
              className: focusClasses,
              child: const Text('Save'),
            ),
          ),
        );
        final Color? idle = paintedColor(tester);

        node.requestFocus();
        await tester.pumpAndSettle();

        expect(node.hasPrimaryFocus, isTrue);
        expect(paintedColor(tester), isNot(idle));
        expect(paintedColor(tester), const Color(0xFF1D4ED8));
      });

      testWidgets('autofocus focuses the button on the first frame (#329)', (
        tester,
      ) async {
        final FocusNode node = FocusNode();
        addTearDown(node.dispose);

        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: () {},
              focusNode: node,
              autofocus: true,
              className: focusClasses,
              child: const Text('Save'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(node.hasPrimaryFocus, isTrue);
        expect(paintedColor(tester), const Color(0xFF1D4ED8));
      });

      testWidgets('a button loading at mount does not autofocus when loading '
          'ends (#329)', (tester) async {
        final FocusNode node = FocusNode();
        addTearDown(node.dispose);

        Widget button({required bool isLoading}) => wrapWithTheme(
          WButton(
            onTap: () {},
            focusNode: node,
            autofocus: true,
            isLoading: isLoading,
            child: const Text('Save'),
          ),
        );

        // The spinner repeats, so pump a fixed time rather than settle.
        await tester.pumpWidget(button(isLoading: true));
        await tester.pump(const Duration(milliseconds: 100));
        expect(node.hasFocus, isFalse);

        await tester.pumpWidget(button(isLoading: false));
        await tester.pumpAndSettle();

        expect(node.hasFocus, isFalse);
      });

      testWidgets('unmounting the button leaves the external node undisposed '
          '(#329)', (tester) async {
        final FocusNode node = FocusNode();
        addTearDown(node.dispose);

        await tester.pumpWidget(
          wrapWithTheme(
            WButton(onTap: () {}, focusNode: node, child: const Text('Save')),
          ),
        );

        await tester.pumpWidget(wrapWithTheme(const SizedBox()));

        expect(() => node.addListener(() {}), returnsNormally);
        expect(node.requestFocus, returnsNormally);
      });

      testWidgets('swapping the node moves focus styling to the new node '
          '(#329)', (tester) async {
        final FocusNode a = FocusNode();
        final FocusNode b = FocusNode();
        addTearDown(a.dispose);
        addTearDown(b.dispose);

        Widget button(FocusNode node) => wrapWithTheme(
          WButton(
            onTap: () {},
            focusNode: node,
            className: focusClasses,
            child: const Text('Save'),
          ),
        );

        await tester.pumpWidget(button(a));
        final Color? idle = paintedColor(tester);
        a.requestFocus();
        await tester.pumpAndSettle();
        expect(paintedColor(tester), isNot(idle));

        await tester.pumpWidget(button(b));
        expect(paintedColor(tester), idle);

        b.requestFocus();
        await tester.pumpAndSettle();
        expect(paintedColor(tester), isNot(idle));

        a.requestFocus();
        await tester.pumpAndSettle();
        expect(a.hasFocus, isFalse);
      });

      testWidgets('a button with no callback and a node is focusable (#329)', (
        tester,
      ) async {
        final FocusNode node = FocusNode();
        addTearDown(node.dispose);

        await tester.pumpWidget(
          wrapWithTheme(
            WButton(
              onTap: null,
              focusNode: node,
              className: focusClasses,
              child: const Text('Save'),
            ),
          ),
        );
        final Color? idle = paintedColor(tester);

        node.requestFocus();
        await tester.pumpAndSettle();

        expect(node.hasPrimaryFocus, isTrue);
        expect(paintedColor(tester), isNot(idle));
      });
    });
  });
}

/// Every button node the platform would actually receive.
///
/// The same walk as `w_anchor_test.dart`: a node with `isMergedIntoParent` is
/// folded into its parent and never reaches assistive technology, so it is not
/// counted.
List<SemanticsNode> _buttonNodes(WidgetTester tester) {
  final List<SemanticsNode> found = <SemanticsNode>[];

  void walk(SemanticsNode node) {
    if (!node.isMergedIntoParent &&
        node.getSemanticsData().flagsCollection.isButton) {
      found.add(node);
    }
    node.visitChildren((SemanticsNode child) {
      walk(child);
      return true;
    });
  }

  walk(tester.getSemantics(find.byType(MaterialApp)));

  return found;
}
