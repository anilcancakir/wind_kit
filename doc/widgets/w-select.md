# WSelect

A highly customisable, utility-first select component that supports single selection, multi-selection, searching, and remote data fetching.

- [Basic Usage](#basic-usage)
- [Constructor](#constructor)
- [Props](#props)
- [Layout Modes](#layout-modes)
- [Event Handling](#event-handling)
- [Accessibility](#accessibility)
- [Keyboard Navigation](#keyboard-navigation)
- [State Variants](#state-variants)
- [Styling Examples](#styling-examples)
- [All Supported Classes](#all-supported-classes)
- [Customizing Theme](#customizing-theme)
- [Related Documentation](#related-documentation)

<x-preview path="forms/select_basic" size="md" source="example/lib/pages/forms/select_basic.dart"></x-preview>

```dart
WSelect<String>(
  value: _selected,
  options: [
    SelectOption(value: 'dart', label: 'Dart'),
    SelectOption(value: 'flutter', label: 'Flutter'),
  ],
  onChange: (value) => setState(() => _selected = value),
  className: 'w-64 bg-white border border-gray-300 rounded-lg',
)
```

<a name="basic-usage"></a>
## Basic Usage

The `WSelect` widget replaces the standard Material Dropdown with a utility-first approach. It manages its own open state while providing a controlled interface for selection.

```dart
WSelect<int>(
  placeholder: 'Choose a number',
  options: List.generate(5, (i) => SelectOption(value: i, label: 'Option $i')),
  onChange: (val) => print('Selected: $val'),
  className: 'bg-white border p-3 rounded-md',
)
```

<a name="constructor"></a>
## Constructor

```dart
const WSelect({
  Key? key,
  T? value,
  ValueChanged<T>? onChange,
  bool isMulti = false,
  List<T>? values,
  ValueChanged<List<T>>? onMultiChange,
  SelectedChipBuilder<T>? selectedChipBuilder,
  required List<SelectOption<T>> options,
  bool searchable = false,
  Future<List<SelectOption<T>>> Function(String)? onSearch,
  String searchPlaceholder = 'Search...',
  Future<SelectOption<T>> Function(String)? onCreateOption,
  CreateOptionBuilder? createOptionBuilder,
  Future<List<SelectOption<T>>> Function()? onLoadMore,
  bool hasMore = false,
  VoidCallback? onOpen,
  String? className,
  String? menuClassName,
  String placeholder = 'Select an option',
  bool disabled = false,
  double? menuWidth,
  double maxMenuHeight = 300,
  Set<String>? states,
  SelectTriggerBuilder<T>? triggerBuilder,
  MultiSelectTriggerBuilder<T>? multiTriggerBuilder,
  SelectItemBuilder<T>? itemBuilder,
  EmptyStateBuilder? emptyBuilder,
  LoadingBuilder? loadingBuilder,
})
```

<a name="props"></a>
## Props

| Prop | Type | Default | Description |
|:-----|:-----|:--------|:------------|
| `className` | `String?` | `null` | Utility classes for the trigger container; when null the trigger uses `bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg p-3` |
| `menuClassName` | `String?` | `null` | Utility classes for the dropdown menu. A menu with no background class still gets the default surface `bg-white dark:bg-gray-800`; any background class you set, including `bg-transparent`, wins |
| `options` | `List<SelectOption<T>>` | **Required** | List of items to display |
| `value` | `T?` | `null` | Selected value in single-select mode |
| `onChange` | `ValueChanged<T>?` | `null` | Callback for single selection changes |
| `isMulti` | `bool` | `false` | Enables multi-select mode |
| `values` | `List<T>?` | `null` | Selected values in multi-select mode |
| `onMultiChange` | `ValueChanged<List<T>>?` | `null` | Callback for multi-selection changes |
| `searchable` | `bool` | `false` | Shows a search input in the menu |
| `searchPlaceholder` | `String` | `'Search...'` | Placeholder text in the search input |
| `onSearch` | `Future<List<SelectOption<T>>> Function(String)?` | `null` | Async remote search handler; returns filtered options for the query |
| `onCreateOption` | `Future<SelectOption<T>> Function(String)?` | `null` | Tagging handler; called when the user creates a new option from search input |
| `createOptionBuilder` | `CreateOptionBuilder?` | `null` | Custom builder for the "create new option" row in the menu |
| `onLoadMore` | `Future<List<SelectOption<T>>> Function()?` | `null` | Pagination handler; called when the user scrolls past the current list |
| `hasMore` | `bool` | `false` | When true, indicates more pages are available for `onLoadMore` |
| `onOpen` | `VoidCallback?` | `null` | Called when the menu opens, after this widget has reset its own search and visible list. A paginating caller resets its cursor here; see below |
| `placeholder` | `String` | `'Select an option'` | Text shown when no value is selected |
| `disabled` | `bool` | `false` | Prevents interaction |
| `menuWidth` | `double?` | `null` | Fixed dropdown width; defaults to the trigger width |
| `maxMenuHeight`| `double` | `300` | Maximum height of the dropdown list |
| `states` | `Set<String>?` | `null` | Custom states for dynamic styling |
| `triggerBuilder` | `SelectTriggerBuilder<T>?` | `null` | Custom trigger renderer for single-select |
| `multiTriggerBuilder` | `MultiSelectTriggerBuilder<T>?` | `null` | Custom trigger renderer for multi-select |
| `selectedChipBuilder` | `SelectedChipBuilder<T>?` | `null` | Custom chip renderer for selected items in multi-select |
| `itemBuilder` | `SelectItemBuilder<T>?` | `null` | Custom renderer for each option in the menu |
| `emptyBuilder` | `EmptyStateBuilder?` | `null` | Custom widget when no options match the search |
| `loadingBuilder` | `LoadingBuilder?` | `null` | Custom widget shown while `onSearch` or `onLoadMore` is pending |

<a name="layout-modes"></a>
## Layout Modes

### Single Select
The default mode for selecting a single item. It displays the label of the selected option in the trigger.

<x-preview path="widgets/w_select_single" size="md" source="example/lib/pages/widgets/w_select_single.dart"></x-preview>

```dart
WSelect<String>(
  value: 'apple',
  options: [
    SelectOption(value: 'apple', label: 'Apple'),
    SelectOption(value: 'banana', label: 'Banana'),
  ],
  onChange: (v) => print(v),
)
```

### Multi Select
Enable `isMulti: true` to allow multiple selections. By default, it displays selected items as chips.

<x-preview path="widgets/w_select_multi" size="md" source="example/lib/pages/widgets/w_select_multi.dart"></x-preview>

```dart
WSelect<String>(
  isMulti: true,
  values: ['red', 'blue'],
  options: [
    SelectOption(value: 'red', label: 'Red'),
    SelectOption(value: 'blue', label: 'Blue'),
    SelectOption(value: 'green', label: 'Green'),
  ],
  onMultiChange: (list) => print(list),
)
```

### Window Edge
An open menu stays inside the window horizontally. When the menu is wider than the room to the right of the trigger (a narrow trigger at the end of a row, or a fixed `menuClassName` width such as `w-64`), it shifts left and sits 8 px inside the window edge. A menu that already fits is not moved, and a menu narrower than the trigger stays aligned with the trigger's left edge. The same applies when the menu opens upward. The menu width is not capped, so the 8 px inset holds only while the menu fits in the window: a menu wider than the window keeps its left edge 8 px in and overflows on the right.

<a name="event-handling"></a>
## Event Handling

`WSelect` provides callbacks for selection changes and remote interactions.

```dart
WSelect<String>(
  options: _options,
  searchable: true,
  hasMore: true,
  onChange: (value) {
    // Handle single selection
  },
  onSearch: (query) async {
    // Return list of options based on search query
    return fetchRemoteOptions(query);
  },
  onLoadMore: () async {
    // Load next page of options
    return fetchNextPage();
  },
  onOpen: resetCursorToPageOne,
)
```

### Pagination and reopening

Opening the menu resets this widget's own view of the list: the search is
cleared and the visible options go back to `options`. Rows that arrived through
`onLoadMore` were appended to the visible list only, so they are gone.

A caller holding a page cursor keeps it across that reset unless `onOpen` tells
it, and the next scroll to the bottom then asks for the page AFTER the one the
reader can see. Measured on a searchable select over a paged endpoint: open,
scroll once to pull page two, close, reopen, and page two's rows were
unreachable without searching for them.

The reset advice assumes `options` goes back to page one along with the visible
list, which is the ordinary shape: return rows from `onLoadMore` and leave
`options` alone. A caller that instead MIRRORS fetched pages into `options`
already has all of them on reopen, so resetting its cursor there would re-fetch
page two and append duplicates. Reset the cursor only if `options` resets too.

<a name="accessibility"></a>
## Accessibility

The closed trigger is one button whose accessible name is its visible text: the selected option's label (labels joined with `, ` in multi-select), and the `placeholder` only while nothing is selected. A test or tapir script that finds a select with a value by its placeholder text must look for the selected label instead. The default placeholder is English and wind has no localisation layer, so pass a translated `placeholder` in a localised app.

The closed trigger publishes exactly one semantics node: it carries the button role, the enabled state, the name, the tap action that opens or closes the menu (absent when `disabled`) and the keyboard focus state. The trigger's own content, including multi-select chips and the output of `triggerBuilder` / `multiTriggerBuilder`, is excluded from semantics so it is not announced a second time. The search field of an open menu keeps its own semantics.

<a name="keyboard-navigation"></a>
## Keyboard Navigation

A select is fully operable from the keyboard, so keyboard and TV (D-pad) users can open it, walk the options and pick one. Tab moves focus to the trigger; the keys below act on it.

| Key | Menu closed (trigger focused) | Menu open | Menu open with `searchable: true` |
|:----|:------------------------------|:----------|:----------------------------------|
| `Enter`, `NumpadEnter`, D-pad centre (`select`), `gameButtonA` | Opens the menu | Selects the highlighted option | Same |
| `Space` | Opens the menu | Selects the highlighted option | Typed into the search field |
| `ArrowDown` | Opens the menu | Highlights the next enabled option | Same |
| `ArrowUp` | Not handled | Highlights the previous enabled option | Same |
| `Home`, `End` | Not handled | Highlights the first or last enabled option | Move the caret in the search field |
| `Escape` | Not handled | Closes the menu and returns focus to the trigger | Same |

- Disabled options are skipped, and the highlight stops at the first and last enabled option instead of wrapping.
- In single mode selecting closes the menu, calls `onChange` and returns focus to the trigger. In multi mode it toggles the option and leaves the menu open.
- While the menu is open these keys are consumed, so the arrows never move focus away. While it is closed, keys the trigger does not use (including `ArrowUp`) are left alone.
- With `searchable: true` opening moves focus to the search field, even from another focused text field, so `ArrowUp`, `ArrowDown`, `Enter` and `Escape` work from it. When the query matches nothing and `onCreateOption` is set, `Enter` runs the `Create "..."` action.
- The highlight is the hover state: `itemBuilder` receives it as `isHovered`, and the default row shows its hover classes. A keyboard open highlights the selected option (the first selected one in multi mode), else the first enabled option; a pointer open starts with no highlight. The highlighted row scrolls into view in a long list, rows of varying `itemBuilder` height included. Rows that scroll under a resting pointer leave a keyboard highlight alone; moving the pointer takes the highlight back. Typing a search resets the highlight; a new `options` list keeps it on the same option (by value) under the current search, and clears it when that option is gone.

<a name="state-variants"></a>
## State Variants

`WSelect` automatically manages several states that you can style using prefixes in `className`:

- `hover:` - When the mouse is over the trigger.
- `focus:` - When the dropdown is open, or when the trigger has keyboard focus (Tab). Never while `disabled`; a disabled select is skipped by Tab.
- `disabled:` - When the widget is disabled.
- `selected:` - When a value is selected.

```dart
WSelect<String>(
  options: _options,
  className: 'border-gray-300 hover:border-blue-500 focus:ring-2 focus:ring-blue-200',
)
```

<a name="styling-examples"></a>
## Styling Examples

### Searchable Select
Combine `searchable: true` with custom menu styling for a robust selection experience.

```dart
WSelect<String>(
  searchable: true,
  searchPlaceholder: 'Search countries...',
  menuClassName: 'bg-white shadow-xl rounded-xl border border-gray-100',
  options: countries,
  onChange: (val) => _country = val,
)
```

### Tagging (Create Option)
Allow users to create new options if a search yields no results.

```dart
WSelect<String>(
  searchable: true,
  onCreateOption: (query) async {
    final newOpt = SelectOption(value: query.toLowerCase(), label: query);
    // Add to your local state/database
    return newOpt;
  },
  options: existingTags,
)
```

<a name="all-supported-classes"></a>
## All Supported Classes

| Category | Classes |
|:---------|:--------|
| Layout | `flex`, `hidden`, `w-{size}`, `h-{size}` |
| Spacing | `p-{n}`, `m-{n}`, `gap-{n}` |
| Visuals | `bg-{color}`, `border`, `rounded`, `shadow` |
| States | `hover:`, `focus:`, `disabled:`, `dark:` |
| Custom | `open:`, `selected:` |

<a name="customizing-theme"></a>
## Customizing Theme

The default styling for `WSelect` and its chips can be influenced by the `WindThemeData`.

```dart
WindThemeData(
  colors: {
    'primary': Colors.indigo,
  },
)
```

<a name="related-documentation"></a>
## Related Documentation

- [WFormSelect](./w-form-select.md) - Form-integrated version with validation
- [WPopover](./w-popover.md) - The underlying overlay engine
- [WInput](./w-input.md) - Used for the internal search field
