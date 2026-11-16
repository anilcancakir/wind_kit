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
  group('WCheckbox States Enhancement', () {
    testWidgets('supports custom states prop', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WCheckbox(
            value: false,
            states: {'error'},
            className: 'w-5 h-5 border error:border-red-500',
          ),
        ),
      );

      expect(find.byType(WCheckbox), findsOneWidget);
    });

    testWidgets('merges custom states with built-in states', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WCheckbox(
            value: true, // adds 'checked' state
            disabled: true, // adds 'disabled' state
            states: {'error', 'loading'}, // custom states
            className: 'w-5 h-5',
          ),
        ),
      );

      expect(find.byType(WCheckbox), findsOneWidget);
    });

    testWidgets('works without custom states (backward compatibility)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WCheckbox(
            value: true,
            className: 'w-5 h-5 border checked:bg-blue-500',
          ),
        ),
      );

      expect(find.byType(WCheckbox), findsOneWidget);
    });
  });

  group('WFormCheckbox Widget Tests', () {
    group('Basic Rendering', () {
      testWidgets('renders checkbox in FormField', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            Form(
              child: WFormCheckbox(
                value: false,
                className: 'w-5 h-5 border rounded',
              ),
            ),
          ),
        );

        expect(find.byType(WCheckbox), findsOneWidget);
      });

      testWidgets('renders with initial value', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(Form(child: WFormCheckbox(value: true))),
        );

        // Checked checkbox should show the check icon
        expect(find.byType(WFormCheckbox), findsOneWidget);
      });

      testWidgets('displays labelText', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            Form(child: WFormCheckbox(labelText: 'I agree to terms')),
          ),
        );

        expect(find.text('I agree to terms'), findsOneWidget);
      });

      testWidgets('displays custom label widget', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            Form(child: WFormCheckbox(label: const Text('Custom Label'))),
          ),
        );

        expect(find.text('Custom Label'), findsOneWidget);
      });

      testWidgets('displays hint', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            Form(child: WFormCheckbox(hint: 'Optional but recommended')),
          ),
        );

        expect(find.text('Optional but recommended'), findsOneWidget);
      });
    });

    group('Form Validation', () {
      testWidgets('validator is called on Form.validate()', (tester) async {
        final formKey = GlobalKey<FormState>();
        bool validatorCalled = false;

        await tester.pumpWidget(
          wrapWithTheme(
            Form(
              key: formKey,
              child: WFormCheckbox(
                value: false,
                labelText: 'Accept terms',
                validator: (value) {
                  validatorCalled = true;
                  return value != true ? 'Required' : null;
                },
              ),
            ),
          ),
        );

        formKey.currentState!.validate();
        await tester.pump();

        expect(validatorCalled, isTrue);
      });

      testWidgets('shows error message when validation fails', (tester) async {
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          wrapWithTheme(
            Form(
              key: formKey,
              child: WFormCheckbox(
                value: false,
                labelText: 'Accept terms',
                validator: (value) =>
                    value != true ? 'You must accept terms' : null,
              ),
            ),
          ),
        );

        formKey.currentState!.validate();
        await tester.pump();

        expect(find.text('You must accept terms'), findsOneWidget);
      });

      testWidgets('hides error when showError is false', (tester) async {
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          wrapWithTheme(
            Form(
              key: formKey,
              child: WFormCheckbox(
                value: false,
                showError: false,
                validator: (value) => value != true ? 'Required' : null,
              ),
            ),
          ),
        );

        formKey.currentState!.validate();
        await tester.pump();

        expect(find.text('Required'), findsNothing);
      });

      testWidgets('validation passes when checked', (tester) async {
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          wrapWithTheme(
            Form(
              key: formKey,
              child: WFormCheckbox(
                value: true,
                validator: (value) => value != true ? 'Required' : null,
              ),
            ),
          ),
        );

        final isValid = formKey.currentState!.validate();
        await tester.pump();

        expect(isValid, isTrue);
      });
    });

    group('Hint and Error Priority', () {
      testWidgets('hint is hidden when error is shown', (tester) async {
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          wrapWithTheme(
            Form(
              key: formKey,
              child: WFormCheckbox(
                value: false,
                hint: 'Please check to continue',
                validator: (value) => value != true ? 'Required' : null,
              ),
            ),
          ),
        );

        // Initially hint is visible
        expect(find.text('Please check to continue'), findsOneWidget);

        // Trigger validation
        formKey.currentState!.validate();
        await tester.pump();

        // Error visible, hint hidden
        expect(find.text('Required'), findsOneWidget);
        expect(find.text('Please check to continue'), findsNothing);
      });
    });

    group('Value Changes', () {
      testWidgets('toggling checkbox updates form state', (tester) async {
        final formKey = GlobalKey<FormState>();
        bool? currentValue = false;

        await tester.pumpWidget(
          wrapWithTheme(
            StatefulBuilder(
              builder: (context, setState) {
                return Form(
                  key: formKey,
                  child: WFormCheckbox(
                    value: currentValue!,
                    onChanged: (value) {
                      setState(() => currentValue = value);
                    },
                    labelText: 'Check me',
                    validator: (value) => value != true ? 'Required' : null,
                  ),
                );
              },
            ),
          ),
        );

        // Initially fails validation
        expect(formKey.currentState!.validate(), isFalse);

        // Tap checkbox
        await tester.tap(find.byType(WCheckbox));
        await tester.pumpAndSettle();

        // Now should pass
        expect(currentValue, isTrue);
        expect(formKey.currentState!.validate(), isTrue);
      });
    });

    group('Form Reset', () {
      testWidgets('Form.reset() restores to initial value', (tester) async {
        final formKey = GlobalKey<FormState>();
        bool currentValue = false;

        await tester.pumpWidget(
          wrapWithTheme(
            StatefulBuilder(
              builder: (context, setState) {
                return Form(
                  key: formKey,
                  child: WFormCheckbox(
                    value: currentValue,
                    onChanged: (value) {
                      setState(() => currentValue = value);
                    },
                  ),
                );
              },
            ),
          ),
        );

        // Toggle checkbox
        await tester.tap(find.byType(WCheckbox));
        await tester.pumpAndSettle();
        expect(currentValue, isTrue);

        // Reset form
        formKey.currentState!.reset();
        await tester.pump();

        // FormField value should be back to initial (false)
        expect(find.byType(WFormCheckbox), findsOneWidget);
      });

      testWidgets('Form.reset() clears error state', (tester) async {
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          wrapWithTheme(
            Form(
              key: formKey,
              child: WFormCheckbox(
                value: false,
                validator: (value) => value != true ? 'Required' : null,
              ),
            ),
          ),
        );

        // Trigger error
        formKey.currentState!.validate();
        await tester.pump();
        expect(find.text('Required'), findsOneWidget);

        // Reset
        formKey.currentState!.reset();
        await tester.pump();

        expect(find.text('Required'), findsNothing);
      });
    });

    group('onSaved Callback', () {
      testWidgets('onSaved is called when form is saved', (tester) async {
        final formKey = GlobalKey<FormState>();
        bool? savedValue;

        await tester.pumpWidget(
          wrapWithTheme(
            Form(
              key: formKey,
              child: WFormCheckbox(
                value: true,
                onSaved: (value) => savedValue = value,
              ),
            ),
          ),
        );

        formKey.currentState!.save();
        expect(savedValue, isTrue);
      });
    });

    group('Disabled State', () {
      testWidgets('disabled checkbox does not respond to taps', (tester) async {
        bool? changed;

        await tester.pumpWidget(
          wrapWithTheme(
            Form(
              child: WFormCheckbox(
                value: false,
                disabled: true,
                onChanged: (value) => changed = value,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(WCheckbox));
        await tester.pump();

        expect(changed, isNull);
      });
    });

    group('Long Label', () {
      const longLabel =
          'I have read and agree to the Terms of Service and the Privacy '
          'Policy of this service.';

      Widget bounded(Widget child) {
        return wrapWithTheme(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 200, child: Form(child: child)),
          ),
        );
      }

      testWidgets('labelText wraps inside a bounded width', (tester) async {
        expect(longLabel.length, greaterThanOrEqualTo(70));

        await tester.pumpWidget(bounded(WFormCheckbox(labelText: longLabel)));

        expect(tester.takeException(), isNull);
        final labelRect = tester.getRect(find.text(longLabel));
        expect(labelRect.right, lessThanOrEqualTo(200));
        expect(labelRect.height, greaterThan(14 * 1.5));
      });

      testWidgets('a caller supplied Flexible label is not wrapped twice', (
        tester,
      ) async {
        await tester.pumpWidget(
          bounded(
            WFormCheckbox(
              label: Flexible(child: WText(longLabel, className: 'text-sm')),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.text(longLabel)).right,
          lessThanOrEqualTo(200),
        );
      });

      testWidgets(
        'a labelClassName with its own flex token is not wrapped twice',
        (tester) async {
          // `flex-1` makes WText wrap itself in Expanded, which was a working way
          // to get a wrapping label before labelText became flexible by default.
          await tester.pumpWidget(
            bounded(
              WFormCheckbox(
                labelText: longLabel,
                labelClassName: 'text-sm flex-1',
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(
            tester.getRect(find.text(longLabel)).right,
            lessThanOrEqualTo(200),
          );
        },
      );

      testWidgets('a labelClassName with shrink-0 keeps the label unshrunk', (
        tester,
      ) async {
        await tester.pumpWidget(
          bounded(
            WFormCheckbox(
              labelText: longLabel,
              labelClassName: 'text-sm shrink-0',
            ),
          ),
        );

        // The caller asked for no shrinking, so the label stays on one line
        // and overflows the 200 px box; the point is that the default
        // `flex-initial` does not override it and nothing asserts on parent
        // data.
        final error = tester.takeException();
        expect(error, isA<FlutterError>());
        expect(error.toString(), contains('overflowed'));
        expect(error.toString(), isNot(contains('ParentDataWidget')));
      });

      testWidgets('labelText lays out under unbounded width', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Form(child: WFormCheckbox(labelText: longLabel)),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text(longLabel), findsOneWidget);
      });

      testWidgets('a short labelText keeps its natural width', (tester) async {
        await tester.pumpWidget(bounded(WFormCheckbox(labelText: 'Short')));

        expect(tester.takeException(), isNull);
        final rowRect = tester.getRect(find.byType(WAnchor).first);
        final labelRect = tester.getRect(find.text('Short'));
        expect(rowRect.right, labelRect.right);
        expect(rowRect.width, lessThan(200));
      });
    });

    group('External Value Updates', () {
      testWidgets('syncs when parent updates value from false to true', (
        tester,
      ) async {
        bool externalValue = false;

        await tester.pumpWidget(
          wrapWithTheme(
            StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    WFormCheckbox(value: externalValue, className: 'w-5 h-5'),
                    WButton(
                      onTap: () => setState(() => externalValue = true),
                      child: const Text('Set True'),
                    ),
                  ],
                );
              },
            ),
          ),
        );

        expect(tester.widget<WCheckbox>(find.byType(WCheckbox)).value, isFalse);

        await tester.tap(find.text('Set True'));
        await tester.pump();

        expect(tester.widget<WCheckbox>(find.byType(WCheckbox)).value, isTrue);
      });

      testWidgets('syncs when parent updates value from true to false', (
        tester,
      ) async {
        bool externalValue = true;

        await tester.pumpWidget(
          wrapWithTheme(
            StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    WFormCheckbox(value: externalValue, className: 'w-5 h-5'),
                    WButton(
                      onTap: () => setState(() => externalValue = false),
                      child: const Text('Set False'),
                    ),
                  ],
                );
              },
            ),
          ),
        );

        expect(tester.widget<WCheckbox>(find.byType(WCheckbox)).value, isTrue);

        await tester.tap(find.text('Set False'));
        await tester.pump();

        expect(tester.widget<WCheckbox>(find.byType(WCheckbox)).value, isFalse);
      });
    });
  });
}
