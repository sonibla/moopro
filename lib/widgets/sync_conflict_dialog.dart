import 'package:flutter/material.dart';

Future<void> showSyncConflictDialog(
  BuildContext context, {
  required VoidCallback onDismiss,
  required VoidCallback onOpen,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sync conflict'),
      content: const Text(
        'This was changed on another device before your edit could be '
        'saved, so your edit was discarded. The version shown now is the '
        'current one from the server.',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onDismiss();
          },
          child: const Text('Dismiss'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onOpen();
          },
          child: const Text('Open'),
        ),
      ],
    ),
  );
}
