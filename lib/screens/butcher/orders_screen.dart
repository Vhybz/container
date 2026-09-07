import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../widgets/status_chip.dart';
import '../../services/butcher_service.dart';
import '../../models/butcher_models.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  ButcherOrderStatus? _selectedStatus;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(butcherOrdersProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: AppSpacing.l),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by Client or Order ID...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: AppSpacing.l),
          _buildOrderTabs(ordersAsync.value ?? []),
          const SizedBox(height: AppSpacing.m),
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                final filtered = orders.where((o) {
                  final matchesStatus = _selectedStatus == null || o.status == _selectedStatus;
                  final matchesSearch = o.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                                       o.id.toLowerCase().contains(_searchQuery.toLowerCase());
                  return matchesStatus && matchesSearch;
                }).toList();
                
                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _buildOrderCard(filtered[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;
        return Flex(
          direction: isMobile ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Processing Orders', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text('Manage pre-orders and bulk requirements', style: TextStyle(color: AppColors.textLight)),
              ],
            ),
            if (isMobile) const SizedBox(height: AppSpacing.m),
            ElevatedButton.icon(
              onPressed: () => _showNewOrderDialog(context),
              icon: const Icon(Icons.add_task),
              label: const Text('Create New Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMaroon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: AppColors.borderGray),
          const SizedBox(height: 16),
          const Text('No orders found matching your criteria.', style: TextStyle(color: AppColors.textLight)),
          TextButton(
            onPressed: () => setState(() {
              _selectedStatus = null;
              _searchQuery = '';
            }),
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  void _showNewOrderDialog(BuildContext context) {
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final customerNameController = TextEditingController();
    final weightController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    final List<String> selectedItems = [];
    final List<String> availableItems = [
      'Beef Sirloin', 'Beef Fillet', 'Beef Chuck', 'Beef Ribs',
      'Pork Belly', 'Pork Chops', 'Pork Shoulder', 'Pork Leg',
      'Goat Mixed', 'Goat Head', 'Goat Feet',
      'Whole Chicken (Hard)', 'Whole Chicken (Soft)',
      'Chicken Wings', 'Chicken Drumsticks', 'Gizzards'
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: Row(
            children: [
              const Icon(Icons.add_task, color: AppColors.primaryMaroon),
              const SizedBox(width: 12),
              const Text('Create Pre-Order'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: customerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer/Client Name',
                        prefixIcon: Icon(Icons.person_outline),
                        hintText: 'e.g. Prime Steakhouse',
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: weightController,
                            decoration: const InputDecoration(
                              labelText: 'Total Est. Weight',
                              prefixIcon: Icon(Icons.scale_outlined),
                              suffixText: 'kg',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (double.tryParse(v) == null) return 'Invalid number';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 90)),
                              );
                              if (picked != null) setDialogState(() => selectedDate = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Due Date'),
                              child: Text(DateFormat('MMM dd, yyyy').format(selectedDate), style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) setDialogState(() => selectedTime = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Pick-up Time', prefixIcon: Icon(Icons.access_time)),
                        child: Text(selectedTime.format(context), style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    const Text('Select Items Required:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(AppRadius.s),
                      ),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: availableItems.map((item) => CheckboxListTile(
                          title: Text(item, style: const TextStyle(fontSize: 12)),
                          value: selectedItems.contains(item),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedItems.add(item);
                              } else {
                                selectedItems.remove(item);
                              }
                            });
                          },
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          activeColor: AppColors.primaryMaroon,
                        )).toList(),
                      ),
                    ),
                    if (selectedItems.isEmpty) 
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Please select at least one item', style: TextStyle(color: Colors.red, fontSize: 10)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedItems.isEmpty ? null : () async {
                if (formKey.currentState!.validate()) {
                  final dueDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );

                  final newOrder = ButcherOrder(
                    id: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                    customerName: customerNameController.text.trim(),
                    items: selectedItems,
                    totalWeight: double.parse(weightController.text),
                    dueDate: dueDateTime,
                    status: ButcherOrderStatus.pending,
                  );

                  try {
                    await ref.read(butcherOrdersProvider.notifier).addOrder(newOrder);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Processing order created successfully!'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to create order: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMaroon, foregroundColor: Colors.white),
              child: const Text('Create Order'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTabs(List<ButcherOrder> orders) {
    int activeCount = orders.where((o) => o.status == ButcherOrderStatus.preparing).length;
    int pendingCount = orders.where((o) => o.status == ButcherOrderStatus.pending).length;
    int readyCount = orders.where((o) => o.status == ButcherOrderStatus.ready).length;
    int completedCount = orders.where((o) => o.status == ButcherOrderStatus.completed).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _tabItem('All (${orders.length})', null),
          _tabItem('Pending ($pendingCount)', ButcherOrderStatus.pending),
          _tabItem('Preparing ($activeCount)', ButcherOrderStatus.preparing),
          _tabItem('Ready ($readyCount)', ButcherOrderStatus.ready),
          _tabItem('Done ($completedCount)', ButcherOrderStatus.completed),
        ],
      ),
    );
  }

  Widget _tabItem(String label, ButcherOrderStatus? status) {
    final bool isSelected = _selectedStatus == status;
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: TextButton(
        onPressed: () => setState(() => _selectedStatus = status),
        style: TextButton.styleFrom(
          foregroundColor: isSelected ? AppColors.primaryMaroon : AppColors.textLight,
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            if (isSelected) Container(height: 2, width: 20, color: AppColors.primaryMaroon, margin: const EdgeInsets.only(top: 4)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(ButcherOrder order) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      child: InkWell(
        onTap: () => _showOrderDetails(context, order),
        borderRadius: BorderRadius.circular(AppRadius.s),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 60,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(AppRadius.s)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(DateFormat('MMM').format(order.dueDate), style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                            Text(DateFormat('dd').format(order.dueDate), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(DateFormat('HH:mm').format(order.dueDate), style: const TextStyle(fontSize: 8, color: AppColors.textLight)),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Order #${order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id}', 
                                    style: const TextStyle(fontWeight: FontWeight.bold), 
                                    overflow: TextOverflow.ellipsis
                                  )
                                ),
                                const SizedBox(width: 8),
                                StatusChip(
                                  label: order.status.name.toUpperCase(), 
                                  color: _getStatusColor(order.status)
                                ),
                              ],
                            ),
                            Text('Client: ${order.customerName}', style: const TextStyle(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text('Items: ${order.items.join(", ")}', style: const TextStyle(fontSize: 11, color: AppColors.textLight), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      if (!isNarrow) ...[
                        const VerticalDivider(),
                        _buildWeightInfo(order),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.print_outlined, size: 20, color: AppColors.textLight),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Printing order ticket for ${order.id}...'))
                            );
                          },
                          tooltip: 'Print Order Ticket',
                        ),
                      ],
                    ],
                  ),
                  if (isNarrow) ...[
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildWeightInfo(order, isHorizontal: true),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.print_outlined, size: 20),
                              onPressed: () {},
                            ),
                            const SizedBox(width: 8),
                            _buildActionButton(order),
                          ],
                        ),
                      ],
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _buildActionButton(order),
                      ),
                    ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(BuildContext context, ButcherOrder order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order Details: ${order.id.toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Customer', order.customerName),
            _detailRow('Status', order.status.name.toUpperCase()),
            _detailRow('Due Date', DateFormat('MMM dd, yyyy HH:mm').format(order.dueDate)),
            _detailRow('Total Weight', '${order.totalWeight} kg'),
            const Divider(),
            const Text('Requested Items:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(item, style: const TextStyle(fontSize: 13)),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.print),
            label: const Text('Print Ticket'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildWeightInfo(ButcherOrder order, {bool isHorizontal = false}) {
    final content = [
      const Text('Total Wt.', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
      Text('${order.totalWeight} kg', style: const TextStyle(fontWeight: FontWeight.bold)),
    ];

    if (isHorizontal) {
      return Row(children: [content[0], const SizedBox(width: 8), content[1]]);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: content,
    );
  }

  Widget _buildActionButton(ButcherOrder order) {
    if (order.status == ButcherOrderStatus.completed) return const Icon(Icons.check_circle, color: Colors.green);

    String label = 'Update';
    ButcherOrderStatus nextStatus = ButcherOrderStatus.preparing;

    switch (order.status) {
      case ButcherOrderStatus.pending:
        label = 'Start Prep';
        nextStatus = ButcherOrderStatus.preparing;
        break;
      case ButcherOrderStatus.preparing:
        label = 'Mark Ready';
        nextStatus = ButcherOrderStatus.ready;
        break;
      case ButcherOrderStatus.ready:
        label = 'Complete';
        nextStatus = ButcherOrderStatus.completed;
        break;
      case ButcherOrderStatus.completed:
        break;
    }

    return ElevatedButton(
      onPressed: () => ref.read(butcherOrdersProvider.notifier).updateStatus(order.id, nextStatus),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryMaroon, 
        foregroundColor: Colors.white, 
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), 
        minimumSize: const Size(80, 32)
      ),
      child: Text(label, style: const TextStyle(fontSize: 10)),
    );
  }

  Color _getStatusColor(ButcherOrderStatus status) {
    switch (status) {
      case ButcherOrderStatus.pending: return Colors.orange;
      case ButcherOrderStatus.preparing: return Colors.blue;
      case ButcherOrderStatus.ready: return Colors.purple;
      case ButcherOrderStatus.completed: return Colors.green;
    }
  }
}
