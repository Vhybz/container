import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cart_provider.dart';

/// Observes route transitions across the app and notifies [cartProvider]
/// whenever entering a POS screen. If switching from one POS to a different POS,
/// the cart is automatically cleared.
class PosNavigatorObserver extends NavigatorObserver {
  final Ref ref;

  PosNavigatorObserver(this.ref);

  void _handleRoute(Route<dynamic>? route) {
    final routeName = route?.settings.name;
    if (routeName == null) return;
    final posId = CartNotifier.normalizePosId(routeName);
    if (posId == null) return;

    void update() {
      ref.read(cartProvider.notifier).registerPos(posId);
    }

    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => update());
    } else {
      update();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _handleRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _handleRoute(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _handleRoute(previousRoute);
  }
}

final posNavigatorObserverProvider = Provider<PosNavigatorObserver>((ref) {
  return PosNavigatorObserver(ref);
});
