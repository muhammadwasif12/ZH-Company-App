import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../models/staff_model.dart';

class StaffState {
  final List<StaffModel> staff;
  final bool isLoading;
  final String? error;

  const StaffState({this.staff = const [], this.isLoading = false, this.error});

  StaffState copyWith({List<StaffModel>? staff, bool? isLoading, String? error}) {
    return StaffState(
      staff: staff ?? this.staff,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class StaffNotifier extends StateNotifier<StaffState> {
  StaffNotifier() : super(const StaffState()) {
    loadStaff();
  }

  Future<void> loadStaff() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseService.client
          .from(SupabaseConstants.staff)
          .select()
          .order('created_at', ascending: false);

      final staff = (response as List)
          .map((json) => StaffModel.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(staff: staff, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load staff: $e');
    }
  }

  Future<bool> createStaff(Map<String, dynamic> data) async {
    try {
      await SupabaseService.client.from(SupabaseConstants.staff).insert(data);
      await loadStaff();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create staff: $e');
      return false;
    }
  }

  Future<bool> updateStaff(String id, Map<String, dynamic> updates) async {
    try {
      await SupabaseService.client
          .from(SupabaseConstants.staff)
          .update(updates)
          .eq('id', id);
      if (updates.containsKey('is_active')) {
        final staff = state.staff.firstWhere((s) => s.id == id);
        await SupabaseService.client.from('profiles').update({
          'is_active': updates['is_active'],
        }).eq('id', staff.userId);
      }
      await loadStaff();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update staff: $e');
      return false;
    }
  }

  Future<bool> deleteStaff(String id) async {
    try {
      await SupabaseService.client.rpc(
        'delete_staff_account',
        params: {'target_staff_id': id},
      );
      await loadStaff();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete staff: $e');
      return false;
    }
  }
}

final staffProvider = StateNotifierProvider<StaffNotifier, StaffState>((ref) {
  return StaffNotifier();
});
