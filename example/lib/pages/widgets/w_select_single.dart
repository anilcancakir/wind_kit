import 'package:material_ui/material_ui.dart';
import 'package:wind_kit/wind_kit.dart';

import '../../widgets/example_scaffold.dart';

class WSelectSingleExamplePage extends StatefulWidget {
  const WSelectSingleExamplePage({super.key});

  @override
  State<WSelectSingleExamplePage> createState() =>
      _WSelectSingleExamplePageState();
}

class _WSelectSingleExamplePageState extends State<WSelectSingleExamplePage> {
  String? _fruit;
  String? _country;
  String? _theme;
  String? _size;

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Single-Select',
      description: 'Default mode of WSelect. Pick one value from a list. Pair searchable: true with longer lists for filtering. Tab to a select and use the arrow keys, Enter and Escape.',
      gradient: 'from-indigo-500 to-blue-600',
      children: [
        ExampleSection(
          title: 'Basic Usage',
          description: 'Three options. The trigger displays the selected label or placeholder.',
          child: WSelect<String>(
            value: _fruit,
            options: const [
              SelectOption(value: 'apple', label: 'Apple'),
              SelectOption(value: 'banana', label: 'Banana'),
              SelectOption(value: 'cherry', label: 'Cherry'),
            ],
            onChange: (v) => setState(() => _fruit = v),
            placeholder: 'Pick a fruit',
            className: '''
              w-64 px-3 py-2 rounded-lg
              bg-white dark:bg-slate-800
              border border-slate-300 dark:border-slate-600
              hover:border-indigo-500
            ''',
            menuClassName: '''
              rounded-lg
              bg-white dark:bg-slate-800
              shadow-xl border border-slate-200 dark:border-slate-700
            ''',
          ),
        ),
        ExampleSection(
          title: 'Searchable',
          description: 'searchable: true adds a filter input on top of the list. searchPlaceholder customizes the prompt.',
          child: WSelect<String>(
            value: _country,
            searchable: true,
            searchPlaceholder: 'Search countries…',
            options: const [
              SelectOption(value: 'tr', label: 'Türkiye'),
              SelectOption(value: 'us', label: 'United States'),
              SelectOption(value: 'de', label: 'Germany'),
              SelectOption(value: 'fr', label: 'France'),
              SelectOption(value: 'jp', label: 'Japan'),
              SelectOption(value: 'br', label: 'Brazil'),
              SelectOption(value: 'in', label: 'India'),
              SelectOption(value: 'au', label: 'Australia'),
            ],
            onChange: (v) => setState(() => _country = v),
            placeholder: 'Pick a country',
            className: '''
              w-64 px-3 py-2 rounded-lg
              bg-white dark:bg-slate-800
              border border-slate-300 dark:border-slate-600
              hover:border-indigo-500
            ''',
            menuClassName: '''
              rounded-lg
              bg-white dark:bg-slate-800
              shadow-xl border border-slate-200 dark:border-slate-700
            ''',
          ),
        ),
        ExampleSection(
          title: 'Default Menu Surface',
          description: 'No menuClassName: the menu follows the theme, so toggle dark mode to see it.',
          child: WSelect<String>(
            value: _theme,
            options: const [
              SelectOption(value: 'light', label: 'Light'),
              SelectOption(value: 'dark', label: 'Dark'),
              SelectOption(value: 'system', label: 'System'),
            ],
            onChange: (v) => setState(() => _theme = v),
            placeholder: 'Pick a theme',
          ),
        ),
        ExampleSection(
          title: 'Right Edge',
          description: 'A narrow trigger at the end of the row with a w-64 menu. The menu shifts left to stay inside the window; narrow the window to see it.',
          child: Align(
            alignment: Alignment.centerRight,
            child: WSelect<String>(
              value: _size,
              options: const [
                SelectOption(value: 's', label: 'Small'),
                SelectOption(value: 'm', label: 'Medium'),
                SelectOption(value: 'l', label: 'Large'),
              ],
              onChange: (v) => setState(() => _size = v),
              placeholder: 'Size',
              className: '''
                w-28 px-3 py-2 rounded-lg
                bg-white dark:bg-slate-800
                border border-slate-300 dark:border-slate-600
              ''',
              menuClassName: 'w-64',
            ),
          ),
        ),
      ],
    );
  }
}
