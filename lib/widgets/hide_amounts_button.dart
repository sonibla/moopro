import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../domain/models.dart';
import '../providers/app_providers.dart';

Future<void> setHideAmounts(WidgetRef ref, bool hidden) => ref
    .read(domainRepositoryProvider)
    .setSetting(SettingIds.hideAmounts, hidden ? '1' : '0');

class HideAmountsButton extends ConsumerWidget {
  const HideAmountsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(hideAmountsProvider);
    return IconButton(
      icon: FaIcon(
        hidden ? FontAwesomeIcons.eyeSlash : FontAwesomeIcons.eye,
        size: 18,
      ),
      tooltip: hidden ? 'Show amounts' : 'Hide amounts',
      onPressed: () => setHideAmounts(ref, !hidden),
    );
  }
}
