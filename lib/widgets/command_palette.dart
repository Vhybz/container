import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/menu_service.dart';
import '../services/product_service.dart';
import '../services/customer_provider.dart';
import '../services/user_provider.dart';
import '../core/constants.dart';

class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const CommandPalette(),
    );
  }

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final menuItems = MenuService.getMenuItemsForUser(user);
    final products = ref.watch(productsFutureProvider).value ?? [];
    final customers = ref.watch(customerProvider);

    final filteredMenu = menuItems.where((i) => 
      i.label.toLowerCase().contains(_query.toLowerCase())
    ).toList();

    final filteredProducts = products.where((p) => 
      !p.isDeleted && p.name.toLowerCase().contains(_query.toLowerCase())
    ).take(5).toList();

    final filteredCustomers = customers.where((c) => 
      c.name.toLowerCase().contains(_query.toLowerCase()) || 
      c.phone.contains(_query)
    ).take(5).toList();

    final bool hasResults = filteredMenu.isNotEmpty || filteredProducts.isNotEmpty || filteredCustomers.isNotEmpty;

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Type to search products, customers, or actions...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() {
                        _searchController.clear();
                        _query = '';
                      })) 
                    : const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text('⌘K', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (_query.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.keyboard_command_key_rounded, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Global Command Palette', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text('Quickly jump to any screen or find a record.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              )
            else if (!hasResults)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text('No matches found.', style: TextStyle(color: Colors.grey)),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (filteredMenu.isNotEmpty) ...[
                      _buildHeader('ACTIONS & SCREENS'),
                      ...filteredMenu.map((item) => ListTile(
                        leading: Icon(item.icon, size: 20),
                        title: Text(item.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text('Navigate to ${item.route}', style: const TextStyle(fontSize: 11)),
                        onTap: () {
                          Navigator.pop(context);
                          MenuService.navigate(context, item.route, '');
                        },
                      )),
                    ],
                    if (filteredProducts.isNotEmpty) ...[
                      _buildHeader('PRODUCTS'),
                      ...filteredProducts.map((p) => ListTile(
                        leading: const Icon(Icons.inventory_2_outlined, size: 20, color: Colors.blue),
                        title: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text('${p.category} • ₵${p.retailPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/admin/stock'); // In a real app, jump to product details
                        },
                      )),
                    ],
                    if (filteredCustomers.isNotEmpty) ...[
                      _buildHeader('CUSTOMERS'),
                      ...filteredCustomers.map((c) => ListTile(
                        leading: const Icon(Icons.person_outline, size: 20, color: Colors.green),
                        title: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(c.phone, style: const TextStyle(fontSize: 11)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/admin/customers');
                        },
                      )),
                    ],
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.m)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.keyboard_return_rounded, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  const Text('to select', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(width: 16),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 12, color: Colors.grey),
                  const Icon(Icons.keyboard_arrow_up_rounded, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  const Text('to navigate', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ESC to close', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
      ),
    );
  }
}
