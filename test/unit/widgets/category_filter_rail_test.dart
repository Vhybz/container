import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container_business_manager/widgets/category_filter_rail.dart';

void main() {
  group('CategoryFilterRail Widget Unit Tests', () {
    testWidgets('Renders all categories with their respective count badges', (tester) async {
      final categories = ['All', 'Antibiotics', 'Antimalarials', 'Analgesics'];
      final categoryCounts = {
        'All': 45,
        'Antibiotics': 15,
        'Antimalarials': 10,
        'Analgesics': 20,
      };

      String selectedCat = 'All';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryFilterRail(
              categories: categories,
              selectedCategory: selectedCat,
              categoryCounts: categoryCounts,
              onSelectCategory: (cat) => selectedCat = cat,
            ),
          ),
        ),
      );

      // Verify category labels exist (upper-cased)
      expect(find.text('ALL'), findsOneWidget);
      expect(find.text('ANTIBIOTICS'), findsOneWidget);
      expect(find.text('ANTIMALARIALS'), findsOneWidget);
      expect(find.text('ANALGESICS'), findsOneWidget);

      // Verify count badges are rendered
      expect(find.text('45'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
    });

    testWidgets('Tapping a category triggers onSelectCategory callback', (tester) async {
      final categories = ['All', 'Antibiotics', 'Tech'];
      String selectedCat = 'All';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CategoryFilterRail(
                  categories: categories,
                  selectedCategory: selectedCat,
                  onSelectCategory: (cat) {
                    setState(() {
                      selectedCat = cat;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap on Antibiotics
      await tester.tap(find.text('ANTIBIOTICS'));
      await tester.pumpAndSettle();

      expect(selectedCat, equals('Antibiotics'));

      // Tap on Tech
      await tester.tap(find.text('TECH'));
      await tester.pumpAndSettle();

      expect(selectedCat, equals('Tech'));
    });

    testWidgets('Displays appropriate sector icons for categories', (tester) async {
      final categories = ['All', 'Antibiotics', 'Phone Accessories', 'Barber Cuts'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryFilterRail(
              categories: categories,
              selectedCategory: 'All',
              onSelectCategory: (_) {},
            ),
          ),
        ),
      );

      // Grid view icon for All
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);

      // Medication icon for Antibiotics
      expect(find.byIcon(Icons.medication_outlined), findsOneWidget);

      // Smartphone icon for Phone Accessories
      expect(find.byIcon(Icons.smartphone_outlined), findsOneWidget);

      // Scissors icon for Barber Cuts
      expect(find.byIcon(Icons.content_cut_outlined), findsOneWidget);
    });
  });
}
