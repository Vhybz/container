import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';

class TechPos extends ConsumerStatefulWidget {
  const TechPos({super.key});

  @override
  ConsumerState<TechPos> createState() => _TechPosState();
}

class _TechPosState extends ConsumerState<TechPos> {
  final currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _imeiController = TextEditingController();

  String _paymentMethod = 'MoMo';

  final List<Map<String, dynamic>> _catalog = [
    {'id': 'T1', 'name': 'iPhone 15 Pro 128GB', 'type': 'Device', 'price': 14500.0, 'requiresImei': true},
    {'id': 'T2', 'name': 'Samsung S24 Ultra', 'type': 'Device', 'price': 15200.0, 'requiresImei': true},
    {'id': 'T3', 'name': '20W USB-C Fast Charger', 'type': 'Accessory', 'price': 180.0, 'requiresImei': false},
    {'id': 'T4', 'name': 'MagSafe Clear Case', 'type': 'Accessory', 'price': 120.0, 'requiresImei': false},
    {'id': 'T5', 'name': '9D Curved Tempered Glass', 'type': 'Accessory', 'price': 50.0, 'requiresImei': false},
    {'id': 'R1', 'name': 'iPhone Screen Repair (Labor + Part)', 'type': 'Repair', 'price': 1200.0, 'requiresImei': false},
  ];

  final List<Map<String, dynamic>> _cart = [];

  void _addToCart(Map<String, dynamic> item) {
    setState(() {
      final idx = _cart.indexWhere((c) => c['id'] == item['id']);
      if (idx >= 0 && !item['requiresImei']) {
        _cart[idx]['quantity'] += 1;
      } else {
        _cart.add({...item, 'quantity': 1, 'imei': ''});
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

  bool get _hasDeviceRequiringImei => _cart.any((i) => i['requiresImei'] == true);

  double get _subtotal => _cart.fold(0.0, (s, item) => s + (item['price'] * item['quantity']));

  void _checkout() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty!')));
      return;
    }

    if (_hasDeviceRequiringImei && _imeiController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device in cart requires valid IMEI/Serial Number.'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.verified_outlined, color: Color(0xFFE65100)),
            SizedBox(width: 8),
            Text('Tech Purchase & Warranty Certificate'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${_customerController.text.isEmpty ? "Walk-In" : _customerController.text}'),
            if (_phoneController.text.isNotEmpty) Text('Phone: ${_phoneController.text}'),
            if (_hasDeviceRequiringImei) Text('Registered IMEI: ${_imeiController.text}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
            const Divider(),
            ..._cart.map((i) => Text('${i['name']} x ${i['quantity']} - ${currencyFormat.format(i['price'] * i['quantity'])}')),
            const Divider(),
            Text('Total Paid: ${currencyFormat.format(_subtotal)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Payment Method: $_paymentMethod'),
            const SizedBox(height: 8),
            const Text('Warranty Certificate Issued (12 Months Coverage).', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _cart.clear();
                _customerController.clear();
                _phoneController.clear();
                _imeiController.clear();
              });
            },
            child: const Text('COMPLETE & PRINT WARRANTY'),
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
        title: const Text('Tech Shop POS & Warranty Generator'),
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
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
                            Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text('Type: ${item['type']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(currencyFormat.format(item['price']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFE65100))),
                          ],
                        ),
                      ),
                    ),
                  );
                },
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
                  const Text('Tech Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: AppSpacing.s),
                  TextField(
                    controller: _customerController,
                    decoration: const InputDecoration(labelText: 'Customer Name', isDense: true),
                  ),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Phone Number', isDense: true),
                  ),
                  if (_hasDeviceRequiringImei) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _imeiController,
                      decoration: const InputDecoration(
                        labelText: 'IMEI / Serial Number *',
                        prefixIcon: Icon(Icons.qr_code),
                        isDense: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.m),
                  Expanded(
                    child: _cart.isEmpty
                        ? const Center(child: Text('Select devices or accessories.'))
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(currencyFormat.format(_subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFE65100))),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.m),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment Mode', isDense: true),
                    items: ['MoMo', 'Cash', 'Card'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) => setState(() => _paymentMethod = v!),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _checkout,
                      icon: const Icon(Icons.verified),
                      label: const Text('CHECKOUT & ISSUE WARRANTY'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
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
