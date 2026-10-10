import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/models.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'container_icon.dart';
import 'container_icon_picker.dart';
import 'container_picker.dart';

class ContainerFormDialog extends ConsumerStatefulWidget {
  final ldb.Container? existing;

  final ContainerType initialType;

  const ContainerFormDialog({
    super.key,
    this.existing,
    this.initialType = ContainerType.holder,
  });

  @override
  ConsumerState<ContainerFormDialog> createState() =>
      _ContainerFormDialogState();
}

typedef _FormSnapshot = ({
  String name,
  ContainerType type,
  String? parentId,
  String? icon,
});

class _ContainerFormDialogState extends ConsumerState<ContainerFormDialog> {
  final _nameController = TextEditingController();
  late ContainerType _type;
  String? _parentId;
  String? _icon;
  bool _saving = false;

  late final _FormSnapshot _initialSnapshot;

  bool _forceClose = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _type = ContainerType.fromJson(existing.containerType);
      _parentId = existing.parentId;
      _icon = existing.icon;
    } else {
      _type = widget.initialType;
    }
    _initialSnapshot = _currentSnapshot();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  _FormSnapshot _currentSnapshot() => (
    name: _nameController.text,
    type: _type,
    parentId: _parentId,
    icon: _icon,
  );

  bool get _isDirty => _currentSnapshot() != _initialSnapshot;

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('This container has unsaved changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handlePopInvoked(bool didPop, void result) async {
    if (didPop) return;
    final discard = await _confirmDiscard();
    if (discard && mounted) {
      setState(() => _forceClose = true);
      Navigator.of(context).pop();
    }
  }

  void _requestClose() {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    _confirmDiscard().then((discard) {
      if (discard && mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty || _forceClose,
      onPopInvokedWithResult: _handlePopInvoked,
      child: _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New container' : 'Edit container'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _iconField(context),
            const SizedBox(height: 16),
            SegmentedButton<ContainerType>(
              segments: const [
                ButtonSegment(
                  value: ContainerType.holder,
                  label: Text('Holder'),
                ),
                ButtonSegment(
                  value: ContainerType.budget,
                  label: Text('Budget'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                if (_type == ContainerType.holder) _parentId = null;
              }),
            ),
            if (_type == ContainerType.budget)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ContainerPickerField(
                  label: 'Parent budget',
                  type: ContainerType.budget,
                  value: _parentId,
                  onChanged: (v) => setState(() => _parentId = v),
                  excludeIds: {
                    if (widget.existing != null) widget.existing!.id,
                  },
                  allowNone: true,
                  noneLabel: 'None (top-level)',
                  required: false,
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: _saving ? null : _delete,
            child: const Text('Delete'),
          ),
        TextButton(onPressed: _requestClose, child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickIcon() async {
    final pick = await showContainerIconPicker(context, selected: _icon);
    if (pick != null && mounted) setState(() => _icon = pick.key);
  }

  Widget _iconField(BuildContext context) {
    final theme = Theme.of(context);
    final hasIcon = ContainerIconKey.parse(_icon) != null;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
      onTap: _pickIcon,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Icon',
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Row(
          children: [
            if (hasIcon)
              ContainerIcon(_icon, size: 20, color: theme.colorScheme.onSurface)
            else
              Text(
                'None',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(domainRepositoryProvider);
      final existing = widget.existing;
      await repo.createContainer(
        id: existing?.id,
        name: name,
        containerType: _type,
        parentId: _parentId,
        icon: _icon,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(domainRepositoryProvider).deleteContainer(existing.id);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
