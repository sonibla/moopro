import 'package:flutter/material.dart';

List<String> filterTagsByQuery(Map<String, int> tagCounts, String query) {
  final q = query.trim().toLowerCase();
  return tagCounts.keys.where((t) => t.toLowerCase().contains(q)).toList()
    ..sort((a, b) {
      final byCount = tagCounts[b]!.compareTo(tagCounts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
}

Future<Set<String>?> showTagPicker({
  required BuildContext context,
  required Map<String, int> tagCounts,
  required Set<String> selected,
  String title = 'Filter by tags',
}) async {
  final content = _TagPickerContent(
    tagCounts: tagCounts,
    selected: selected,
    title: title,
  );

  final wide = MediaQuery.sizeOf(context).width > 900;
  if (wide) {
    return showDialog<Set<String>>(
      context: context,
      builder: (_) =>
          Dialog(child: SizedBox(width: 420, height: 560, child: content)),
    );
  }
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: content,
      ),
    ),
  );
}

class _TagPickerContent extends StatefulWidget {
  final Map<String, int> tagCounts;
  final Set<String> selected;
  final String title;

  const _TagPickerContent({
    required this.tagCounts,
    required this.selected,
    required this.title,
  });

  @override
  State<_TagPickerContent> createState() => _TagPickerContentState();
}

class _TagPickerContentState extends State<_TagPickerContent> {
  final _searchController = TextEditingController();
  late Set<String> _selected = {...widget.selected};
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(String tag) => setState(() {
    final next = {..._selected};
    if (!next.add(tag)) next.remove(tag);
    _selected = next;
  });

  @override
  Widget build(BuildContext context) {
    final matches = filterTagsByQuery(widget.tagCounts, _query);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search tags...',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final tag in _selected.toList()..sort())
                    InputChip(label: Text(tag), onDeleted: () => _toggle(tag)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: matches.isEmpty
                ? const Center(child: Text('No matches.'))
                : ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, i) {
                      final tag = matches[i];
                      return CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _selected.contains(tag),
                        onChanged: (_) => _toggle(tag),
                        title: Text(tag),
                        secondary: Text('${widget.tagCounts[tag]}'),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Showing transactions with all selected tags',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => setState(() => _selected = {}),
                  child: const Text('Clear'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
