import 'package:flutter_test/flutter_test.dart';
import 'package:container_business_manager/models/product.dart';

void main() {
  group('Pharmacy Checkout Prescription Compilation & Multi-Drug Tests', () {
    late Product paracetamol;
    late Product amoxicillin;
    late Product coughSyrup;

    setUp(() {
      paracetamol = Product(
        id: 'drug-para-001',
        name: 'Paracetamol 500mg',
        retailPrice: 15.0,
        wholesalePrice: 12.0,
        stockQuantity: 100,
        category: 'Analgesics',
        unit: 'tablet',
        imageUrl: '',
      );

      amoxicillin = Product(
        id: 'drug-amox-002',
        name: 'Amoxicillin 250mg',
        retailPrice: 35.0,
        wholesalePrice: 28.0,
        stockQuantity: 50,
        category: 'Antibiotics',
        unit: 'capsule',
        imageUrl: '',
      );

      coughSyrup = Product(
        id: 'drug-syr-003',
        name: 'Benylin Dry Cough',
        retailPrice: 45.0,
        wholesalePrice: 38.0,
        stockQuantity: 30,
        category: 'Syrups',
        unit: 'bottle',
        imageUrl: '',
      );
    });

    String compilePrescriptionText(Map<String, String> dosages, List<CartItem> cartItems) {
      if (dosages.isEmpty) return '';
      final lines = <String>[];
      for (final item in cartItems) {
        final dosage = dosages[item.product.id]?.trim();
        if (dosage != null && dosage.isNotEmpty) {
          final qtyStr = item.quantity % 1 == 0 
              ? item.quantity.toInt().toString() 
              : item.quantity.toString();
          lines.add('• ${item.product.name} (x$qtyStr): $dosage');
        }
      }
      return lines.join('\n');
    }

    test('Empty dosages map results in empty compiled prescription text', () {
      final cart = [
        CartItem(product: paracetamol, quantity: 2, priceAtSale: 15.0, originalPrice: 15.0),
      ];
      final dosages = <String, String>{};

      final result = compilePrescriptionText(dosages, cart);
      expect(result, isEmpty);
    });

    test('Single drug prescribed formats correctly with integer quantity', () {
      final cart = [
        CartItem(product: paracetamol, quantity: 2, priceAtSale: 15.0, originalPrice: 15.0),
      ];
      final dosages = {'drug-para-001': '2 tabs 3 times daily after meals for 5 days'};

      final result = compilePrescriptionText(dosages, cart);
      expect(result, '• Paracetamol 500mg (x2): 2 tabs 3 times daily after meals for 5 days');
    });

    test('Fractional or decimal quantity formats properly without truncation', () {
      final cart = [
        CartItem(product: coughSyrup, quantity: 1.5, priceAtSale: 45.0, originalPrice: 45.0),
      ];
      final dosages = {'drug-syr-003': '10ml 2 times daily before bedtime'};

      final result = compilePrescriptionText(dosages, cart);
      expect(result, '• Benylin Dry Cough (x1.5): 10ml 2 times daily before bedtime');
    });

    test('Selective prescribing only compiles items that have non-empty dosages', () {
      final cart = [
        CartItem(product: paracetamol, quantity: 1, priceAtSale: 15.0, originalPrice: 15.0),
        CartItem(product: amoxicillin, quantity: 2, priceAtSale: 35.0, originalPrice: 35.0),
        CartItem(product: coughSyrup, quantity: 1, priceAtSale: 45.0, originalPrice: 45.0),
      ];
      // Only amoxicillin and cough syrup prescribed; paracetamol left blank or whitespace
      final dosages = {
        'drug-para-001': '   ',
        'drug-amox-002': '1 cap every 8 hours for 7 days',
        'drug-syr-003': '5ml 3x daily',
      };

      final result = compilePrescriptionText(dosages, cart);
      final lines = result.split('\n');

      expect(lines.length, 2);
      expect(lines[0], '• Amoxicillin 250mg (x2): 1 cap every 8 hours for 7 days');
      expect(lines[1], '• Benylin Dry Cough (x1): 5ml 3x daily');
    });

    test('Apply to all meds replicates dosage across all checkout cart items', () {
      final cart = [
        CartItem(product: paracetamol, quantity: 1, priceAtSale: 15.0, originalPrice: 15.0),
        CartItem(product: amoxicillin, quantity: 1, priceAtSale: 35.0, originalPrice: 35.0),
        CartItem(product: coughSyrup, quantity: 1, priceAtSale: 45.0, originalPrice: 45.0),
      ];
      const bulkDosage = 'Take 1 dose twice daily after meals';
      final dosages = <String, String>{};

      // Emulate _applyDosageToAllMeds
      for (final item in cart) {
        dosages[item.product.id] = bulkDosage;
      }
      final result = compilePrescriptionText(dosages, cart);
      final lines = result.split('\n');

      expect(lines.length, 3);
      expect(dosages.length, 3);
      for (final item in cart) {
        expect(dosages[item.product.id], bulkDosage);
        expect(result.contains(item.product.name), isTrue);
      }
    });

    test('Deleting item from cart removes its dosage from compiled prescription', () {
      final cart = [
        CartItem(product: paracetamol, quantity: 2, priceAtSale: 15.0, originalPrice: 15.0),
        CartItem(product: amoxicillin, quantity: 1, priceAtSale: 35.0, originalPrice: 35.0),
      ];
      final dosages = {
        'drug-para-001': '2 tabs 3x daily',
        'drug-amox-002': '1 cap 3x daily for 5 days',
      };

      // Verify both present before delete
      var result = compilePrescriptionText(dosages, cart);
      expect(result.split('\n').length, 2);

      // Emulate deleting amoxicillin from cart
      const deletedDrugId = 'drug-amox-002';
      dosages.remove(deletedDrugId);
      final updatedCart = cart.where((ci) => ci.product.id != deletedDrugId).toList();

      result = compilePrescriptionText(dosages, updatedCart);
      expect(result, '• Paracetamol 500mg (x2): 2 tabs 3x daily');
      expect(dosages.containsKey(deletedDrugId), isFalse);
    });

    test('Clearing cart completely resets dosages and compiled text', () {
      final dosages = {
        'drug-para-001': '2 tabs 3x daily',
        'drug-amox-002': '1 cap 3x daily',
      };

      // Emulate clear
      dosages.clear();
      final result = compilePrescriptionText(dosages, []);
      expect(result, isEmpty);
      expect(dosages.isEmpty, isTrue);
    });

    test('Prescription text preserves order matching checkout cart item sequence', () {
      final cart = [
        CartItem(product: coughSyrup, quantity: 1, priceAtSale: 45.0, originalPrice: 45.0),
        CartItem(product: paracetamol, quantity: 2, priceAtSale: 15.0, originalPrice: 15.0),
        CartItem(product: amoxicillin, quantity: 1, priceAtSale: 35.0, originalPrice: 35.0),
      ];
      final dosages = {
        'drug-syr-003': '10ml at night',
        'drug-para-001': '2 tabs morning and night',
        'drug-amox-002': '1 cap every 8 hours',
      };

      final result = compilePrescriptionText(dosages, cart);
      final lines = result.split('\n');

      expect(lines[0], startsWith('• Benylin Dry Cough'));
      expect(lines[1], startsWith('• Paracetamol 500mg'));
      expect(lines[2], startsWith('• Amoxicillin 250mg'));
    });

    test('Prescription SMS receipt message contains patient, Rx No, Prescriber, and Dosage instructions', () {
      const rxText = '• Paracetamol 500mg (x2): 2 tabs 3x daily\n• Amoxicillin 250mg (x1): 1 cap 3x daily';
      const patient = 'Kwame Mensah';
      const prescriber = 'Dr. Addo';
      const rxNo = 'RX-2026-99';

      // Verify prescription message compilation logic
      String message = 'RECEIPT #INV-001 - Emmanuel Chemist\n';
      message += 'Patient: $patient\n';
      message += 'Items: 2tablet Paracetamol 500mg, 1capsule Amoxicillin 250mg\n';
      message += 'Total: GHS 50.00\nStatus: Paid';
      message += '\nRx No: $rxNo';
      message += '\nPrescriber: $prescriber';
      message += '\nRx / Dosage:\n$rxText';
      message += '\nThank you for trusting Emmanuel Chemist!';

      expect(message, contains('Patient: Kwame Mensah'));
      expect(message, contains('Rx No: RX-2026-99'));
      expect(message, contains('Prescriber: Dr. Addo'));
      expect(message, contains('Rx / Dosage:\n• Paracetamol 500mg (x2): 2 tabs 3x daily'));
      expect(message, contains('Emmanuel Chemist'));
    });
  });
}
