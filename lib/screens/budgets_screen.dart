import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../widgets/container_explorer/container_explorer_body.dart';
import '../widgets/container_form_dialog.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'budgetsScreenFab',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) =>
              const ContainerFormDialog(initialType: ContainerType.budget),
        ),
        child: const Icon(Icons.add),
      ),
      body: const ContainerExplorerBody(type: ContainerType.budget),
    );
  }
}
