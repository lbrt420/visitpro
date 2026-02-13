import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/app_localizations.dart';

class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.value,
    required this.onRetry,
    required this.data,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${l10n.somethingWentWrong}\n$error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
      data: data,
    );
  }
}
