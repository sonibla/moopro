import 'package:flutter/material.dart';

import 'tag_input.dart';

Future<({List<String> add, List<String> remove})?> showMassEditTagsDialog(
  BuildContext context, {
  required int count,
  required List<String> presentTags,
}) {
  return showDialog<({List<String> add, List<String> remove})>(
    context: context,
    builder: (context) =>
        _MassEditTagsDialog(count: count, presentTags: presentTags),
  );
}

class _MassEditTagsDialog extends StatefulWidget {
  final int count;
  final List<String> presentTags;
  const _MassEditTagsDialog({required this.count, required this.presentTags});

  @override
  State<_MassEditTagsDialog> createState() => _MassEditTagsDialogState();
}

class _MassEditTagsDialogState extends State<_MassEditTagsDialog> {
  List<String> _add = [];
  final Set<String> _remove = {};

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    return AlertDialog(
      title: Text(
        'Edit tags of ${widget.count} transaction'
        '${widget.count == 1 ? '' : 's'}',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tags to add', style: labelStyle),
              const SizedBox(height: 8),
              TagInput(
                tags: _add,
                onChanged: (v) => setState(() {
                  _add = v;
                  _remove.removeAll(v);
                }),
              ),
              const SizedBox(height: 20),
              Text('Tags to remove', style: labelStyle),
              const SizedBox(height: 8),
              if (widget.presentTags.isEmpty)
                Text(
                  'None of the selected transactions have tags.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in widget.presentTags)
                      FilterChip(
                        label: Text(tag),
                        selected: _remove.contains(tag),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _remove.add(tag);
                            _add = _add.where((t) => t != tag).toList();
                          } else {
                            _remove.remove(tag);
                          }
                        }),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _add.isEmpty && _remove.isEmpty
              ? null
              : () => Navigator.of(
                  context,
                ).pop((add: _add, remove: _remove.toList()..sort())),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
