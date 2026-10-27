import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/user_provider.dart';
import '../services/barber_management_provider.dart';
import '../services/barber_records_provider.dart';
import '../services/barber_queue_provider.dart';
import '../core/constants.dart';

class BarberManagementDialog extends ConsumerStatefulWidget {
  const BarberManagementDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const BarberManagementDialog(),
    );
  }

  @override
  ConsumerState<BarberManagementDialog> createState() => _BarberManagementDialogState();
}

class _BarberManagementDialogState extends ConsumerState<BarberManagementDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddBarberModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.content_cut, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Register New Barber'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Barber Full Name *',
                  hintText: 'e.g. Samuel Kojo',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  hintText: 'e.g. 0241234567',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
            icon: const Icon(Icons.check),
            label: const Text('Add Barber'),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              
              // 1. Create account in userProvider
              final newAccount = UserAccount(
                id: 'barber_${DateTime.now().millisecondsSinceEpoch}',
                email: '${name.toLowerCase().replaceAll(' ', '_')}@barber.local',
                firstName: name.split(' ').first,
                surname: name.split(' ').length > 1 ? name.split(' ').sublist(1).join(' ') : 'Stylist',
                phone: phoneCtrl.text.trim(),
                role: UserRole.barber,
                status: AccountStatus.approved,
              );

              try {
                await ref.read(userProvider.notifier).addAccount(newAccount);
              } catch (_) {}

              // 2. Add to barberManagementProvider
              await ref.read(barberManagementProvider.notifier).addCustomBarber(
                name,
                phone: phoneCtrl.text.trim(),
                userId: newAccount.id,
              );

              messenger.showSnackBar(
                SnackBar(content: Text('Barber "$name" registered successfully!')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showEditBarberModal(BuildContext context, String currentName, String? userId, String? currentPhone) {
    final nameCtrl = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: AppColors.primaryMaroon),
            SizedBox(width: 8),
            Text('Edit Barber Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Barber Full Name *',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMaroon, foregroundColor: Colors.white),
            icon: const Icon(Icons.save),
            label: const Text('Save Changes'),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;

              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);

              await ref.read(barberManagementProvider.notifier).editBarber(
                currentName,
                newName,
                newPhone: phoneCtrl.text.trim(),
                userId: userId,
              );

              messenger.showSnackBar(
                SnackBar(content: Text('Updated barber name to "$newName"')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBarber(BuildContext context, String barberName, String? userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Barber'),
          ],
        ),
        content: Text('Are you sure you want to delete barber "$barberName"? This will remove them from active selection lists.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              await ref.read(barberManagementProvider.notifier).deleteBarber(barberName, userId: userId);
              messenger.showSnackBar(
                SnackBar(content: Text('Barber "$barberName" removed.')),
              );
            },
            child: const Text('Delete Barber'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staffUsers = ref.watch(userProvider);
    final records = ref.watch(barberRecordsProvider);
    final queue = ref.watch(barberQueueProvider);
    final barberState = ref.watch(barberManagementProvider);

    // Compiled active barbers
    final activeBarbers = ref.read(barberManagementProvider.notifier).getCompiledBarbers(
      staff: staffUsers,
      records: records,
      queue: queue,
    );

    // Unknown / Legacy barbers
    final unknownBarbers = ref.read(barberManagementProvider.notifier).getUnknownBarbers(
      staff: staffUsers,
      records: records,
      queue: queue,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 550,
        height: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.content_cut_rounded, color: Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Barber Management', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const Text('Edit created barbers or clear unknown/legacy barber entries', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFD97706),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFD97706),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.badge_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('Active Barbers (${activeBarbers.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_off_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('Unknown (${unknownBarbers.length})'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Active Barbers
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Registered & Created Barbers', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Barber', style: TextStyle(fontSize: 12)),
                            onPressed: () => _showAddBarberModal(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: activeBarbers.isEmpty
                            ? const Center(child: Text('No active barbers registered yet.'))
                            : ListView.builder(
                                itemCount: activeBarbers.length,
                                itemBuilder: (ctx, index) {
                                  final name = activeBarbers[index];
                                  final matchedUser = staffUsers.where((u) => u.name.trim().toLowerCase() == name.toLowerCase()).firstOrNull;
                                  final customMatch = barberState.customBarbers.where((b) => b.name.trim().toLowerCase() == name.toLowerCase()).firstOrNull;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFFD97706).withValues(alpha: 0.15),
                                        child: Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : 'B',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                        ),
                                      ),
                                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(
                                        matchedUser != null
                                            ? 'Role: ${matchedUser.role.display} • ${matchedUser.phone ?? "No phone"}'
                                            : (customMatch?.phone.isNotEmpty == true ? 'Phone: ${customMatch!.phone}' : 'Created Barber'),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                            tooltip: 'Edit Barber Name',
                                            onPressed: () => _showEditBarberModal(
                                              context,
                                              name,
                                              matchedUser?.id ?? customMatch?.userId,
                                              matchedUser?.phone ?? customMatch?.phone,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                            tooltip: 'Delete Barber',
                                            onPressed: () => _confirmDeleteBarber(
                                              context,
                                              name,
                                              matchedUser?.id ?? customMatch?.userId,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),

                  // Tab 2: Unknown / Legacy Barbers
                  Column(
                    children: [
                      if (unknownBarbers.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text('Unknown barber names found in records or default fallbacks:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                icon: const Icon(Icons.clear_all, size: 16),
                                label: const Text('Clear All Unknowns', style: TextStyle(fontSize: 11)),
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  await ref.read(barberManagementProvider.notifier).clearAllUnknownBarbers(unknownBarbers);
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('All unknown barber names cleared.')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: unknownBarbers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline, color: Colors.green.shade400, size: 48),
                                    const SizedBox(height: 8),
                                    const Text('No unknown barbers found!', style: TextStyle(fontWeight: FontWeight.bold)),
                                    const Text('Your barber selection lists are completely clean.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: unknownBarbers.length,
                                itemBuilder: (ctx, index) {
                                  final unknownName = unknownBarbers[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.orange.shade100,
                                        child: const Icon(Icons.help_outline, color: Colors.orange),
                                      ),
                                      title: Text(unknownName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: const Text('Legacy record / Unknown barber entry', style: TextStyle(fontSize: 11)),
                                      trailing: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade50,
                                          foregroundColor: Colors.red,
                                          elevation: 0,
                                          side: const BorderSide(color: Colors.red),
                                        ),
                                        icon: const Icon(Icons.remove_circle_outline, size: 16),
                                        label: const Text('Clear Barber', style: TextStyle(fontSize: 11)),
                                        onPressed: () async {
                                          final messenger = ScaffoldMessenger.of(context);
                                          await ref.read(barberManagementProvider.notifier).clearUnknownBarber(unknownName);
                                          messenger.showSnackBar(
                                            SnackBar(content: Text('Cleared unknown barber "$unknownName"')),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
