import 'package:flutter/material.dart';
import '../../core/constants.dart';

class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: AppSpacing.xl),
          _buildWorkflowStep(
            context,
            '1',
            'Animal Intake',
            'Start by recording the arrival of a new animal. Use the "New Intake" button on the dashboard.',
            [
              'Select the correct Animal Type to enable smart yield predictions.',
              'The system will auto-generate a unique Smart ID.',
              'Enter the Live Weight (kg) as measured on the digital scale.',
              'Verify the Source/Farm details for traceability.',
            ],
            Icons.pets_rounded,
          ),
          _buildDivider(),
          _buildWorkflowStep(
            context,
            '2',
            'Slaughter & Logging',
            'Monitor and update the status of animals as they move to slaughter.',
            [
              'Check the Slaughter Log to see pending animals.',
              'Update status from "Pending" to "Processing" when starting.',
              'The system calculates "Estimated Yield" - use this as a benchmark for your actual output.',
              'Mark as "Completed" once the carcass is ready for primary cuts.',
            ],
            Icons.precision_manufacturing_rounded,
          ),
          _buildDivider(),
          _buildWorkflowStep(
            context,
            '3',
            'Meat Processing & Batching',
            'Divide carcasses into primary and secondary cuts for inventory.',
            [
              'Go to "Meat Processing" to record specific cuts (e.g., Ribeye, Brisket).',
              'Create "Meat Batches" for group tracking.',
              'The system will compare your actual batch weights against the initial predictions to track efficiency.',
            ],
            Icons.restaurant_rounded,
          ),
          _buildDivider(),
          _buildWorkflowStep(
            context,
            '4',
            'Waste Management',
            'Accurately record bones, fat trim, and other non-saleable items.',
            [
              'Use "Waste Management" to log weight of bones and trim.',
              'High waste levels trigger a yield efficiency alert on the dashboard.',
              'Recording waste is critical for accurate inventory balancing.',
            ],
            Icons.delete_sweep_rounded,
          ),
          _buildDivider(),
          _buildWorkflowStep(
            context,
            '5',
            'Stock Transfer',
            'Finalize the process by transferring ready meat to the retail/cashier unit.',
            [
              'Select completed batches in "Stock Transfer".',
              'Generate and print batch labels for physical identification.',
              'Confirm transfer to move items out of Butcher Inventory and into Retail Sales.',
            ],
            Icons.local_shipping_rounded,
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildProTips(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Butcher Operations Workflow',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryMaroon),
        ),
        SizedBox(height: AppSpacing.s),
        Text(
          'Follow these steps to ensure accurate inventory and yield tracking.',
          style: TextStyle(color: AppColors.textLight, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildWorkflowStep(
    BuildContext context,
    String stepNumber,
    String title,
    String description,
    List<String> points,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primaryMaroon,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.primaryMaroon, size: 24),
                    const SizedBox(width: AppSpacing.s),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  description,
                  style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textDark),
                ),
                const SizedBox(height: AppSpacing.m),
                ...points.map((point) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(Icons.circle, size: 6, color: AppColors.primaryMaroon),
                          ),
                          const SizedBox(width: AppSpacing.m),
                          Expanded(child: Text(point)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Divider(color: AppColors.borderGray.withValues(alpha: 0.5), height: 40),
    );
  }

  Widget _buildProTips() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue),
              SizedBox(width: AppSpacing.s),
              Text('Pro Operating Tips', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
            ],
          ),
          SizedBox(height: AppSpacing.m),
          Text('• Keep the digital scale calibrated daily for accurate "Live Weight" entry.'),
          Text('• Use the "Smart Insights" on the dashboard to spot yield drops early.'),
          Text('• Always print labels immediately after batching to prevent cross-contamination or misidentification.'),
        ],
      ),
    );
  }
}
