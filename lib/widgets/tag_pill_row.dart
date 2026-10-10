import 'package:flutter/material.dart';

class TagPillRow extends StatelessWidget {
  final List<String> tags;
  final double height;

  const TagPillRow({super.key, required this.tags, required this.height});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    final sorted = [...tags]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final tag in sorted)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    label: Text(tag, style: style),
                    visualDensity: const VisualDensity(
                      horizontal: -4,
                      vertical: -4,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
