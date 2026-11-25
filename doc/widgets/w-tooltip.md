# WTooltip

A Material-free tooltip styled through `className`: it shows a short message when the pointer hovers, the keyboard focuses or a finger long-presses the child it wraps.

- [Basic Usage](#basic-usage)
- [Constructor](#constructor)
- [Props](#props)
- [Behaviour](#behaviour)
- [Placement](#placement)
- [Styling](#styling)
- [Related Documentation](#related-documentation)

<x-preview path="widgets/w_tooltip_basic" size="md" source="example/lib/pages/widgets/w_tooltip_basic.dart"></x-preview>

```dart
WTooltip(
  message: 'Save changes',
  child: WButton(
    onTap: save,
    child: WText('Save'),
  ),
)
```

<a name="basic-usage"></a>
## Basic Usage

Wrap the widget that should explain itself and give it a `message`. The tooltip needs an `Overlay` ancestor, which any `MaterialApp` or `WidgetsApp` provides.

```dart
WTooltip(
  message: 'Delete this draft',
  alignment: PopoverAlignment.topCenter,
  child: WIcon(Icons.delete_outline, className: 'text-gray-500 dark:text-gray-400'),
)
```

<a name="constructor"></a>
## Constructor

```dart
const WTooltip({
  Key? key,
  required String message,
  required Widget child,
  String? className,
  PopoverAlignment alignment = PopoverAlignment.bottomCenter,
  Offset offset = const Offset(0, 4),
  Duration hoverDelay = const Duration(milliseconds: 500),
})
```

<a name="props"></a>
## Props

| Prop | Type | Default | Description |
|:-----|:-----|:--------|:------------|
| `message` | `String` | **Required** | The text shown in the tooltip and exposed as the child's semantics tooltip. An empty string renders the bare `child`: no overlay and no semantics tooltip. |
| `child` | `Widget` | **Required** | The widget that triggers the tooltip. |
| `className` | `String?` | `null` | Wind utility classes for the tooltip box. When `null` the default box applies; a value replaces the default entirely. |
| `alignment` | `PopoverAlignment` | `bottomCenter` | Where the tooltip sits relative to the child. |
| `offset` | `Offset` | `Offset(0, 4)` | Gap between the child and the tooltip, in logical pixels. |
| `hoverDelay` | `Duration` | `Duration(milliseconds: 500)` | How long a mouse pointer must hover the child before the tooltip shows. |

<a name="behaviour"></a>
## Behaviour

- **Hover**: the tooltip shows once the pointer has hovered the child for `hoverDelay` and hides when the pointer leaves. The box itself is hoverable, so moving the pointer from the child onto the tooltip keeps it open.
- **Keyboard focus**: when focus reaches the child, the tooltip shows at once, and it hides again on blur, but only while that tooltip is still open from the focus: a blur never closes a tooltip that Escape had already dismissed or that another widget has since shown. It does so only while Flutter's focus highlight mode is the keyboard one, so a touch focus does not pop it. On desktop and web that mode also stays active after mouse input, so a click that moves focus into the child shows the tooltip at once and it stays until blur.
- **Long press**: on touch, a long press shows the tooltip, and it stays for 1.5 seconds after the finger lifts.
- **Escape**: Escape dismisses every open tooltip. While no tooltip is open, Escape is left alone and reaches the app's own shortcuts.
- **Never takes focus**: `WTooltip` is not a Tab stop and never becomes the primary focus, even when `className` carries a `focus:` class. The child keeps its own focus behaviour.
- **Semantics**: `message` becomes the child's semantics tooltip, so screen readers announce it with the child.
- **Empty message**: an empty `message` renders the bare child, with no overlay, no semantics tooltip and no hover or focus trigger.

<a name="placement"></a>
## Placement

`alignment` takes the same `PopoverAlignment` values as `WPopover`:

| Alignment | Description |
|:----------|:------------|
| `bottomCenter` | Below the child, centred horizontally (Default). |
| `bottomLeft` | Below the child, aligned to its left edge. |
| `bottomRight` | Below the child, aligned to its right edge. |
| `topCenter` | Above the child, centred horizontally. |
| `topLeft` | Above the child, aligned to its left edge. |
| `topRight` | Above the child, aligned to its right edge. |

The tooltip flips to the opposite side when the requested one has no room, and it is pulled back inside the overlay horizontally. A box taller than the room on its side is held inside the overlay with an 8 pixel margin. The box is capped at the overlay height less that margin on both sides, and a message longer than the cap scrolls inside it.

```dart
WTooltip(
  message: 'Open settings',
  alignment: PopoverAlignment.topRight,
  offset: const Offset(0, 8),
  child: WIcon(Icons.settings, className: 'text-gray-600 dark:text-gray-300'),
)
```

<a name="styling"></a>
## Styling

When `className` is `null`, the box uses `bg-gray-900 dark:bg-gray-100 text-white dark:text-gray-900 text-xs px-2 py-1 rounded-md`. A `className` you pass replaces that default rather than extending it, so carry the `dark:` pair of every colour class yourself.

```dart
WTooltip(
  message: 'Copied',
  className: 'bg-blue-600 dark:bg-blue-500 text-white dark:text-white text-sm px-3 py-2 rounded-lg shadow-lg',
  child: WButton(
    onTap: copy,
    child: WText('Copy'),
  ),
)
```

<a name="related-documentation"></a>
## Related Documentation

- [WPopover](./w-popover.md): the overlay widget whose placement helpers WTooltip reuses.
- [WDiv](./w-div.md): the container the tooltip box is built on.
- [WText](./w-text.md): the text widget that renders the message.
