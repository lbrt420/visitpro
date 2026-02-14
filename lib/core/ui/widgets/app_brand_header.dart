import 'package:flutter/material.dart';

import '../../config/brand_config.dart';

class AppBrandHeader extends StatelessWidget {
  const AppBrandHeader({
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 10),
    this.useSafeArea = true,
  });

  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.png',
              width: 24,
              height: 24,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              appBrandName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
    if (!useSafeArea) {
      return row;
    }
    return SafeArea(bottom: false, child: row);
  }
}
