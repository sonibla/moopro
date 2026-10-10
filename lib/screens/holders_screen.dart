import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../widgets/container_explorer/container_explorer_body.dart';
import '../widgets/container_form_dialog.dart';

class HoldersScreen extends StatelessWidget {
  const HoldersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'holdersScreenFab',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) =>
              const ContainerFormDialog(initialType: ContainerType.holder),
        ),
        child: const Icon(Icons.add),
      ),
      body: const ContainerExplorerBody(type: ContainerType.holder),
    );
  }
}
