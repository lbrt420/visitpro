import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ForceSpanishDebugNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  void setEnabled(bool value) {
    state = value;
  }
}

final forceSpanishDebugProvider =
    NotifierProvider<ForceSpanishDebugNotifier, bool>(
  ForceSpanishDebugNotifier.new,
);

final localeOverrideProvider = Provider<Locale?>((ref) {
  final forceSpanish = ref.watch(forceSpanishDebugProvider);
  if (forceSpanish) {
    return const Locale('es');
  }
  return null;
});
