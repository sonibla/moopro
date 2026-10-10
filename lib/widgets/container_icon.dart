import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'bank_icons.dart';
import 'fa_icon_registry.g.dart';

sealed class ContainerIconKey {
  const ContainerIconKey();

  static const faPrefix = 'fa:';
  static const bankPrefix = 'bank:';

  static String fontAwesome(String name) => '$faPrefix$name';
  static String bank(String id) => '$bankPrefix$id';

  static ContainerIconKey? parse(String? key) {
    if (key == null) return null;
    if (key.startsWith(faPrefix)) {
      final entry = faIconRegistry[key.substring(faPrefix.length)];
      return entry == null ? null : FontAwesomeKey(entry);
    }
    if (key.startsWith(bankPrefix)) {
      final bank = bankIconRegistry[key.substring(bankPrefix.length)];
      return bank == null ? null : BankKey(bank);
    }
    return null;
  }
}

class FontAwesomeKey extends ContainerIconKey {
  final FaIconEntry entry;
  const FontAwesomeKey(this.entry);
}

class BankKey extends ContainerIconKey {
  final BankIcon bank;
  const BankKey(this.bank);
}

class ContainerIcon extends StatelessWidget {
  final String? icon;
  final double? size;
  final Color? color;

  const ContainerIcon(this.icon, {super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final key = ContainerIconKey.parse(icon);
    if (key == null) return const SizedBox.shrink();
    final resolvedSize =
        size ?? DefaultTextStyle.of(context).style.fontSize ?? 14;
    final resolvedColor =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: resolvedSize,
        child: Center(
          child: switch (key) {
            FontAwesomeKey(:final entry) => FaIcon(
              entry.icon,
              size: resolvedSize,
              color: resolvedColor,
            ),
            BankKey(:final bank) => SvgPicture.asset(
              bank.assetPath,
              width: resolvedSize,
              height: resolvedSize,
              colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
            ),
          },
        ),
      ),
    );
  }
}

class ContainerName extends StatelessWidget {
  final String name;
  final String? icon;
  final TextStyle? style;
  final TextOverflow? overflow;
  final int? maxLines;

  const ContainerName(
    this.name, {
    super.key,
    this.icon,
    this.style,
    this.overflow = TextOverflow.ellipsis,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    if (ContainerIconKey.parse(icon) == null) {
      return Text(name, style: style, overflow: overflow, maxLines: maxLines);
    }
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final fontSize = effective.fontSize ?? 14;
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(right: fontSize * 0.5),
              child: ContainerIcon(
                icon,
                size: fontSize,
                color: effective.color,
              ),
            ),
          ),
          TextSpan(text: name),
        ],
      ),
      style: style,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}
