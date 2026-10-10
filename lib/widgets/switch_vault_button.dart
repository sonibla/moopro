import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_controller.dart';

class SwitchVaultButton extends ConsumerWidget {
  const SwitchVaultButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.swap_horiz),
      tooltip: 'Switch vault',
      onPressed: () =>
          ref.read(authControllerProvider.notifier).showVaultPicker(),
    );
  }
}
