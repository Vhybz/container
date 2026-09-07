import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../services/butcher_service.dart';
import '../../widgets/responsive_layout.dart';

class WasteManagementScreen extends ConsumerWidget {
  const WasteManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wasteAsync = ref.watch(butcherWasteProvider);
    final isMobile = ResponsiveLayout.isMobile(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flex(
            direction: isMobile ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Waste & By-Product Control', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text('Recording and monitoring slaughterhouse disposal', style: TextStyle(color: AppColors.textLight)),
                ],
              ),
              if (isMobile) const SizedBox(height: AppSpacing.m),
              ElevatedButton.icon(
                onPressed: () => _showRecordWasteDialog(context, ref),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Record Waste'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMaroon, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          _buildWasteDashboard(context, wasteAsync),
          const SizedBox(height: AppSpacing.l),
          _buildRecentDisposals(wasteAsync),
        ],
      ),
    );
  }

  Widget _buildWasteDashboard(BuildContext context, AsyncValue<List<Map<String, dynamic>>> wasteAsync) {
    return wasteAsync.when(
      data: (waste) {
        final totalWeight = waste.fold(0.0, (sum, w) => sum + (w['weight'] as num).toDouble());
        final isMobile = MediaQuery.of(context).size.width < 600;

        return GridView.count(
          crossAxisCount: isMobile ? 2 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.m,
          mainAxisSpacing: AppSpacing.m,
          childAspectRatio: isMobile ? 1.4 : 2.0,
          children: [
            _wasteStatCard('Total Waste', '${totalWeight.toStringAsFixed(1)} kg', 'All-time Disposal', Colors.red),
            _wasteStatCard('Last Entry', waste.isEmpty ? 'N/A' : '${(waste.first['weight'] as num).toDouble()} kg', 'Most Recent', Colors.green),
            _wasteStatCard('Records', '${waste.length}', 'Disposal Logs', Colors.blue),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, error) => const Text('Error loading stats'),
    );
  }

  Widget _wasteStatCard(String title, String value, String subtitle, Color color) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.bold)),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentDisposals(AsyncValue<List<Map<String, dynamic>>> wasteAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Disposal Records', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            wasteAsync.when(
              data: (waste) {
                if (waste.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No waste records found.')));
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: waste.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final w = waste[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      ),
                      title: Text('${w['reason']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Batch: ${w['batch_id'] ?? "Manual"} • ${DateFormat('MMM dd').format(DateTime.parse(w['recorded_at']))}', style: const TextStyle(fontSize: 10)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${(w['weight'] as num).toDouble()} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                          const Text('Disposed', style: TextStyle(fontSize: 9, color: AppColors.textLight)),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordWasteDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final reasonController = TextEditingController();
    final weightController = TextEditingController();
    String? selectedBatchId;
    
    final batchesAsync = ref.read(meatBatchesProvider);
    final activeBatches = batchesAsync.value ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        title: const Text('Record Waste'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: reasonController,
                    decoration: const InputDecoration(labelText: 'Reason (e.g. Bone trimmings)', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: weightController,
                    decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid weight';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Select Batch (Optional)', border: OutlineInputBorder()),
                    items: activeBatches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.id, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => selectedBatchId = v,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await ref.read(butcherWasteProvider.notifier).addWaste(
                  selectedBatchId ?? 'MANUAL', 
                  reasonController.text, 
                  double.tryParse(weightController.text) ?? 0
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMaroon, foregroundColor: Colors.white),
            child: const Text('Save Record'),
          ),
        ],
      ),
    );
  }
}
