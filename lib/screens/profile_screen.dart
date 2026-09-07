import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import '../services/user_provider.dart';
import '../widgets/main_app_bar.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/app_sidebar.dart';
import '../services/menu_service.dart';
import '../services/auth_provider.dart';
import '../widgets/role_pop_scope.dart';
import '../services/branch_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/profile';
    final menuItems = ref.watch(menuItemsProvider);

    return RolePopScope(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const MainAppBar(title: 'My Profile'),
        drawer: isDesktop ? null : Drawer(
          child: AppSidebar(
            userId: user.id,
            userName: user.name,
            userRole: user.activePrimaryRole.name.toUpperCase(),
            currentRoute: currentRoute,
            items: menuItems,
            onTap: (route) => MenuService.navigate(context, route, currentRoute),
          ),
        ),
        body: Row(
          children: [
            if (isDesktop)
              AppSidebar(
                userId: user.id,
                userName: user.name,
                userRole: user.activePrimaryRole.name.toUpperCase(),
                currentRoute: currentRoute,
                items: menuItems,
                onTap: (route) => MenuService.navigate(context, route, currentRoute),
              ),
            const Expanded(
              child: ProfileView(),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  late TextEditingController _firstNameController;
  late TextEditingController _surnameController;
  late TextEditingController _phoneController;
  
  String? _selectedGender;
  DateTime? _selectedDob;
  bool _isEditing = false;
  bool _isUploading = false;
  Uint8List? _localImageBytes;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _surnameController = TextEditingController(text: user?.surname ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _selectedGender = user?.gender;
    _selectedDob = user?.dob;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: Text('No user logged in.'));

    final theme = Theme.of(context);
    final currentBranch = ref.watch(currentBranchProvider);
    final branchDisplay = currentBranch != null ? '${currentBranch.name} (${currentBranch.location})' : (user.branchCode ?? 'Global Admin');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModernHeader(theme, user),
              const SizedBox(height: AppSpacing.xl),
              _buildProfileContent(theme, user, branchDisplay),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(ThemeData theme, UserAccount user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          _buildAvatarWithPicker(user),
          const SizedBox(height: 20),
          Text(
            user.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
            ),
            child: Text(
              user.role.name.toUpperCase(),
              style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWithPicker(UserAccount user) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: _isUploading ? null : _updatePhoto,
      borderRadius: BorderRadius.circular(60),
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(color: _isUploading ? Colors.orange : theme.colorScheme.primary, width: 3),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: ClipOval(
              child: _localImageBytes != null
                ? Image.memory(_localImageBytes!, fit: BoxFit.cover)
                : (_isUploading 
                  ? const Center(child: CircularProgressIndicator())
                  : (user.photoUrl != null
                    ? Image.network(
                        user.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, _, _) => Icon(Icons.person_rounded, size: 60, color: theme.colorScheme.primary),
                      )
                    : Icon(Icons.person_rounded, size: 60, color: theme.colorScheme.primary))),
            ),
          ),
          if (!_isUploading)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.cardTheme.color ?? Colors.transparent, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(ThemeData theme, UserAccount user, String branchDisplay) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Information', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    Text(
                      'System & Security Profile',
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _isEditing = !_isEditing),
                icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          if (!_isEditing) ...[
            _modernInfoRow(Icons.phone_rounded, 'Phone Number', user.phone ?? 'Not provided'),
            _modernInfoRow(Icons.wc_rounded, 'Gender', user.gender ?? 'Not provided'),
            _modernInfoRow(Icons.cake_rounded, 'Date of Birth', user.dob != null ? DateFormat('MMMM d, yyyy').format(user.dob!) : 'Not provided'),
            _modernInfoRow(Icons.calendar_today_rounded, 'Joined System', DateFormat('MMMM d, yyyy').format(user.createdAt)),
            _modernInfoRow(Icons.location_city_rounded, 'Current Branch', branchDisplay),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  GlobalLogout.perform(ref).then((_) {
                    navigator.pushNamedAndRemoveUntil('/login', (route) => false);
                    messenger.showSnackBar(const SnackBar(content: Text('Signed out successfully.')));
                  });
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: const Text('Sign Out Securely', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else ...[
            _buildEditField(_firstNameController, 'First Name', Icons.person_outline),
            const SizedBox(height: 16),
            _buildEditField(_surnameController, 'Surname', Icons.person_outline),
            const SizedBox(height: 16),
            _buildEditField(_phoneController, 'Phone Number', Icons.phone_android_rounded),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder(), prefixIcon: Icon(Icons.wc_rounded)),
              items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setState(() => _selectedGender = v),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDob ?? DateTime(2000),
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDob = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cake_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDob == null ? 'Select Date of Birth' : DateFormat('MMMM d, yyyy').format(_selectedDob!),
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Update Profile Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modernInfoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label, 
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
    );
  }

  Future<void> _updatePhoto() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        setState(() {
          _localImageBytes = bytes;
          _isUploading = true;
        });

        final url = await ref.read(userProvider.notifier).updatePhoto(user.id, bytes);
        
        if (!mounted) return;
        setState(() => _isUploading = false);
        
        if (url != null) {
          // Upload success, we can clear local bytes and use the URL
          setState(() => _localImageBytes = null);
          messenger.showSnackBar(
            const SnackBar(content: Text('Profile picture updated successfully!'), backgroundColor: Colors.green),
          );
        } else {
          // Upload failed (offline), but we keep showing the local image for "seamlessness"
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Working offline. Image will sync when connection returns.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _saveProfile() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      final messenger = ScaffoldMessenger.of(context);
      ref.read(userProvider.notifier).updateProfile(
        user.id,
        firstName: _firstNameController.text.trim(),
        surname: _surnameController.text.trim(),
        phone: _phoneController.text.trim(),
        gender: _selectedGender,
        dob: _selectedDob,
      ).then((_) {
        if (!mounted) return;
        setState(() => _isEditing = false);
        messenger.showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));
      });
    }
  }
}
