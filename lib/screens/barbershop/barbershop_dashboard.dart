import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../models/product.dart';
import '../../models/sale_model.dart';
import '../../models/user_model.dart';
import '../../services/product_service.dart';
import '../../services/sale_provider.dart';
import '../../services/user_provider.dart';
import '../../services/barber_queue_provider.dart';
import '../../services/barber_appointment_provider.dart';
import '../../services/customer_provider.dart';
import '../../services/sms_service.dart';
import '../../models/barbershop_models.dart';
import '../../models/customer_model.dart';
import '../../services/barber_records_provider.dart';
import '../../services/receipt_service.dart';
import '../../services/menu_service.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/role_pop_scope.dart';
import '../../widgets/barber_settlement_dialog.dart';

class BarbershopDashboard extends ConsumerStatefulWidget {
  const BarbershopDashboard({super.key});

  @override
  ConsumerState<BarbershopDashboard> createState() => _BarbershopDashboardState();
}

class _BarbershopDashboardState extends ConsumerState<BarbershopDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
  String _appointmentFilter = 'All';
  final TextEditingController _recordsSearchController = TextEditingController();
  String _recordBarberFilter = 'All';
  String _recordServiceFilter = 'All';
  String _recordDateFilter = 'All Time';
  DateTimeRange? _recordCustomRange;
  String _recordPaymentFilter = 'All';
  String _commissionDateFilter = 'This Month';
  DateTimeRange? _commissionCustomRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _recordsSearchController.dispose();
    super.dispose();
  }

  void _showAddQueueDialog(BuildContext context, List<Product> services, List<UserAccount> staff) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final haircutServices = services.where((s) {
      final cat = s.category.toUpperCase();
      final name = s.name.toUpperCase();
      return (cat.contains('BARBER') || cat.contains('HAIR') || cat.contains('BEARD') || cat.contains('GROOM')) &&
          !cat.contains('REPAIR') && !name.contains('IPHONE') && !name.contains('BATTERY') && !name.contains('CHARGING') && !name.contains('FLASHING');
    }).toList();

    final List<String> serviceNames = haircutServices.isNotEmpty 
        ? haircutServices.map((s) => s.name).toList() 
        : ['Executive Haircut', 'Kids Haircut', 'Beard Grooming & Oil', 'Hair Dye / Blackening', 'Facial Scrub & Steam'];

    final barberStaff = staff.where((u) => u.role == UserRole.secretary || u.role == UserRole.admin).toList();
    final List<String> barberNames = barberStaff.isNotEmpty 
        ? barberStaff.map((u) => '${u.firstName} ${u.surname}').toList() 
        : ['King Mojo'];

    String? selectedService = serviceNames.first;
    String? selectedBarber = barberNames.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add_outlined, color: Color(0xFF1565C0)),
              SizedBox(width: 8),
              Text('Add Client to Queue'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Client Name', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: AppSpacing.m),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: AppSpacing.m),
                DropdownButtonFormField<String>(
                  initialValue: selectedService,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Requested Hairstyle / Grooming', prefixIcon: Icon(Icons.cut_outlined)),
                  items: serviceNames
                      .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedService = v),
                ),
                const SizedBox(height: AppSpacing.m),
                DropdownButtonFormField<String>(
                  initialValue: selectedBarber,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Assign Stylist / Barber', prefixIcon: Icon(Icons.badge_outlined)),
                  items: barberNames
                      .map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedBarber = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                final chosenService = selectedService ?? 'Executive Haircut';
                final match = haircutServices.where((p) => p.name.toLowerCase() == chosenService.toLowerCase()).firstOrNull;
                final double price = match?.retailPrice ?? BarberQueueNotifier.getDefaultPrice(chosenService);

                ref.read(barberQueueProvider.notifier).addToQueue(
                  customer: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  service: chosenService,
                  barber: selectedBarber ?? 'King Mojo',
                  price: price,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${nameController.text.trim()} added to live queue.')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
              child: const Text('ADD TO QUEUE'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookAppointmentDialog(BuildContext context, List<Product> services, List<UserAccount> staff) {
    final haircutServices = services.where((s) {
      final cat = s.category.toUpperCase();
      final name = s.name.toUpperCase();
      return (cat.contains('BARBER') || cat.contains('HAIR') || cat.contains('BEARD') || cat.contains('GROOM')) &&
          !cat.contains('REPAIR') && !name.contains('IPHONE') && !name.contains('BATTERY') && !name.contains('CHARGING') && !name.contains('FLASHING');
    }).toList();

    final List<String> serviceNames = haircutServices.isNotEmpty 
        ? haircutServices.map((s) => s.name).toList() 
        : ['Executive Haircut', 'Kids Haircut', 'Beard Grooming & Oil', 'Hair Dye / Blackening', 'Facial Scrub & Steam'];

    final barberStaff = staff.where((u) => u.role == UserRole.secretary || u.role == UserRole.admin).toList();
    final List<String> barberNames = barberStaff.isNotEmpty 
        ? barberStaff.map((u) => '${u.firstName} ${u.surname}').toList() 
        : ['King Mojo'];

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();
    final searchCustomerController = TextEditingController();
    final momoNumberController = TextEditingController(text: BarberAppointment.defaultMomoNumber);
    final momoNameController = TextEditingController(text: BarberAppointment.defaultMomoName);

    String? selectedService = serviceNames.first;
    String? selectedBarber = barberNames.first;
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 60)));
    bool isExistingCustomer = true;
    bool saveToDirectory = true;
    Customer? selectedCustomer;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final customers = ref.watch(customerProvider);
          final searchQuery = searchCustomerController.text.trim().toLowerCase();
          final filteredCustomers = searchQuery.isEmpty
              ? customers.take(5).toList()
              : customers.where((c) =>
                  c.name.toLowerCase().contains(searchQuery) ||
                  c.phone.contains(searchQuery)
                ).take(5).toList();

          final chosenService = selectedService ?? serviceNames.first;
          final matchedProduct = haircutServices.where((p) => p.name.toLowerCase() == chosenService.toLowerCase()).firstOrNull;
          final double price = matchedProduct?.retailPrice ?? BarberQueueNotifier.getDefaultPrice(chosenService);

          final scheduledDateTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );

          final bool isToday = selectedDate.year == DateTime.now().year &&
                               selectedDate.month == DateTime.now().month &&
                               selectedDate.day == DateTime.now().day;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A1B9A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_month, color: Color(0xFF6A1B9A), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Book Barbershop Appointment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Secretary & Admin Booking Portal', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode Toggle: Existing Customer vs New Client
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: true,
                          icon: Icon(Icons.how_to_reg_outlined, size: 16),
                          label: Text('Existing Customer', style: TextStyle(fontSize: 12)),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          icon: Icon(Icons.person_add_outlined, size: 16),
                          label: Text('New Client', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                      selected: {isExistingCustomer},
                      onSelectionChanged: (Set<bool> val) {
                        setDialogState(() {
                          isExistingCustomer = val.first;
                          if (!isExistingCustomer) {
                            selectedCustomer = null;
                            nameController.clear();
                            phoneController.clear();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.m),

                    if (isExistingCustomer) ...[
                      // Search and auto-fill customer
                      TextField(
                        controller: searchCustomerController,
                        decoration: InputDecoration(
                          labelText: 'Search Customer by Name or Phone',
                          hintText: 'Type to auto-fill details...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchCustomerController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () => setDialogState(() {
                                    searchCustomerController.clear();
                                    selectedCustomer = null;
                                    nameController.clear();
                                    phoneController.clear();
                                  }),
                                )
                              : null,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 6),
                      if (selectedCustomer == null && filteredCustomers.isNotEmpty) ...[
                        Container(
                          constraints: const BoxConstraints(maxHeight: 140),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredCustomers.length,
                            itemBuilder: (ctx, idx) {
                              final c = filteredCustomers[idx];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.person, size: 18),
                                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(c.phone, style: const TextStyle(fontSize: 11)),
                                trailing: const Text('Select', style: TextStyle(color: Color(0xFF1565C0), fontSize: 11, fontWeight: FontWeight.bold)),
                                onTap: () {
                                  setDialogState(() {
                                    selectedCustomer = c;
                                    nameController.text = c.name;
                                    phoneController.text = c.phone;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (selectedCustomer != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.green.shade400),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Auto-filled: ${selectedCustomer!.name} (${selectedCustomer!.phone})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setDialogState(() {
                                    selectedCustomer = null;
                                    nameController.clear();
                                    phoneController.clear();
                                  });
                                },
                                child: const Text('Change', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                    ],

                    // Client Name & Phone fields (editable in both modes)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Client Full Name *',
                              prefixIcon: Icon(Icons.person_outline),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number (for SMS) *',
                              prefixIcon: Icon(Icons.phone_outlined),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!isExistingCustomer) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Checkbox(
                            value: saveToDirectory,
                            onChanged: (v) => setDialogState(() => saveToDirectory = v ?? true),
                          ),
                          const Expanded(
                            child: Text(
                              'Save new client to Customer Directory',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.m),

                    // Service & Barber selection
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedService,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Requested Service',
                              prefixIcon: Icon(Icons.content_cut),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: serviceNames
                                .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) => setDialogState(() => selectedService = v),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedBarber,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Assign Stylist / Barber',
                              prefixIcon: Icon(Icons.badge_outlined),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: barberNames
                                .map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) => setDialogState(() => selectedBarber = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // Date & Time Picker Section (Allows Days/Weeks in Advance)
                    const Text(
                      'Appointment Date & Time (Advance Booking Supported):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              DateFormat('EEE, d MMM yyyy').format(selectedDate),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                lastDate: DateTime.now().add(const Duration(days: 180)),
                              );
                              if (picked != null) {
                                setDialogState(() => selectedDate = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(
                              selectedTime.format(context),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (picked != null) {
                                setDialogState(() => selectedTime = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Scheduled time preview banner
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A1B9A).withValues(alpha: 0.08),
                        border: Border.all(color: const Color(0xFF8E24AA).withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_alarm, size: 16, color: Color(0xFF8E24AA)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Scheduled for: ${DateFormat('EEE, d MMM yyyy @ h:mm a').format(scheduledDateTime)} (${isToday ? "Today" : "${scheduledDateTime.difference(DateTime.now()).inDays + 1} days away"})',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // Notes
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Special Notes / Customer Preferences (Optional)',
                        prefixIcon: Icon(Icons.notes),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // MoMo Payment & Validation Info Box with explicit account configuration
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.payment_rounded, size: 16, color: Colors.amber.shade900),
                              const SizedBox(width: 6),
                              Text('Client SMS MoMo Payment Instructions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '• 1. Booking SMS will be dispatched immediately to the client with this MoMo number & name to validate within 30 mins.\n• 2. Appointment enters "Pending Payment" status until payment is confirmed.\n• 3. Confirmation SMS is dispatched automatically once payment is validated.',
                            style: TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: TextField(
                                  controller: momoNumberController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    labelText: 'MoMo Number',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.phone_android, size: 16),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: TextField(
                                  controller: momoNameController,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    labelText: 'Account Name',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.person, size: 16),
                                    border: OutlineInputBorder(),
                                  ),
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
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.bookmark_added_rounded, size: 18),
                label: Text('CONFIRM BOOKING (₵${price.toStringAsFixed(2)})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final phone = phoneController.text.trim();

                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter the client name.')),
                          );
                          return;
                        }
                        if (phone.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a phone number to receive confirmation & reminder SMS.')),
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);

                        try {
                          final user = ref.read(currentUserProvider);
                          // If new client and saveToDirectory is true
                          if (!isExistingCustomer && saveToDirectory) {
                            final newCustomer = Customer(
                              id: 'CUST-${DateTime.now().millisecondsSinceEpoch}',
                              branchCode: user?.branchCode ?? 'MAIN',
                              name: name,
                              phone: phone,
                            );
                            ref.read(customerProvider.notifier).addCustomer(newCustomer);
                          }

                          final String momoNum = momoNumberController.text.trim().isNotEmpty
                              ? momoNumberController.text.trim()
                              : BarberAppointment.defaultMomoNumber;
                          final String momoAccountName = momoNameController.text.trim().isNotEmpty
                              ? momoNameController.text.trim()
                              : BarberAppointment.defaultMomoName;

                          await ref.read(barberAppointmentsProvider.notifier).bookAppointment(
                            customerName: name,
                            phone: phone,
                            service: chosenService,
                            barber: selectedBarber ?? 'King Mojo',
                            appointmentTime: scheduledDateTime,
                            price: price,
                            customerId: selectedCustomer?.id,
                            notes: notesController.text.trim(),
                            momoNumber: momoNum,
                            momoName: momoAccountName,
                          );

                          if (ctx.mounted) Navigator.pop(ctx);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF6A1B9A),
                                content: Text(
                                  'Appointment booked for $name (Pending Payment). MoMo payment SMS ($momoNum - $momoAccountName) sent to client.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error booking appointment: $e')),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCompleteCutDialog(BuildContext context, BarberQueueItem item) {
    if (item.status == 'Completed' && item.saleId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cut for ${item.customer} is already completed & recorded in sales (${item.saleId}).')),
      );
      return;
    }

    final priceController = TextEditingController(
      text: (item.price ?? BarberQueueNotifier.getDefaultPrice(item.service)).toStringAsFixed(2),
    );
    String selectedPaymentMethod = 'Cash';
    bool printReceipt = false;
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: !isProcessing,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle_outline, color: Colors.green),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Complete Cut & Record Sale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppRadius.s),
                      border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item.customer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(item.id, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Service: ${item.service}', style: const TextStyle(fontSize: 12)),
                        Text('Stylist / Barber: ${item.barber}', style: const TextStyle(fontSize: 12)),
                        if (item.phone.isNotEmpty)
                          Text('Phone: ${item.phone}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Cut Price / Service Fee (₵)',
                      prefixText: '₵ ',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: ['Cash', 'MoMo', 'Card'].map((method) {
                      final isSelected = selectedPaymentMethod == method;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            onTap: () => setDialogState(() => selectedPaymentMethod = method),
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF1565C0) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade400),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                method,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Print Physical Receipt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    value: printReceipt,
                    onChanged: (val) => setDialogState(() => printReceipt = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: isProcessing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(isProcessing ? 'Recording...' : 'COMPLETE & ADD TO SALES'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: isProcessing
                  ? null
                  : () async {
                      final double? parsedPrice = double.tryParse(priceController.text.trim());
                      if (parsedPrice == null || parsedPrice <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid haircut price.')),
                        );
                        return;
                      }

                      setDialogState(() => isProcessing = true);

                      try {
                        final sale = await ref.read(barberQueueProvider.notifier).completeAndAddToSales(
                          item.id,
                          customPrice: parsedPrice,
                          paymentMethod: selectedPaymentMethod,
                          printReceipt: printReceipt,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.green.shade800,
                              content: Text('Haircut marked complete! Added ₵${parsedPrice.toStringAsFixed(2)} to sales for ${item.customer} (${sale?.id ?? 'Sale Recorded'}).'),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isProcessing = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error recording sale: $e')),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppSpacing.m),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueTab(ThemeData theme, List<Product> services, List<UserAccount> staff) {
    final queue = ref.watch(barberQueueProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Client Queue & Appointments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Pre-booked appointments auto-enter 30 mins prior', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showBookAppointmentDialog(context, services, staff),
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: const Text('Book Appointment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A1B9A),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddQueueDialog(context, services, staff),
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Add Client to Queue'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text('No clients currently in queue.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('Walk-ins and auto-queued appointments will appear here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: queue.length,
                      separatorBuilder: (context, sepIndex) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final q = queue[index];
                        final isIn = q.status == 'In Service';
                        final isDone = q.status == 'Completed';
                        final isAppointment = q.isAppointment;

                        // Unique styling container for pre-booked appointments vs walk-ins
                        return Container(
                          decoration: BoxDecoration(
                            color: isAppointment
                                ? (isIn 
                                    ? const Color(0xFF6A1B9A).withValues(alpha: 0.1) 
                                    : const Color(0xFF6A1B9A).withValues(alpha: 0.04))
                                : (isIn 
                                    ? Colors.green.withValues(alpha: 0.05) 
                                    : Theme.of(context).cardColor),
                            borderRadius: BorderRadius.circular(AppRadius.m),
                            border: Border.all(
                              color: isAppointment
                                  ? const Color(0xFF8E24AA).withValues(alpha: isIn ? 0.9 : 0.4)
                                  : (isIn ? Colors.green.shade400 : Colors.grey.shade300),
                              width: isAppointment ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Unique Banner for Pre-booked Appointments
                              if (isAppointment)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6A1B9A).withValues(alpha: 0.12),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(AppRadius.m - 1),
                                      topRight: Radius.circular(AppRadius.m - 1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.stars_rounded, size: 14, color: Color(0xFF6A1B9A)),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'PRE-BOOKED APPOINTMENT',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A), letterSpacing: 0.5),
                                      ),
                                      const Spacer(),
                                      if (q.appointmentTime != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6A1B9A),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Booked: ${DateFormat('h:mm a').format(q.appointmentTime!)}',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isAppointment
                                      ? const Color(0xFF6A1B9A).withValues(alpha: 0.15)
                                      : (isDone
                                          ? Colors.grey.withValues(alpha: 0.2)
                                          : (isIn ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1))),
                                  child: Icon(
                                    isAppointment
                                        ? (isDone ? Icons.check_circle : (isIn ? Icons.cut : Icons.stars_rounded))
                                        : (isDone ? Icons.check_circle : (isIn ? Icons.cut : Icons.hourglass_top)),
                                    color: isAppointment
                                        ? const Color(0xFF6A1B9A)
                                        : (isDone ? Colors.grey : (isIn ? Colors.green : Colors.orange)),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${q.customer} (${q.id})',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    if (q.price != null && q.price! > 0)
                                      Text(
                                        currencyFormat.format(q.price),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isAppointment ? const Color(0xFF6A1B9A) : Colors.green.shade800,
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text('Service: ${q.service} • Barber: ${q.barber}', style: const TextStyle(fontSize: 12)),
                                    Text(
                                      'Queued: ${DateFormat('h:mm a').format(q.timestamp)} • Phone: ${q.phone.isNotEmpty ? q.phone : "N/A"}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                trailing: Wrap(
                                  spacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (!isDone)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green.shade700,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        icon: const Icon(Icons.done_all, size: 14),
                                        label: const Text('Complete Cut'),
                                        onPressed: () => _showCompleteCutDialog(context, q),
                                      ),
                                    PopupMenuButton<String>(
                                      onSelected: (action) {
                                        if (action == 'complete_cut') {
                                          _showCompleteCutDialog(context, q);
                                        } else if (action == 'complete') {
                                          ref.read(barberQueueProvider.notifier).updateStatus(q.id, 'Completed');
                                        } else if (action == 'in_service') {
                                          ref.read(barberQueueProvider.notifier).updateStatus(q.id, 'In Service');
                                        } else if (action == 'waiting') {
                                          ref.read(barberQueueProvider.notifier).updateStatus(q.id, 'Waiting');
                                        } else if (action == 'remove') {
                                          ref.read(barberQueueProvider.notifier).removeFromQueue(q.id);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'complete_cut', child: Text('Complete Cut & Record Sale')),
                                        const PopupMenuItem(value: 'in_service', child: Text('Start Service (In Service)')),
                                        const PopupMenuItem(value: 'waiting', child: Text('Set Back to Waiting')),
                                        const PopupMenuItem(value: 'complete', child: Text('Mark Status as Completed')),
                                        const PopupMenuItem(value: 'remove', child: Text('Remove from Queue', style: TextStyle(color: Colors.red))),
                                      ],
                                      child: Chip(
                                        label: Text(
                                          q.status,
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        backgroundColor: isDone
                                            ? Colors.grey
                                            : (isIn ? Colors.green : (isAppointment ? const Color(0xFF6A1B9A) : Colors.blue)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsTab(ThemeData theme, List<Product> services, List<UserAccount> staff) {
    final appointments = ref.watch(barberAppointmentsProvider);
    final now = DateTime.now();

    final pendingPaymentAppts = appointments.where((a) => a.isPendingPayment).toList();

    final todayAppts = appointments.where((a) =>
        a.appointmentTime.year == now.year &&
        a.appointmentTime.month == now.month &&
        a.appointmentTime.day == now.day).toList();

    final upcomingAppts = appointments.where((a) =>
        a.appointmentTime.isAfter(now) && !a.isPendingPayment && (a.status == 'Scheduled' || a.status == 'Confirmed')).toList();

    final queuedAppts = appointments.where((a) => a.isQueued || a.status == 'Queued').toList();
    final completedAppts = appointments.where((a) => a.status == 'Completed').toList();

    List<BarberAppointment> filteredAppts = appointments;
    if (_appointmentFilter == 'Pending Payment') {
      filteredAppts = pendingPaymentAppts;
    } else if (_appointmentFilter == 'Today') {
      filteredAppts = todayAppts;
    } else if (_appointmentFilter == 'Upcoming') {
      filteredAppts = upcomingAppts;
    } else if (_appointmentFilter == 'In Queue') {
      filteredAppts = queuedAppts;
    } else if (_appointmentFilter == 'Completed') {
      filteredAppts = completedAppts;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          children: [
            // Top action bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appointment Bookings & Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Clients auto-enter Live Queue 30 mins before scheduled time with SMS', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showBookAppointmentDialog(context, services, staff),
                  icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                  label: const Text('Book Appointment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A1B9A),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),

            // Filters row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _appointmentFilterChip('All', appointments.length),
                  const SizedBox(width: 8),
                  _appointmentFilterChip('Pending Payment', pendingPaymentAppts.length),
                  const SizedBox(width: 8),
                  _appointmentFilterChip('Today', todayAppts.length),
                  const SizedBox(width: 8),
                  _appointmentFilterChip('Upcoming', upcomingAppts.length),
                  const SizedBox(width: 8),
                  _appointmentFilterChip('In Queue', queuedAppts.length),
                  const SizedBox(width: 8),
                  _appointmentFilterChip('Completed', completedAppts.length),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.m),

            // Appointment Cards List
            Expanded(
              child: filteredAppts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('No appointments found under "$_appointmentFilter"', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('Click "Book Appointment" to schedule an advance cut or service.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredAppts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _buildAppointmentCard(filteredAppts[index], theme);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appointmentFilterChip(String label, int count) {
    final isSelected = _appointmentFilter == label;
    return FilterChip(
      selected: isSelected,
      label: Text('$label ($count)'),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
      ),
      selectedColor: const Color(0xFF6A1B9A),
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFF6A1B9A) : Colors.grey.shade400,
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _appointmentFilter = label;
          });
        }
      },
    );
  }

  Widget _buildAppointmentCard(BarberAppointment appt, ThemeData theme) {
    final now = DateTime.now();
    final isToday = appt.appointmentTime.year == now.year &&
        appt.appointmentTime.month == now.month &&
        appt.appointmentTime.day == now.day;
    final isUpcoming = appt.appointmentTime.isAfter(now);
    final isWithin30Mins = appt.isDueForQueue;

    Color statusColor;
    if (appt.isPendingPayment) {
      statusColor = Colors.orange.shade800;
    } else if (appt.status == 'Completed') {
      statusColor = Colors.green;
    } else if (appt.status == 'Queued' || appt.isQueued) {
      statusColor = Colors.orange.shade800;
    } else if (appt.status == 'Cancelled') {
      statusColor = Colors.red;
    } else {
      statusColor = const Color(0xFF2E7D32);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(
          color: appt.isPendingPayment
              ? Colors.orange.shade600
              : (isWithin30Mins && !appt.isQueued
                  ? Colors.amber.shade700
                  : (appt.isQueued ? Colors.orange.shade300 : const Color(0xFF8E24AA).withValues(alpha: 0.3))),
          width: appt.isPendingPayment || isWithin30Mins ? 2 : 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Icon(
                    appt.isPendingPayment ? Icons.pending_actions_rounded : Icons.stars_rounded,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(appt.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(appt.id, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Service: ${appt.service} • Stylist: ${appt.barber}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Phone: ${appt.phone.isNotEmpty ? appt.phone : "N/A"} • Booked by: ${appt.bookedBy}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (appt.isPendingPayment) ...[
                            Icon(Icons.hourglass_top_rounded, size: 11, color: statusColor),
                            const SizedBox(width: 4),
                          ] else if (appt.paymentStatus == 'Validated' && !appt.isQueued && appt.status != 'Completed') ...[
                            Icon(Icons.check_circle, size: 11, color: statusColor),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            appt.isPendingPayment
                                ? 'PENDING PAYMENT'
                                : (appt.isQueued && appt.status == 'Scheduled'
                                    ? 'IN QUEUE'
                                    : (appt.paymentStatus == 'Validated' && appt.status == 'Scheduled'
                                        ? 'VALIDATED'
                                        : appt.status.toUpperCase())),
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormat.format(appt.price),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF6A1B9A)),
                    ),
                  ],
                ),
              ],
            ),

            // Pending Payment Alert & MoMo Details Box
            if (appt.isPendingPayment) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payment_rounded, size: 16, color: Colors.amber.shade900),
                        const SizedBox(width: 6),
                        Text(
                          'Payment Validation Required (Within 30 mins)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('MTN MoMo: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            SelectableText(appt.effectiveMomoNumber, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Name: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            SelectableText(appt.effectiveMomoName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Fee: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            Text(currencyFormat.format(appt.price), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Client received SMS instructions. Verify MoMo receipt for ${currencyFormat.format(appt.price)}, then click "Validate Appointment" below.',
                      style: TextStyle(fontSize: 10.5, color: Colors.black.withValues(alpha: 0.65)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Scheduled Date & Time
                Row(
                  children: [
                    const Icon(Icons.access_time_filled, size: 15, color: Color(0xFF6A1B9A)),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('EEE, d MMM yyyy @ h:mm a').format(appt.appointmentTime),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isToday ? '(Today)' : (isUpcoming ? '(${appt.appointmentTime.difference(now).inDays + 1}d away)' : '(Past)'),
                      style: TextStyle(fontSize: 11, color: isToday ? Colors.green.shade800 : Colors.grey),
                    ),
                  ],
                ),
                // SMS / Queue Notice
                if (isWithin30Mins && !appt.isQueued && !appt.isPendingPayment)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 13, color: Colors.amber.shade900),
                        const SizedBox(width: 2),
                        Text('Auto-Queueing Now (<30m)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                      ],
                    ),
                  ),
              ],
            ),
            if (appt.notes != null && appt.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.notes, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Notes: ${appt.notes}',
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (appt.isPendingPayment) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    icon: const Icon(Icons.sms_outlined, size: 14),
                    label: const Text('Resend MoMo SMS'),
                    onPressed: () async {
                      if (appt.phone.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client has no phone number.')));
                        return;
                      }
                      await SmsService.sendAppointmentBookingSms(
                        name: appt.customerName,
                        phone: appt.phone,
                        serviceName: appt.service,
                        barberName: appt.barber,
                        appointmentTime: appt.appointmentTime,
                        appointmentId: appt.id,
                        price: appt.price,
                        momoNumber: appt.effectiveMomoNumber,
                        momoName: appt.effectiveMomoName,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Payment instructions (${appt.effectiveMomoNumber}) re-sent to ${appt.phone}.')),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    icon: const Icon(Icons.verified_rounded, size: 15),
                    label: const Text('Validate Appointment'),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.verified_rounded, color: Color(0xFF2E7D32)),
                              SizedBox(width: 8),
                              Text('Validate Payment?'),
                            ],
                          ),
                          content: Text(
                            'Confirm that ${currencyFormat.format(appt.price)} has been received from ${appt.customerName} on MoMo ${appt.effectiveMomoNumber} (${appt.effectiveMomoName})?\n\nA confirmation SMS will be sent immediately to ${appt.phone}.',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('CONFIRM & SEND SMS'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(barberAppointmentsProvider.notifier).validateAppointment(appt.id);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF2E7D32),
                            content: Text('Appointment ${appt.id} validated! Confirmation SMS sent to ${appt.phone}.'),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: const Text('Cancel'),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cancel Appointment?'),
                          content: Text('Are you sure you want to cancel the appointment for ${appt.customerName}?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Yes, Cancel'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(barberAppointmentsProvider.notifier).cancelAppointment(appt.id);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Appointment ${appt.id} cancelled.')),
                        );
                      }
                    },
                  ),
                ] else if ((appt.status == 'Scheduled' || appt.status == 'Confirmed') && !appt.isQueued) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    icon: const Icon(Icons.sms_outlined, size: 14),
                    label: const Text('Resend Confirmation SMS'),
                    onPressed: () async {
                      if (appt.phone.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client has no phone number.')));
                        return;
                      }
                      await SmsService.sendAppointmentValidatedSms(
                        name: appt.customerName,
                        phone: appt.phone,
                        serviceName: appt.service,
                        barberName: appt.barber,
                        appointmentTime: appt.appointmentTime,
                        appointmentId: appt.id,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Confirmation SMS re-sent to ${appt.phone}.')),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 14),
                    label: const Text('Queue Now'),
                    onPressed: () async {
                      await ref.read(barberAppointmentsProvider.notifier).manualQueueNow(appt.id);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF1565C0),
                          content: Text('${appt.customerName} pushed to live queue and sent 30-min reminder SMS.'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: const Text('Cancel'),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cancel Appointment?'),
                          content: Text('Are you sure you want to cancel the appointment for ${appt.customerName}?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Yes, Cancel'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(barberAppointmentsProvider.notifier).cancelAppointment(appt.id);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Appointment ${appt.id} cancelled.')),
                        );
                      }
                    },
                  ),
                ] else if (appt.isQueued && appt.status != 'Completed') ...[
                  Chip(
                    avatar: const Icon(Icons.hourglass_bottom, size: 14, color: Colors.white),
                    label: const Text('In Live Queue', style: TextStyle(color: Colors.white, fontSize: 11)),
                    backgroundColor: Colors.orange.shade800,
                  ),
                ] else if (appt.status == 'Completed') ...[
                  const Chip(
                    avatar: Icon(Icons.check_circle, size: 14, color: Colors.white),
                    label: Text('Completed & Recorded', style: TextStyle(color: Colors.white, fontSize: 11)),
                    backgroundColor: Colors.green,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsTab(ThemeData theme, List<Product> services, List<UserAccount> staff) {
    final allRecords = ref.watch(barberRecordsProvider);

    // Extract unique barber names from staff and records
    final staffBarberNames = staff
        .where((u) => u.role == UserRole.barber || u.role == UserRole.secretary || u.role == UserRole.admin)
        .map((u) => '${u.firstName} ${u.surname}')
        .toList();
    final recordBarberNames = allRecords.map((r) => r.barber).toSet().toList();
    final Set<String> allBarberNames = {'All', ...staffBarberNames, ...recordBarberNames};

    // Extract unique haircut/service names from catalog and records
    final haircutNames = services
        .where((s) => !s.isDeleted && (
          s.category.toUpperCase().contains('BARBER') ||
          s.category.toUpperCase().contains('HAIR') ||
          s.category.toUpperCase().contains('BEARD') ||
          s.category.toUpperCase().contains('GROOM') ||
          s.isService
        ))
        .map((s) => s.name)
        .toSet();
    final recordServiceNames = allRecords.map((r) => r.service).toSet();
    final Set<String> allServiceOptions = {'All', ...haircutNames, ...recordServiceNames};

    // Filter using provider method (supports Customer Name, Barber, Haircut/Service, Date, Payment)
    final filtered = ref.read(barberRecordsProvider.notifier).filter(
      searchQuery: _recordsSearchController.text,
      selectedBarber: _recordBarberFilter,
      selectedService: _recordServiceFilter,
      selectedDateFilter: _recordDateFilter,
      customDateRange: _recordCustomRange,
      selectedPaymentMethod: _recordPaymentFilter,
    );

    final double totalRevenue = filtered.fold(0.0, (sum, r) => sum + r.totalPaid);
    final double avgTicket = filtered.isNotEmpty ? totalRevenue / filtered.length : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Title & Clear Filters Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Shaving & Grooming Records Archive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      'Search by customer, barber, haircut, and date range • ${allRecords.length} total records saved',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                if (_recordsSearchController.text.isNotEmpty ||
                    _recordBarberFilter != 'All' ||
                    _recordServiceFilter != 'All' ||
                    _recordDateFilter != 'All Time' ||
                    _recordPaymentFilter != 'All')
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _recordsSearchController.clear();
                        _recordBarberFilter = 'All';
                        _recordServiceFilter = 'All';
                        _recordDateFilter = 'All Time';
                        _recordCustomRange = null;
                        _recordPaymentFilter = 'All';
                      });
                    },
                    icon: const Icon(Icons.filter_alt_off, size: 16, color: Colors.red),
                    label: const Text('Clear All Filters', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),

            // 1. Search Bar (Customer Name, Phone, Service, Barber, Receipt ID)
            TextField(
              controller: _recordsSearchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Filter by Customer Name (e.g. "Kofi"), Phone number, Barber, or Receipt ID...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.person_search_outlined, size: 20),
                suffixIcon: _recordsSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _recordsSearchController.clear()),
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
              ),
            ),
            const SizedBox(height: AppSpacing.s),

            // 2. Dropdown Filters Row: Barber, Haircut / Service, Payment Method
            Row(
              children: [
                // Filter by Barber
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: allBarberNames.contains(_recordBarberFilter) ? _recordBarberFilter : 'All',
                    decoration: const InputDecoration(
                      labelText: 'Filter by Barber',
                      prefixIcon: Icon(Icons.badge_outlined, size: 16),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: allBarberNames.map((name) {
                      return DropdownMenuItem(
                        value: name,
                        child: Text(
                          name == 'All' ? 'All Barbers' : name,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _recordBarberFilter = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Filter by Haircut / Service
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: allServiceOptions.contains(_recordServiceFilter) ? _recordServiceFilter : 'All',
                    decoration: const InputDecoration(
                      labelText: 'Filter by Haircut / Service',
                      prefixIcon: Icon(Icons.cut_outlined, size: 16),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: allServiceOptions.map((srv) {
                      return DropdownMenuItem(
                        value: srv,
                        child: Text(
                          srv == 'All' ? 'All Haircuts / Services' : srv,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _recordServiceFilter = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Filter by Payment Method
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _recordPaymentFilter,
                    decoration: const InputDecoration(
                      labelText: 'Payment',
                      prefixIcon: Icon(Icons.payments_outlined, size: 16),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: ['All', 'Cash', 'MoMo', 'Card'].map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(
                          m == 'All' ? 'All Methods' : m,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _recordPaymentFilter = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),

            // 3. Quick Date Range Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRecordDateChip('All Time'),
                  const SizedBox(width: 6),
                  _buildRecordDateChip('Today'),
                  const SizedBox(width: 6),
                  _buildRecordDateChip('Yesterday'),
                  const SizedBox(width: 6),
                  _buildRecordDateChip('This Week'),
                  const SizedBox(width: 6),
                  _buildRecordDateChip('This Month'),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: Icon(
                      Icons.date_range,
                      size: 14,
                      color: _recordDateFilter == 'Custom' ? Colors.white : theme.colorScheme.primary,
                    ),
                    label: Text(
                      _recordDateFilter == 'Custom' && _recordCustomRange != null
                          ? '${DateFormat('d MMM').format(_recordCustomRange!.start)} - ${DateFormat('d MMM').format(_recordCustomRange!.end)}'
                          : 'Custom Date Range',
                      style: TextStyle(
                        fontSize: 11,
                        color: _recordDateFilter == 'Custom' ? Colors.white : theme.colorScheme.onSurface,
                        fontWeight: _recordDateFilter == 'Custom' ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    backgroundColor: _recordDateFilter == 'Custom' ? const Color(0xFF1565C0) : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: _recordDateFilter == 'Custom' ? const Color(0xFF1565C0) : Colors.grey.shade400,
                      ),
                    ),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        initialDateRange: _recordCustomRange ?? DateTimeRange(
                          start: DateTime.now().subtract(const Duration(days: 7)),
                          end: DateTime.now(),
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _recordDateFilter = 'Custom';
                          _recordCustomRange = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.m),

            // 4. Dynamic KPI Metric Chips (Reflecting Active Filtered Set)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(AppRadius.s),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _recordMetric('Filtered Records', '${filtered.length} Shaves / Cuts', Icons.format_list_numbered, const Color(0xFF1565C0)),
                  Container(height: 24, width: 1, color: Colors.grey.shade300),
                  _recordMetric('Total Revenue', currencyFormat.format(totalRevenue), Icons.monetization_on, Colors.green.shade700),
                  Container(height: 24, width: 1, color: Colors.grey.shade300),
                  _recordMetric('Avg Service Price', currencyFormat.format(avgTicket), Icons.analytics, const Color(0xFF6A1B9A)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.m),

            // 5. Records List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text('No shaving records match your filters.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('Try adjusting the customer name, barber, or date range.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _buildRecordCard(filtered[index], theme);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordDateChip(String label) {
    final isSelected = _recordDateFilter == label;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF1565C0),
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade400,
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _recordDateFilter = label;
            _recordCustomRange = null;
          });
        }
      },
    );
  }

  Widget _recordMetric(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ],
    );
  }

  Widget _buildRecordCard(BarberRecord record, ThemeData theme) {
    final isShave = record.serviceCategory == 'Shaves & Beard';
    final isDye = record.serviceCategory == 'Dye & Color';
    final isFacial = record.serviceCategory == 'Facials & Wash';
    final isKid = record.serviceCategory == 'Kids Haircut';

    Color categoryColor = const Color(0xFF1565C0);
    IconData categoryIcon = Icons.cut;
    if (isShave) {
      categoryColor = const Color(0xFFD32F2F);
      categoryIcon = Icons.face_retouching_natural;
    } else if (isDye) {
      categoryColor = const Color(0xFF6A1B9A);
      categoryIcon = Icons.palette;
    } else if (isFacial) {
      categoryColor = Colors.teal;
      categoryIcon = Icons.clean_hands;
    } else if (isKid) {
      categoryColor = Colors.orange.shade800;
      categoryIcon = Icons.child_care;
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: categoryColor.withValues(alpha: 0.12),
                  child: Icon(categoryIcon, color: categoryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.customerName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              record.serviceCategory,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: categoryColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Haircut / Service: ${record.service}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.person_pin, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('Barber: ${record.barber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 10),
                          if (record.customerPhone.isNotEmpty) ...[
                            const Icon(Icons.phone, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(record.customerPhone, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(record.totalPaid),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        record.paymentMethod.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('EEE, d MMM yyyy @ h:mm a').format(record.timestamp),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'Via ${record.source}',
                        style: const TextStyle(fontSize: 9, color: Color(0xFF1565C0), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    if (record.saleId != null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          textStyle: const TextStyle(fontSize: 10),
                          minimumSize: Size.zero,
                        ),
                        icon: const Icon(Icons.receipt_long, size: 12),
                        label: const Text('Receipt'),
                        onPressed: () {
                          final sales = ref.read(saleHistoryProvider);
                          final matched = sales.where((s) => s.id == record.saleId).firstOrNull;
                          if (matched != null) {
                            ReceiptService.printReceipt(matched, context: context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Invoice #${record.saleId} recorded.')),
                            );
                          }
                        },
                      ),
                    if (record.customerPhone.isNotEmpty)
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        icon: const Icon(Icons.sms_outlined, size: 16, color: Color(0xFF1565C0)),
                        tooltip: 'Send Follow-up SMS',
                        onPressed: () async {
                          await SmsService.sendPostHaircutSms(
                            name: record.customerName,
                            phone: record.customerPhone,
                            serviceName: record.service,
                            barberName: record.barber,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Follow-up SMS sent to ${record.customerPhone}.')),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesTab(ThemeData theme, List<Product> barbershopProducts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: barbershopProducts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cut_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No barbershop services found in product catalog.'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/admin/stock'),
                      child: const Text('Add Services in Master Stock Control'),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                itemCount: barbershopProducts.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final p = barbershopProducts[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(p.isService ? Icons.cut : Icons.sanitizer, color: theme.colorScheme.primary),
                    ),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Category: ${p.category} • Type: ${p.isService ? "Service / Labor" : "Retail Care Product"}\n'
                      '${p.isService ? "Fixed Barber Commission: ${currencyFormat.format(p.serviceCommission)}" : "Stock: ${p.isUnlimited ? "Unlimited" : "${p.stockQuantity} ${p.unit}"}"}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(currencyFormat.format(p.retailPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1565C0))),
                        if (p.isService)
                          Text('Comm: ${currencyFormat.format(p.serviceCommission)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildCommissionsTab(ThemeData theme, List<SaleRecord> todaySales, List<UserAccount> staff) {
    final allRecords = ref.watch(barberRecordsProvider);
    final barberNames = staff.isNotEmpty 
        ? staff.map((u) => '${u.firstName} ${u.surname}').toList()
        : ['King Mojo'];

    // Retrieve accurate aggregated summaries for each barber
    final summariesMap = ref.watch(barberRecordsProvider.notifier).getAllBarbersCommissionSummary(
      dateFilter: _commissionDateFilter,
      range: _commissionCustomRange,
      includeBarbers: barberNames,
    );

    // Calculate shop-wide totals for the selected period
    int totalServicesAll = 0;
    double totalGrossAll = 0.0;
    double totalCommissionAll = 0.0;
    double totalTipsAll = 0.0;

    summariesMap.forEach((_, summary) {
      totalServicesAll += summary.totalServices;
      totalGrossAll += summary.grossSales;
      totalCommissionAll += summary.totalCommission;
      totalTipsAll += summary.totalTips;
    });

    final double totalPayoutAll = totalCommissionAll + totalTipsAll;

    final summaries = summariesMap.values.toList()
      ..sort((a, b) => b.totalCommission.compareTo(a.totalCommission));

    final dateFilterOptions = ['Today', 'Yesterday', 'This Week', 'This Month', 'All Time', 'Custom Range'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header & Filter Section
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stylist Commissions & Earnings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(
                      'Period: $_commissionDateFilter • Tracking ${allRecords.length} completed shaves & cuts',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                // Date Filter Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...dateFilterOptions.map((filter) {
                      final isSelected = _commissionDateFilter == filter;
                      return ChoiceChip(
                        label: Text(filter, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF1565C0),
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                        onSelected: (selected) async {
                          if (selected) {
                            if (filter == 'Custom Range') {
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                initialDateRange: _commissionCustomRange ?? DateTimeRange(
                                  start: DateTime.now().subtract(const Duration(days: 7)),
                                  end: DateTime.now(),
                                ),
                              );
                              if (picked != null) {
                                setState(() {
                                  _commissionCustomRange = picked;
                                  _commissionDateFilter = filter;
                                });
                              }
                            } else {
                              setState(() {
                                _commissionDateFilter = filter;
                                _commissionCustomRange = null;
                              });
                            }
                          }
                        },
                      );
                    }),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),

            // Shop-Wide Summary KPI Grid
            Row(
              children: [
                Expanded(
                  child: _buildCommissionKpiCard(
                    title: 'SERVICES COMPLETED',
                    value: '$totalServicesAll Services',
                    subtitle: 'Cuts, shaves, dye & facials',
                    icon: Icons.content_cut_rounded,
                    color: const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCommissionKpiCard(
                    title: 'GROSS SERVICE SALES',
                    value: currencyFormat.format(totalGrossAll),
                    subtitle: 'Total billed revenue',
                    icon: Icons.attach_money_rounded,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCommissionKpiCard(
                    title: 'COMMISSION EARNED',
                    value: currencyFormat.format(totalCommissionAll),
                    subtitle: 'Standard ~40% split',
                    icon: Icons.account_balance_wallet_rounded,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCommissionKpiCard(
                    title: 'TOTAL PAYOUT (+TIPS)',
                    value: currencyFormat.format(totalPayoutAll),
                    subtitle: 'Includes ${currencyFormat.format(totalTipsAll)} tips',
                    icon: Icons.payments_rounded,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            const Divider(),

            // Stylists Breakdown List
            Expanded(
              child: summaries.isEmpty
                  ? const Center(child: Text('No stylist records found for this period.'))
                  : ListView.separated(
                      itemCount: summaries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final summary = summaries[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFF1565C0),
                            child: Text(
                              summary.barberName.isNotEmpty ? summary.barberName[0].toUpperCase() : 'B',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(summary.barberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${summary.totalServices} cuts/services',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Gross Sales: ${currencyFormat.format(summary.grossSales)} • Fixed Comm: ${currencyFormat.format(summary.totalCommission)} • Tips: ${currencyFormat.format(summary.totalTips)}',
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                              if (summary.servicesByType.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  summary.servicesByType.entries.map((e) => '${e.value} ${e.key}').join(', '),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currencyFormat.format(summary.totalEarnings),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                  ),
                                  Text(
                                    'Comm: ${currencyFormat.format(summary.totalCommission)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  side: const BorderSide(color: Color(0xFF1565C0)),
                                ),
                                icon: const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF1565C0)),
                                label: const Text('Breakdown', style: TextStyle(fontSize: 11, color: Color(0xFF1565C0))),
                                onPressed: () => _showBarberCommissionDetailsDialog(context, summary),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade800,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                icon: const Icon(Icons.payments_outlined, size: 14),
                                label: const Text('Settle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  final matching = staff.where((u) => '${u.firstName} ${u.surname}'.toLowerCase() == summary.barberName.toLowerCase() || u.firstName.toLowerCase() == summary.barberName.toLowerCase()).firstOrNull;
                                  BarberSettlementDialog.show(
                                    context: context,
                                    ref: ref,
                                    barberName: summary.barberName,
                                    barberPhone: matching?.phone,
                                    initialFilter: _commissionDateFilter == 'Custom Range' ? 'Today' : _commissionDateFilter,
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommissionKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBarberCommissionDetailsDialog(BuildContext context, BarberCommissionSummary summary) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF1565C0)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Commission Log: ${summary.barberName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('${summary.totalServices} haircuts/shaves • Total Earnings: ${currencyFormat.format(summary.totalEarnings)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 400,
          child: summary.records.isEmpty
              ? const Center(child: Text('No individual service records recorded in this period.'))
              : ListView.separated(
                  itemCount: summary.records.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = summary.records[i];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text('${r.service} (${r.customerName})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          Text(
                            '+${currencyFormat.format(r.effectiveCommission)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${DateFormat('d MMM, h:mm a').format(r.timestamp)} • Price: ${currencyFormat.format(r.price)} • Comm: ${currencyFormat.format(r.effectiveCommission)}',
                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                          if (r.tip > 0)
                            Text('Tip: +${currencyFormat.format(r.tip)}',
                                style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/barbershop';
    final menuItems = ref.watch(menuItemsProvider);

    // Live Data Providers
    final productsAsync = ref.watch(productsFutureProvider);
    final sales = ref.watch(saleHistoryProvider);
    final users = ref.watch(userProvider);
    final liveQueue = ref.watch(barberQueueProvider);
    final appointments = ref.watch(barberAppointmentsProvider);
    final allRecords = ref.watch(barberRecordsProvider);

    final allProducts = productsAsync.value ?? [];
    final barbershopProducts = allProducts.where((p) => !p.isDeleted && (
      p.category.toUpperCase().contains('BARBER') ||
      p.category.toUpperCase().contains('HAIR') ||
      p.category.toUpperCase().contains('BEARD') ||
      p.category.toUpperCase().contains('GROOM')
    ) && !p.category.toUpperCase().contains('REPAIR') && !p.name.toUpperCase().contains('IPHONE') && !p.name.toUpperCase().contains('BATTERY') && !p.name.toUpperCase().contains('CHARGING') && !p.name.toUpperCase().contains('FLASHING')).toList();

    // Today's Sales Calculation
    final now = DateTime.now();
    final todaySales = sales.where((s) {
      final isToday = s.timestamp.year == now.year && s.timestamp.month == now.month && s.timestamp.day == now.day;
      final isBarbershop = s.items.any((item) => 
        item.product.category.toUpperCase().contains('BARBER') ||
        item.product.category.toUpperCase().contains('HAIR') ||
        item.product.category.toUpperCase().contains('BEARD') ||
        item.product.isService
      );
      return isToday && isBarbershop;
    }).toList();

    final double todayRevenue = todaySales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final int todayClientsServed = todaySales.length;

    // Today's appointments count
    final todayAppointments = appointments.where((a) =>
        a.appointmentTime.year == now.year &&
        a.appointmentTime.month == now.month &&
        a.appointmentTime.day == now.day).toList();

    // Active Barbers / Staff
    final activeBarbers = users.where((u) => !u.isDeleted && u.status == AccountStatus.approved && (u.role == UserRole.barber || u.role == UserRole.secretary || u.role == UserRole.admin)).toList();

    return RolePopScope(
      currentRoute: currentRoute,
      child: Scaffold(
        appBar: const MainAppBar(title: 'Barbershop Operations'),
        drawer: isDesktop
            ? null
            : Drawer(
                child: AppSidebar(
                  userId: user?.id ?? '',
                  userName: user?.name ?? 'Barber',
                  userRole: user?.activePrimaryRole.display.toUpperCase() ?? 'BARBER',
                  currentRoute: currentRoute,
                  items: menuItems,
                  onTap: (route) => MenuService.navigate(context, route, currentRoute),
                ),
              ),
        body: Row(
          children: [
            if (isDesktop)
              AppSidebar(
                userId: user?.id ?? '',
                userName: user?.name ?? 'Barber',
                userRole: user?.activePrimaryRole.display.toUpperCase() ?? 'BARBER',
                currentRoute: currentRoute,
                items: menuItems,
                onTap: (route) => MenuService.navigate(context, route, currentRoute),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Hero Banner
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                      color: const Color(0xFF1565C0),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.content_cut, size: 30, color: Colors.white),
                            ),
                            const SizedBox(width: AppSpacing.m),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Barbershop Grooming Operations',
                                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Live Client Queue, Advance Bookings, Automated 30-Min Queueing & POS Sales',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, '/barbershop/pos'),
                              icon: const Icon(Icons.point_of_sale),
                              label: const Text('OPEN BARBER POS'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1565C0),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),

                    // 4 Live Stat Cards
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Clients Served Today', todayClientsServed.toString(), Icons.people_alt, Colors.blue)),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(child: _buildStatCard('Queue Waiting', '${liveQueue.where((q) => q.status != 'Completed').length} Active', Icons.access_time_filled, Colors.orange)),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(child: _buildStatCard('Appointments Today', '${todayAppointments.length} Booked', Icons.calendar_month, const Color(0xFF6A1B9A))),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(child: _buildStatCard('Today\'s Revenue', currencyFormat.format(todayRevenue), Icons.monetization_on, Colors.green)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),

                    // 5 Tabs
                    TabBar(
                      controller: _tabController,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: theme.colorScheme.primary,
                      tabs: [
                        const Tab(icon: Icon(Icons.queue), text: 'Live Customer Queue'),
                        Tab(
                          icon: Badge.count(
                            count: todayAppointments.where((a) => a.status == 'Scheduled').length,
                            isLabelVisible: todayAppointments.where((a) => a.status == 'Scheduled').isNotEmpty,
                            child: const Icon(Icons.calendar_month),
                          ),
                          text: 'Appointments Schedule',
                        ),
                        Tab(
                          icon: Badge.count(
                            count: allRecords.length,
                            isLabelVisible: allRecords.isNotEmpty,
                            child: const Icon(Icons.receipt_long),
                          ),
                          text: 'Shaving & Records',
                        ),
                        const Tab(icon: Icon(Icons.design_services), text: 'Services Catalog'),
                        const Tab(icon: Icon(Icons.badge), text: 'Barber Commissions'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    SizedBox(
                      height: 600,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildQueueTab(theme, barbershopProducts, activeBarbers),
                          _buildAppointmentsTab(theme, barbershopProducts, activeBarbers),
                          _buildRecordsTab(theme, barbershopProducts, activeBarbers),
                          _buildServicesTab(theme, barbershopProducts),
                          _buildCommissionsTab(theme, todaySales, activeBarbers),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}