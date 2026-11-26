import 'package:material_ui/material_ui.dart';
import 'package:wind_kit/wind_kit.dart';

import '../../widgets/example_scaffold.dart';

class WTooltipBasicExamplePage extends StatelessWidget {
  const WTooltipBasicExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Tooltip',
      description: 'A className-styled hint that shows on hover, keyboard focus or long press and hides on Escape.',
      gradient: 'from-slate-700 to-slate-900',
      children: [
        ExampleSection(
          title: 'Basic Usage',
          description: 'Hover an icon for half a second to read what it does.',
          child: WDiv(
            className: 'wrap gap-3 py-6',
            children: const [
              WTooltip(
                message: 'Save changes',
                child: _IconAction(icon: Icons.save_outlined, label: 'Save'),
              ),
              WTooltip(
                message: 'Copy link',
                child: _IconAction(icon: Icons.link_outlined, label: 'Copy'),
              ),
              WTooltip(
                message: 'Delete item',
                child: _IconAction(
                  icon: Icons.delete_outlined,
                  label: 'Delete',
                ),
              ),
            ],
          ),
        ),
        ExampleSection(
          title: 'Alignment',
          description: 'alignment picks the side; the tooltip flips when an edge would clip it.',
          child: WDiv(
            className: 'wrap gap-3 py-10',
            children: const [
              _AlignedTooltip(alignment: PopoverAlignment.bottomLeft),
              _AlignedTooltip(alignment: PopoverAlignment.bottomCenter),
              _AlignedTooltip(alignment: PopoverAlignment.bottomRight),
              _AlignedTooltip(alignment: PopoverAlignment.topLeft),
              _AlignedTooltip(alignment: PopoverAlignment.topCenter),
              _AlignedTooltip(alignment: PopoverAlignment.topRight),
            ],
          ),
        ),
        ExampleSection(
          title: 'Custom Style',
          description: 'A className replaces the default box, and hoverDelay shortens the wait.',
          child: WDiv(
            className: 'wrap gap-3 py-6',
            children: const [
              WTooltip(
                message: 'Shared with John Doe',
                hoverDelay: Duration(milliseconds: 150),
                className: '''
                  bg-purple-600 dark:bg-purple-400
                  text-white dark:text-purple-950
                  text-sm font-medium
                  px-3 py-1.5 rounded-lg
                  border border-purple-700 dark:border-purple-300
                ''',
                child: _IconAction(icon: Icons.share_outlined, label: 'Share'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlignedTooltip extends StatelessWidget {
  final PopoverAlignment alignment;

  const _AlignedTooltip({required this.alignment});

  @override
  Widget build(BuildContext context) {
    return WTooltip(
      message: alignment.name,
      alignment: alignment,
      child: const _IconAction(icon: Icons.info_outlined, label: 'Placement'),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;

  /// The button's accessible name. It differs from the tooltip message: the
  /// enclosing WTooltip publishes the message as the semantics tooltip, so a
  /// label of the same text would be announced twice.
  final String label;

  const _IconAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return WButton(
      onTap: () {},
      semanticLabel: label,
      className: '''
        p-3 rounded-lg
        bg-slate-100 dark:bg-slate-700
        hover:bg-slate-200 dark:hover:bg-slate-600
        focus:ring-2 focus:ring-slate-400 dark:focus:ring-slate-500
        duration-200
      ''',
      child: WIcon(
        icon,
        className: 'w-5 h-5 text-slate-700 dark:text-slate-200',
      ),
    );
  }
}
