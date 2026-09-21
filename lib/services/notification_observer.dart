import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service.dart';
import 'product_service.dart';

/// This provider observes notifications and triggers side effects in other services.
/// This helps break circular dependencies between services.
final notificationObserverProvider = Provider<void>((ref) {
  ref.listen(notificationProvider, (previous, next) {
    if (next.isEmpty) return;

    // Check if there are any NEW notifications that should trigger a refresh
    final List<String> previousIds = previous?.map((n) => n.id).toList() ?? [];
    final newNotifications = next.where((n) => !previousIds.contains(n.id)).toList();

    for (final n in newNotifications) {
      final title = n.title.toUpperCase();
      final msg = n.message.toUpperCase();

      final bool isStockAlert = title.contains('STOCK') ||
                                msg.contains('STOCK') ||
                                msg.contains('RESTOCKED');

      if (isStockAlert) {
        // Trigger immediate refresh of product catalog
        Future.delayed(const Duration(milliseconds: 500), () {
          try {
            ref.read(productsFutureProvider.notifier).loadProducts();
          } catch (e) {
            // Silently ignore if providers are disposed
          }
        });
      }
    }
  });
});
