import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';

class PharmacistPos extends ConsumerStatefulWidget {
  const PharmacistPos({super.key});

  @override
  ConsumerState<PharmacistPos> createState() => _PharmacistPosState();
}

class _PharmacistPosState extends ConsumerState<PharmacistPos> {
  final currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _patientController = TextEditingController();
  final TextEditingController _doctorController = TextEditingController();
  final TextEditingController _rxNumberController = TextEditingController();

  final List<Map<String, dynamic>> _medications = [
    {
      'id': 'M1',
      'name': 'Amoxicillin 500mg',
      'category': 'Antibiotic',
      'price': 25.0,
      'isRxRequired': true,
      'batchNo': 'BAT-2024-001',
      'stock': 45
    },
    {
      'id': 'M2',
      'name': 'Paracetamol Extra 500mg',
      'category': 'Analgesic',
      'price': 10.0,
      'isRxRequired': false,
      'batchNo': 'BAT-2024-088',
      'stock': 120
    },
    {
      'id': 'M3',
      'name': 'Ibuprofen 400mg',
      'category': 'NSAID',
      'price': 15.0,
      'isRxRequired': false,
      'batchNo': 'BAT-2024-012',
      'stock': 80
    },
    {
      'id': 'M4',
      'name': 'Metformin 850mg',
      'category': 'Antidiabetic',
      'price': 35.0,
      'isRxRequired': true,
      'batchNo': 'BAT-2024-105',
      'stock': 60
    },
    {
      'id': 'M5',
      'name': 'Vitamin C 1000mg Chewable',
      'category': 'Supplement',
      'price': 18.0,
      'isRxRequired': false,
      'batchNo': 'BAT-2024-200',
      'stock': 200
    },
  ];

  final List<Map<String, dynamic>> _cart = [];
  String _paymentMethod = 'Cash';

  void _addToCart(Map<String, dynamic> item) {
    final existingIndex = _cart.indexWhere((c) => c['id'] == item['id']);
    setState(() {
      if (existingIndex >= 0) {
        _cart[existingIndex]['quantity'] += 1;
      } else {
        _cart.add({
          ...item,
          'quantity': 1,
        });
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

  bool get _hasRxRequiredItems => _cart.any((item) => item['isRxRequired'] == true);

  double get _subtotal => _cart.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));

  void _checkout() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty!')));
      return;
    }

    if (_hasRxRequiredItems && (_patientController.text.trim().isEmpty || _rxNumberController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription medications in cart require Patient Name and Rx Number.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Dispense Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Paid: ${currencyFormat.format(_subtotal)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Payment Method: $_paymentMethod'),
            if (_hasRxRequiredItems) ...[
              const Divider(),
              Text('Patient: ${_patientController.text}'),
              Text('Doctor: ${_doctorController.text.isEmpty ? "N/A" : _doctorController.text}'),
              Text('Rx Number: ${_rxNumberController.text}'),
            ],
            const Divider(),
            const Text('Receipt printed & inventory batch updated.'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _cart.clear();
                _patientController.clear();
                _doctorController.clear();
                _rxNumberController.clear();
              });
            },
            child: const Text('OK / NEW SALE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filteredMeds = _medications.where((m) {
      final q = _searchController.text.toLowerCase();
      return m['name'].toString().toLowerCase().contains(q) || m['category'].toString().toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy POS & Dispensing'),
        backgroundColor: const Color(0xFF2E7D32),
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
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search medication or category...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 2.2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: filteredMeds.length,
                      itemBuilder: (context, index) {
                        final item = filteredMeds[index];
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
                                      Expanded(
                                        child: Text(
                                          item['name'],
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (item['isRxRequired'])
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('Rx', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${item['category']} • Batch: ${item['batchNo']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(currencyFormat.format(item['price']), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                                      Text('Stock: ${item['stock']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
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
                  const Text('Dispensing Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: AppSpacing.s),
                  Expanded(
                    child: _cart.isEmpty
                        ? const Center(child: Text('Cart is empty. Select medications to add.'))
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
                                    Text('${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  if (_hasRxRequiredItems) ...[
                    const Divider(),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Prescription Verification Required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepOrange)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _patientController,
                            decoration: const InputDecoration(labelText: 'Patient Name *', isDense: true),
                          ),
                          TextField(
                            controller: _doctorController,
                            decoration: const InputDecoration(labelText: 'Doctor Name', isDense: true),
                          ),
                          TextField(
                            controller: _rxNumberController,
                            decoration: const InputDecoration(labelText: 'Rx Serial Number *', isDense: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(currencyFormat.format(_subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF2E7D32))),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.m),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment Mode', isDense: true),
                    items: ['Cash', 'MoMo', 'Card'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) => setState(() => _paymentMethod = v!),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _checkout,
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('DISPENSE & PRINT RECEIPT', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
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
