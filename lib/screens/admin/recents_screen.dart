import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/app_sidebar.dart';
import '../../services/menu_service.dart';
import '../../services/user_provider.dart';
import '../../services/sale_provider.dart';
import '../../services/expense_provider.dart';
import '../../services/butcher_service.dart';
import '../../models/sale_model.dart';
import '../../models/butcher_models.dart';
import '../../models/expense_model.dart';

class RecentsScreen extends ConsumerStatefulWidget {
  const RecentsScreen({super.key});

  @override
  ConsumerState<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends ConsumerState<RecentsScreen> {
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  String _activeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/admin/recents';
    final menuItems = ref.watch(menuItemsProvider);

    final sales = ref.watch(saleHistoryProvider);
    final expenses = ref.watch(expenseProvider).records;
    final logs = ref.watch(slaughterLogsProvider).value ?? [];

    final allActivity = _combineAndFilterActivity(sales, expenses, logs);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const MainAppBar(title: 'Company Recents'),
      drawer: isDesktop ? null : Drawer(
        child: AppSidebar(
          userId: user.id,
          userName: user.name,
          userRole: user.activePrimaryRole.name.toUpperCase(),
          currentRoute: currentRoute,
          items: menuItems,
          onTap: (route) => MenuService.navigate(context, route, currentRoute),
        ),
      ),
      body: Row(
        children: [
          if (isDesktop)
            AppSidebar(
              userId: user.id,
              userName: user.name,
              userRole: user.activePrimaryRole.name.toUpperCase(),
              currentRoute: currentRoute,
              items: menuItems,
              onTap: (route) => MenuService.navigate(context, route, currentRoute),
            ),
          Expanded(
            child: Column(
              children: [
                _buildFilterBar(theme),
                Expanded(
                  child: allActivity.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.l),
                          itemCount: allActivity.length,
                          itemBuilder: (context, index) {
                            final item = allActivity[index];
                            return _buildActivityTile(item);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search sales, items, or staff...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              OutlinedButton.icon(
                onPressed: _pickDateRange,
                icon: const Icon(Icons.date_range),
                label: Text(_selectedDateRange == null 
                  ? 'Filter by Date' 
                  : '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Sales', 'Expenses', 'Butcher Logs'].map((filter) {
                final isSelected = _activeFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (v) => setState(() => _activeFilter = filter),
                    selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                    checkmarkColor: theme.colorScheme.primary,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(dynamic item) {
    if (item is SaleRecord) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: Colors.blue.withValues(alpha: 0.1),
            child: const Icon(Icons.point_of_sale, color: Colors.blue, size: 20),
          ),
          title: Row(
            children: [
              Expanded(child: Text('Sale: ${item.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              Text('₵${item.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
            ],
          ),
          subtitle: Text(
            'Cashier: ${item.cashierName} • ${DateFormat('MMM dd, HH:mm').format(item.timestamp)}',
            style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    } else if (item is ExpenseRecord) {
       return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: Colors.red.withValues(alpha: 0.1),
            child: const Icon(Icons.receipt_long, color: Colors.red, size: 20),
          ),
          title: Row(
            children: [
              Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              Text('₵${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
            ],
          ),
          subtitle: Text(
            '${item.category} • ${DateFormat('MMM dd, yyyy').format(item.date)}',
            style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    } else if (item is SlaughterLog) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: Colors.orange.withValues(alpha: 0.1),
            child: const Icon(Icons.pets, color: Colors.orange, size: 20),
          ),
          title: Row(
            children: [
              Expanded(child: Text('Butcher Log: ${item.type.displayName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              Text('${item.liveWeight}kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          subtitle: Text(
            'Status: ${item.status.name.toUpperCase()} • ${DateFormat('MMM dd, HH:mm').format(item.slaughterTime ?? DateTime.now())}',
            style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  List<dynamic> _combineAndFilterActivity(List<SaleRecord> sales, List<ExpenseRecord> expenses, List<SlaughterLog> logs) {
    List<dynamic> combined = [];
    
    if (_activeFilter == 'All' || _activeFilter == 'Sales') combined.addAll(sales);
    if (_activeFilter == 'All' || _activeFilter == 'Expenses') combined.addAll(expenses);
    if (_activeFilter == 'All' || _activeFilter == 'Butcher Logs') combined.addAll(logs);

    // Filter by Search Query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      combined = combined.where((item) {
        if (item is SaleRecord) {
          return item.id.toLowerCase().contains(q) || item.cashierName.toLowerCase().contains(q);
        }
        if (item is ExpenseRecord) {
          return item.title.toLowerCase().contains(q) || item.category.toLowerCase().contains(q);
        }
        if (item is SlaughterLog) {
          return item.animalId.toLowerCase().contains(q) || item.type.displayName.toLowerCase().contains(q);
        }
        return false;
      }).toList();
    }

    // Filter by Date Range
    if (_selectedDateRange != null) {
      combined = combined.where((item) {
        DateTime date;
        if (item is SaleRecord) {
          date = item.timestamp;
        } else if (item is ExpenseRecord) {
          date = item.date;
        } else if (item is SlaughterLog) {
          date = item.slaughterTime ?? DateTime.now();
        } else {
          return false;
        }

        return date.isAfter(_selectedDateRange!.start) && date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Sort by Date Descending
    combined.sort((a, b) {
      DateTime dateA;
      if (a is SaleRecord) {
        dateA = a.timestamp;
      } else if (a is ExpenseRecord) {
        dateA = a.date;
      } else {
        dateA = (a as SlaughterLog).slaughterTime ?? DateTime.now();
      }

      DateTime dateB;
      if (b is SaleRecord) {
        dateB = b.timestamp;
      } else if (b is ExpenseRecord) {
        dateB = b.date;
      } else {
        dateB = (b as SlaughterLog).slaughterTime ?? DateTime.now();
      }

      return dateB.compareTo(dateA);
    });

    return combined;
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) setState(() => _selectedDateRange = picked);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 64, color: Theme.of(context).dividerColor),
          const SizedBox(height: 16),
          const Text('No recent activity found matching your search.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
