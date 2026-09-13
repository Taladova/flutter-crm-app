import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

class AppFilterTabs extends StatelessWidget {
  const AppFilterTabs({
    super.key,
    required this.labels,
    required this.selectedLabel,
    required this.onSelected,
    this.counts = const {},
    this.scrollable = true,
  });

  final List<String> labels;
  final String selectedLabel;
  final ValueChanged<String> onSelected;
  final Map<String, int> counts;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final children = labels.map((label) {
      final isSelected = selectedLabel == label;
      final count = counts[label];

      return Padding(
        padding: const EdgeInsets.only(right: 18),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelected(label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count == null ? label : '$label $count',
                  maxLines: 1,
                  style: TextStyle(
                    color: isSelected
                        ? AppTheme.primary(context)
                        : AppTheme.secondaryTextColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: isSelected ? 30 : 0,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: AppTheme.primary(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();

    if (!scrollable) {
      return Row(
        children: children.map((child) => Expanded(child: child)).toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(children: children),
    );
  }
}
