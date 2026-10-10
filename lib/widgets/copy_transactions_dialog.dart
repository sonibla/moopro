import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../domain/calendar_date.dart';

Future<({CalendarDate effectiveDate, DateTime postedAt})?>
showCopyTransactionsDialog(BuildContext context, {required int count}) {
  return showDialog<({CalendarDate effectiveDate, DateTime postedAt})>(
    context: context,
    builder: (context) => _CopyTransactionsDialog(count: count),
  );
}

class _CopyTransactionsDialog extends ConsumerStatefulWidget {
  final int count;
  const _CopyTransactionsDialog({required this.count});

  @override
  ConsumerState<_CopyTransactionsDialog> createState() =>
      _CopyTransactionsDialogState();
}

class _CopyTransactionsDialogState
    extends ConsumerState<_CopyTransactionsDialog> {
  CalendarDate _date = CalendarDate.today();
  DateTime _postedAt = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(dateTimeFormatPrefsProvider);
    return AlertDialog(
      title: Text(
        'Copy ${widget.count} transaction${widget.count == 1 ? '' : 's'}',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('New date'),
            subtitle: Text(prefs.formatCalendarDate(_date)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Posted'),
            subtitle: Text(prefs.formatDateTime(_postedAt)),
            trailing: const Icon(Icons.schedule),
            onTap: () => _pickPostedAt(prefs.use24HourTime),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop((effectiveDate: _date, postedAt: _postedAt)),
          child: const Text('Copy'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.toDateTime(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = CalendarDate.fromDateTime(picked));
    }
  }

  Future<void> _pickPostedAt(bool use24HourTime) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _postedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_postedAt),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(alwaysUse24HourFormat: use24HourTime),
        child: child!,
      ),
    );
    if (pickedTime == null) return;
    setState(
      () => _postedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      ),
    );
  }
}
