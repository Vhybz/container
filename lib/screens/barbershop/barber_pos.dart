import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';

class BarberPos extends ConsumerStatefulWidget {
  const BarberPos({super.key});

  @override
  ConsumerState<BarberPos> createState() => _BarberPosState();
}

class _BarberPosState extends ConsumerState<BarberPos> {
  final currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _tipController = TextEditingController(text: '0.0');

  String _selectedBarber = 'Master Barber Frank';
  String _paymentMethod = 'Cash';

  final List<String> _barbers = [
    'Master Barber Frank',
    'Barber Alex',
    'Barber Sam',
  ];

  final List<Map<String, dynamic>> _catalog = [
    {'id': 'S1', 'name': 'Executive Haircut', 'type': 'Service', 'price': 50.0},
    {'id': 'S2', 'name': 'Beard Grooming & Oil', 'type': 'Service', 'price': 30.0},
    {'id': 'S3', 'name': 'Hair Dye / Blackening', 'type': 'Service', 'price': 45.0},
    {'id': 'S4', 'name': 'Facial Scrub & Steam', 'type': 'Service', 'price': 60.0},
    {'id': 'P1', 'name': 'Premium Hair Gel (150g)', 'type': 'Product', 'price': 25.0},
    {'id': 'P2', 'name': 'Beard Growth Oil (50ml)', 'type': 'Product', 'price': 40.0},
  ];

  final List<Map<String, dynamic>> _cart = [];

  void _addToCart(Map<String, dynamic> item) {
    setState(() {
      final idx = _cart.indexWhere((c) => c['id'] == item['id']);
      if (idx >= 0) {
        _cart[idx]['quantity'] += 1;
      } else {
        _cart.add({...item, 'quantity': 1});
      }
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      _cart[index]['quantity'] += delta;
      if (_cart[index]['quantity'] <= 0) {
        _cart.removeAt(index);
      }
    });
  }

  double get _subtotal => _cart.fold(0.0, (s, item) => s + (item['price'] * item['quantity']));
  double get _tip => double.tryParse(_tipController.text) ?? 0.0;
  double get _grandTotal => _subtotal + _tip;

  void _checkout() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty!')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('Barbershop Receipt'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${_customerController.text.isEmpty ? "Walk-In" : _customerController.text}'),
            Text('Assigned Barber: $_selectedBarber'),
            const Divider(),
            ..._cart.map((i) => Text('${i['name']} x ${i['quantity']} - ${currencyFormat.format(i['price'] * i['quantity'])}')),
            if (_tip > 0) ...[
              const Divider(),
              Text('Tip Amount: ${currencyFormat.format(_tip)}'),
            ],
            const Divider(),
            Text('Total Amount: ${currencyFormat.format(_grandTotal)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Payment Method: $_paymentMethod'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _cart.clear();
                _customerController.clear();
                _tipController.text = '0.0';
              });
            },
            child: const Text('COMPLETE TRANSACTION'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barbershop POS & Checkout'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                children: [
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 2.2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _catalog.length,
                      itemBuilder: (context, index) {
                        final item = _catalog[index];
                        final isService = item['type'] == 'Service';
                        return Card(
                          elevation: 2,
                          child: InkWell(
                            onTap: () => _addToCart(item),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.s),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Icon(isService ? Icons.cut : Icons.shopping_bag_outlined, size: 16, color: const Color(0xFF1565C0)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item['name'],
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(currencyFormat.format(item['price']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1565C0))),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: theme.cardColor,
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Client Checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: AppSpacing.s),
                  TextField(
                    controller: _customerController,
                    decoration: const InputDecoration(labelText: 'Customer Name (Optional)', isDense: true),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBarber,
                    decoration: const InputDecoration(labelText: 'Assign Barber for Commission', isDense: true),
                    items: _barbers.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (v) => setState(() => _selectedBarber = v!),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Expanded(
                    child: _cart.isEmpty
                        ? const Center(child: Text('No services or products selected.'))
                        : ListView.separated(
                            itemCount: _cart.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final item = _cart[index];
                              return ListTile(
                                title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('${currencyFormat.format(item['price'])} x ${item['quantity']}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                                      onPressed: () => _updateQuantity(index, -1),
                                    ),
                                    Text('${item['quantity']}'),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 20),
                                      onPressed: () => _updateQuantity(index, 1),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(),
                  TextField(
                    controller: _tipController,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Add Tip (GHS)', isDense: true),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(currencyFormat.format(_grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1565C0))),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.m),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method', isDense: true),
                    items: ['Cash', 'MoMo', 'Card'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) => setState(() => _paymentMethod = v!),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _checkout,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('COMPLETE CHECKOUT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
