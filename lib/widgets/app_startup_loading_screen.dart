import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppStartupLoadingScaffold extends StatelessWidget {
  const AppStartupLoadingScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: AppStartupLoadingIndicator());
  }
}

class AppStartupLoadingIndicator extends StatelessWidget {
  const AppStartupLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: SizedBox(
          width: 108,
          height: 108,
          child: CircularProgressIndicator(
            strokeCap: StrokeCap.round,
            strokeWidth: 8,
            strokeAlign: -1,
            backgroundColor: AppTheme.accentSoft(brightness),
            color: AppTheme.accent(brightness),
          ),
        ),
      ),
    );
  }
}
