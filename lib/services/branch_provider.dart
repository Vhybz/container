import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/branch_model.dart';
import 'supabase_branch_service.dart';
import 'user_provider.dart';

final branchServiceProvider = Provider<SupabaseBranchService>((ref) {
  return SupabaseBranchService();
});

final branchesFutureProvider = FutureProvider<List<Branch>>((ref) async {
  return ref.watch(branchServiceProvider).getBranches();
});

class BranchNotifier extends StateNotifier<AsyncValue<List<Branch>>> {
  final SupabaseBranchService _service;

  BranchNotifier(this._service) : super(const AsyncValue.loading()) {
    loadBranches();
  }

  Future<void> loadBranches() async {
    state = const AsyncValue.loading();
    try {
      final branches = await _service.getBranches();
      state = AsyncValue.data(branches);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addBranch(Branch branch) async {
    try {
      await _service.createBranch(branch);
      await loadBranches();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setBranchAdmin(String code, String adminId) async {
    try {
      await _service.updateBranchAdmin(code, adminId);
      await loadBranches();
    } catch (e) {
      // Ignore errors for now as this is a secondary update
    }
  }
}

final branchesProvider = StateNotifierProvider<BranchNotifier, AsyncValue<List<Branch>>>((ref) {
  return BranchNotifier(ref.watch(branchServiceProvider));
});

final currentBranchProvider = Provider<Branch?>((ref) {
  final user = ref.watch(currentUserProvider);
  final branchesAsync = ref.watch(branchesProvider);
  
  return branchesAsync.when(
    data: (branches) => branches.where((b) => b.code == user?.branchCode).firstOrNull,
    loading: () => null,
    error: (_, _) => null,
  );
});
