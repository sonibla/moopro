import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/transaction_filter.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class TagInput extends ConsumerStatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  const TagInput({super.key, required this.tags, required this.onChanged});

  @override
  ConsumerState<TagInput> createState() => _TagInputState();
}

class _TagInputState extends ConsumerState<TagInput> {
  final _controller = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final tag = raw.trim();
    setState(() => _adding = false);
    _controller.clear();
    if (tag.isEmpty || widget.tags.contains(tag)) return;
    widget.onChanged([...widget.tags, tag]);
  }

  void _remove(String tag) {
    widget.onChanged(widget.tags.where((t) => t != tag).toList());
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final suggestions = (transactionsAsync.value == null)
        ? const <String>[]
        : allTags(transactionsAsync.value!)
              .where((t) => !widget.tags.contains(t))
              .where(
                (t) =>
                    _controller.text.isEmpty ||
                    t.toLowerCase().contains(
                      _controller.text.trim().toLowerCase(),
                    ),
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in widget.tags)
              InputChip(label: Text(tag), onDeleted: () => _remove(tag)),
            if (!_adding)
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Add tag'),
                shape: StadiumBorder(
                  side: BorderSide(
                    color: AppTheme.lineStrong(Theme.of(context).brightness),
                    style: BorderStyle.solid,
                  ),
                ),
                onPressed: () => setState(() => _adding = true),
              ),
          ],
        ),
        if (_adding) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Tag name',
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check, size: 18),
                  onPressed: () => _commit(_controller.text),
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: _commit,
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in suggestions.take(8))
                  ActionChip(label: Text(s), onPressed: () => _commit(s)),
              ],
            ),
          ],
        ],
      ],
    );
  }
}
