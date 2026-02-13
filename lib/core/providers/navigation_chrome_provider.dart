import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavigationChromeNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  void setCompact(bool compact) {
    if (state == compact) {
      return;
    }
    state = compact;
  }
}

final compactNavigationBarProvider =
    NotifierProvider<NavigationChromeNotifier, bool>(
  NavigationChromeNotifier.new,
);
