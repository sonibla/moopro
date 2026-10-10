import 'package:flutter/material.dart';

import '../domain/transaction_list_grouping.dart';
import '../theme/app_theme.dart';

class NowMarkerRow extends StatelessWidget {
  const NowMarkerRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.accent(theme.brightness);
    final line = Expanded(
      child: Divider(height: 1, thickness: 1, color: accent),
    );
    return SizedBox(
      key: const ValueKey('nowMarker'),
      height: NowMarkerItem.height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            line,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'NOW',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent,
                  letterSpacing: 1,
                ),
              ),
            ),
            line,
          ],
        ),
      ),
    );
  }
}
