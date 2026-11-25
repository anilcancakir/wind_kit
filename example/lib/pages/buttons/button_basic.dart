import 'package:material_ui/material_ui.dart';
import 'package:wind_kit/wind_kit.dart';

import '../../widgets/example_scaffold.dart';

class ButtonBasicExamplePage extends StatefulWidget {
  const ButtonBasicExamplePage({super.key});

  @override
  State<ButtonBasicExamplePage> createState() => _ButtonBasicExamplePageState();
}

class _ButtonBasicExamplePageState extends State<ButtonBasicExamplePage> {
  int _counter = 0;
  bool _isLoading = false;

  Future<void> _simulateLoading() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'WButton',
      description: 'Interactive button on top of WAnchor. Built-in isLoading + disabled props activate the matching state prefixes. className styles the rest.',
      gradient: 'from-blue-600 to-indigo-700',
      children: [
        ExampleSection(
          title: 'Basic Usage',
          description:
              'onTap + className. Hover and active states fire automatically.',
          child: WButton(
            onTap: () => setState(() => _counter++),
            className: '''
              bg-blue-600 hover:bg-blue-700 active:bg-blue-800
              text-white px-4 py-2 rounded-lg duration-200
              self-start
            ''',
            child: WText(
              'Click Me (tapped $_counter times)',
              className: 'text-white font-medium',
            ),
          ),
        ),
        ExampleSection(
          title: 'Button Variants',
          description: 'Same WButton, different className. Primary, secondary, outline, danger: all utility-driven.',
          child: WDiv(
            className: 'wrap gap-3',
            children: [
              WButton(
                onTap: () {},
                className: 'bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg duration-200',
                child: const WText(
                  'Primary',
                  className: 'text-white font-medium',
                ),
              ),
              WButton(
                onTap: () {},
                className: 'bg-slate-200 hover:bg-slate-300 dark:bg-slate-700 dark:hover:bg-slate-600 px-4 py-2 rounded-lg duration-200',
                child: const WText(
                  'Secondary',
                  className: 'text-slate-700 dark:text-slate-200 font-medium',
                ),
              ),
              WButton(
                onTap: () {},
                className: 'border-2 border-blue-600 hover:bg-blue-50 dark:hover:bg-blue-900/30 px-4 py-2 rounded-lg duration-200',
                child: const WText(
                  'Outline',
                  className: 'text-blue-600 dark:text-blue-400 font-medium',
                ),
              ),
              WButton(
                onTap: () {},
                className: 'bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-lg duration-200',
                child: const WText(
                  'Danger',
                  className: 'text-white font-medium',
                ),
              ),
            ],
          ),
        ),
        ExampleSection(
          title: 'Loading State',
          description: 'isLoading paints a spinner instead of the child and activates loading: prefixed classes. loadingText prints a label next to the spinner; without it the child stays mounted, unpainted, and names the button.',
          child: WDiv(
            className: 'wrap gap-3 items-center',
            children: [
              WButton(
                onTap: _simulateLoading,
                isLoading: _isLoading,
                loadingText: 'Submitting…',
                className: '''
                  bg-blue-600 loading:opacity-70
                  text-white px-6 py-2 rounded-lg
                ''',
                child: const WText(
                  'Click to Load',
                  className: 'text-white font-medium',
                ),
              ),
              WButton(
                onTap: () {},
                isLoading: true,
                className: 'bg-emerald-600 text-white px-6 py-2 rounded-lg',
                child: const WText(
                  'Always Loading',
                  className: 'text-white font-medium',
                ),
              ),
            ],
          ),
        ),
        ExampleSection(
          title: 'Disabled State',
          description:
              'disabled blocks gestures AND activates the disabled: prefix.',
          child: WDiv(
            className: 'wrap gap-3',
            children: [
              WButton(
                onTap: () {},
                className: 'bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg',
                child: const WText(
                  'Enabled',
                  className: 'text-white font-medium',
                ),
              ),
              WButton(
                onTap: () {},
                disabled: true,
                className: '''
                  bg-blue-600 disabled:bg-slate-300
                  dark:disabled:bg-slate-700
                  disabled:opacity-60
                  text-white px-4 py-2 rounded-lg
                ''',
                child: const WText(
                  'Disabled',
                  className: 'text-white font-medium',
                ),
              ),
            ],
          ),
        ),
        const ExampleSection(
          title: 'Focus Control',
          description: 'focusNode and autofocus reach the WAnchor underneath. The caller owns the node; focus: classes follow it.',
          child: _FocusDemo(),
        ),
        ExampleSection(
          title: 'Icon Button',
          description:
              'Pair WButton with WIcon for circular/square icon buttons.',
          child: WDiv(
            className: 'wrap gap-3',
            children: [
              WButton(
                onTap: () {},
                className:
                    'bg-red-500 hover:bg-red-600 p-3 rounded-full duration-200',
                child: WIcon(
                  Icons.delete_outline,
                  className: 'text-white w-5 h-5',
                ),
              ),
              WButton(
                onTap: () {},
                className: 'bg-blue-500 hover:bg-blue-600 p-3 rounded-full duration-200',
                child: WIcon(Icons.add, className: 'text-white w-5 h-5'),
              ),
              WButton(
                onTap: () {},
                className: 'bg-emerald-500 hover:bg-emerald-600 p-3 rounded-full duration-200',
                child: WIcon(Icons.check, className: 'text-white w-5 h-5'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Owns the [FocusNode] a [WButton] is given, so the page can move focus to it.
class _FocusDemo extends StatefulWidget {
  const _FocusDemo();

  @override
  State<_FocusDemo> createState() => _FocusDemoState();
}

class _FocusDemoState extends State<_FocusDemo> {
  final FocusNode _saveFocus = FocusNode();

  @override
  void dispose() {
    _saveFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'wrap gap-3 items-center',
      children: [
        WButton(
          focusNode: _saveFocus,
          onTap: () {},
          className: '''
            bg-blue-600 hover:bg-blue-700
            dark:bg-blue-500 dark:hover:bg-blue-600
            focus:ring-2 focus:ring-blue-300 dark:focus:ring-blue-700
            text-white px-4 py-2 rounded-lg duration-200
          ''',
          child: const WText('Save', className: 'text-white font-medium'),
        ),
        WButton(
          onTap: _saveFocus.requestFocus,
          className: '''
            bg-slate-200 hover:bg-slate-300
            dark:bg-slate-700 dark:hover:bg-slate-600
            px-4 py-2 rounded-lg duration-200
          ''',
          child: const WText(
            'Focus Save',
            className: 'text-slate-700 dark:text-slate-200 font-medium',
          ),
        ),
      ],
    );
  }
}
