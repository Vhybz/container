import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../services/barber_queue_provider.dart';
import '../../services/repair_ticket_provider.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  final String? initialTicketId;

  const LiveTrackingScreen({super.key, this.initialTicketId});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  late final TextEditingController _searchController;
  String _activeTicketId = '';

  @override
  void initState() {
    super.initState();
    _activeTicketId = widget.initialTicketId?.trim().toUpperCase() ?? '';
    _searchController = TextEditingController(text: _activeTicketId);
  }

  @override
  void didUpdateWidget(covariant LiveTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTicketId != oldWidget.initialTicketId && widget.initialTicketId != null) {
      setState(() {
        _activeTicketId = widget.initialTicketId!.trim().toUpperCase();
        _searchController.text = _activeTicketId;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchTicket() {
    final query = _searchController.text.trim().toUpperCase();
    if (query.isEmpty) return;
    setState(() {
      _activeTicketId = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queueList = ref.watch(barberQueueProvider);
    final repairList = ref.watch(repairTicketProvider);

    // Look for matching ticket
    final queueItem = queueList.where((q) => q.id.toUpperCase() == _activeTicketId).firstOrNull;
    final repairItem = repairList.where((r) => r.id.toUpperCase() == _activeTicketId).firstOrNull;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Live Status Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Search Bar
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Color(0xFF1565C0)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'Enter Ticket # (e.g., Q-104 or REP-102)',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (_) => _searchTicket(),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _searchTicket,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Track'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.l),

                // Content View
                if (_activeTicketId.isEmpty)
                  _buildEmptyPrompt(theme)
                else if (queueItem != null)
                  _buildQueueTracker(context, queueItem, queueList)
                else if (repairItem != null)
                  _buildRepairTracker(context, repairItem)
                else
                  _buildNotFoundCard(theme, _activeTicketId),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPrompt(ThemeData theme) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: AppSpacing.m),
            const Text(
              'Real-Time Service & Queue Tracking',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your ticket number from your SMS or receipt above to check your live queue position or repair order status.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundCard(ThemeData theme, String ticketId) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const Icon(Icons.search_off, size: 56, color: Colors.orange),
            const SizedBox(height: AppSpacing.m),
            Text(
              'Ticket "$ticketId" Not Found',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Please verify the ticket ID on your SMS or receipt. Active tickets begin with "Q-" for Barbershop queues or "REP-" for Device repairs.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueTracker(BuildContext context, BarberQueueItem item, List<BarberQueueItem> fullQueue) {
    final theme = Theme.of(context);
    final waitingList = fullQueue.where((q) => q.status == 'Waiting').toList();
    
    // Sort waiting by timestamp
    waitingList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final positionInLine = waitingList.indexWhere((q) => q.id == item.id);
    final peopleAhead = positionInLine >= 0 ? positionInLine : 0;
    final estimatedMinutes = (peopleAhead * 25);

    final isWaiting = item.status == 'Waiting';
    final isInService = item.status == 'In Service';
    final isCompleted = item.status == 'Completed';

    Color statusColor = Colors.orange;
    String statusTitle = 'Waiting in Line';
    String statusDescription = peopleAhead == 0
        ? 'You are next! Please be ready for your stylist.'
        : '$peopleAhead client(s) ahead of you (~$estimatedMinutes mins wait).';

    if (isInService) {
      statusColor = Colors.blue;
      statusTitle = 'Currently In Service';
      statusDescription = 'Your cut/grooming is currently in progress with ${item.barber}.';
    } else if (isCompleted) {
      statusColor = Colors.green;
      statusTitle = 'Cut Completed!';
      statusDescription = 'Thank you for choosing Container Barbershop. Hope you love your new look!';
    }

    return Column(
      children: [
        // Status Hero Banner
        Card(
          elevation: 3,
          color: statusColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Icon(
                    isCompleted ? Icons.check_circle : (isInService ? Icons.content_cut : Icons.hourglass_top),
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusDescription,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),

        // Live Queue Metrics
        if (isWaiting)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Queue Position', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '#${positionInLine + 1}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: theme.dividerColor),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Est. Wait Time', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '~$estimatedMinutes min',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.m),

        // Ticket Details
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Appointment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Divider(),
                _buildInfoRow('Ticket ID', item.id),
                _buildInfoRow('Client Name', item.customer),
                _buildInfoRow('Service', item.service),
                _buildInfoRow('Assigned Barber', item.barber),
                _buildInfoRow('Check-in Time', DateFormat('hh:mm a • dd MMM yyyy').format(item.timestamp)),
                if (item.price != null)
                  _buildInfoRow('Estimated Fee', 'GHS ${item.price!.toStringAsFixed(2)}'),
                if (item.saleId != null)
                  _buildInfoRow('Receipt / Sale ID', item.saleId!),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRepairTracker(BuildContext context, RepairTicket ticket) {
    final stages = ['Received', 'Diagnosed', 'In Progress', 'Ready for Pickup', 'Delivered'];
    
    // Normalize status into stages
    int currentStageIndex = 0;
    final s = ticket.status.toLowerCase();
    if (s.contains('deliver')) {
      currentStageIndex = 4;
    } else if (s.contains('ready') || s.contains('pickup')) {
      currentStageIndex = 3;
    } else if (s.contains('progress')) {
      currentStageIndex = 2;
    } else if (s.contains('diagnos')) {
      currentStageIndex = 1;
    } else {
      currentStageIndex = 0;
    }

    final balanceDue = ticket.cost - ticket.deposit;

    return Column(
      children: [
        // Hero Header
        Card(
          elevation: 3,
          color: const Color(0xFF00695C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.build_circle, color: Colors.white, size: 32),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.device,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Work Order #${ticket.id} • ${ticket.status}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),

        // 5-Stage Progress Stepper
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Repair Progress Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: AppSpacing.m),
                ...List.generate(stages.length, (idx) {
                  final isPassed = idx <= currentStageIndex;
                  final isCurrent = idx == currentStageIndex;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: isPassed ? Colors.teal : Colors.grey.shade300,
                            child: Icon(
                              isPassed ? Icons.check : Icons.circle,
                              size: 14,
                              color: isPassed ? Colors.white : Colors.grey.shade600,
                            ),
                          ),
                          if (idx < stages.length - 1)
                            Container(
                              width: 2,
                              height: 28,
                              color: idx < currentStageIndex ? Colors.teal : Colors.grey.shade300,
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            stages[idx],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent ? FontWeight.bold : (isPassed ? FontWeight.w600 : FontWeight.normal),
                              color: isCurrent ? Colors.teal.shade800 : (isPassed ? Colors.black87 : Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),

        // Financial & Device Details
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Repair Order Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Divider(),
                _buildInfoRow('Customer', ticket.customer),
                _buildInfoRow('Reported Issue', ticket.issue),
                _buildInfoRow('Lead Technician', ticket.technician),
                _buildInfoRow('Date Logged', DateFormat('dd MMM yyyy • hh:mm a').format(ticket.timestamp)),
                _buildInfoRow('Total Estimated Cost', 'GHS ${ticket.cost.toStringAsFixed(2)}'),
                _buildInfoRow('Deposit Paid', 'GHS ${ticket.deposit.toStringAsFixed(2)}'),
                _buildInfoRow(
                  'Remaining Balance',
                  balanceDue <= 0 ? 'PAID IN FULL' : 'GHS ${balanceDue.toStringAsFixed(2)}',
                  color: balanceDue <= 0 ? Colors.green : Colors.red,
                  isBold: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
