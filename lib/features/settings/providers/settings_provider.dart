import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/constants/supabase_constants.dart';

/// Settings provider — manages configurable system defaults
class SettingsState {
  final Map<String, String> settings;
  final List<Map<String, dynamic>> couriers;
  final List<Map<String, dynamic>> deliveryCharges;
  final bool isLoading;
  final String? error;

  const SettingsState({
    this.settings = const {},
    this.couriers = const [],
    this.deliveryCharges = const [],
    this.isLoading = false,
    this.error,
  });

  SettingsState copyWith({
    Map<String, String>? settings,
    List<Map<String, dynamic>>? couriers,
    List<Map<String, dynamic>>? deliveryCharges,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      couriers: couriers ?? this.couriers,
      deliveryCharges: deliveryCharges ?? this.deliveryCharges,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  String getSetting(String key, [String defaultValue = '']) {
    return settings[key] ?? defaultValue;
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    await Future.wait([
      _loadSettings(),
      _loadCouriers(),
      _loadDeliveryCharges(),
    ]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadSettings() async {
    try {
      final response = await SupabaseService.client
          .from(SupabaseConstants.settings)
          .select();

      final map = <String, String>{};
      for (final row in (response as List)) {
        map[row['key'] as String] = row['value'] as String;
      }
      state = state.copyWith(settings: map);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load settings: $e');
    }
  }

  Future<void> _loadCouriers() async {
    try {
      final response = await SupabaseService.client
          .from(SupabaseConstants.couriers)
          .select()
          .eq('is_active', true)
          .order('name');

      state = state.copyWith(
        couriers: List<Map<String, dynamic>>.from(response as List),
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to load couriers: $e');
    }
  }

  Future<void> _loadDeliveryCharges() async {
    try {
      final response = await SupabaseService.client
          .from(SupabaseConstants.deliveryCharges)
          .select()
          .order('city');

      state = state.copyWith(
        deliveryCharges: List<Map<String, dynamic>>.from(response as List),
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to load delivery charges: $e');
    }
  }

  /// Update a setting
  Future<bool> updateSetting(String key, String value) async {
    try {
      await SupabaseService.client
          .from(SupabaseConstants.settings)
          .update({'value': value})
          .eq('key', key);

      final newSettings = Map<String, String>.from(state.settings);
      newSettings[key] = value;
      state = state.copyWith(settings: newSettings);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update setting: $e');
      return false;
    }
  }

  /// Add a courier
  Future<bool> addCourier(String name) async {
    try {
      await SupabaseService.client
          .from(SupabaseConstants.couriers)
          .insert({'name': name});
      await _loadCouriers();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to add courier: $e');
      return false;
    }
  }

  /// Remove a courier
  Future<bool> removeCourier(String id) async {
    try {
      await SupabaseService.client
          .from(SupabaseConstants.couriers)
          .delete()
          .eq('id', id);
      await _loadCouriers();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to remove courier: $e');
      return false;
    }
  }

  /// Add a city delivery charge
  Future<bool> addDeliveryCharge(String city, double charge) async {
    try {
      await SupabaseService.client
          .from(SupabaseConstants.deliveryCharges)
          .insert({'city': city, 'charge': charge});
      await _loadDeliveryCharges();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to add delivery charge: $e');
      return false;
    }
  }

  /// Update a city delivery charge
  Future<bool> updateDeliveryCharge(String id, double charge) async {
    try {
      await SupabaseService.client
          .from(SupabaseConstants.deliveryCharges)
          .update({'charge': charge})
          .eq('id', id);
      await _loadDeliveryCharges();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update delivery charge: $e');
      return false;
    }
  }

  /// Remove a city delivery charge
  Future<bool> removeDeliveryCharge(String id) async {
    try {
      await SupabaseService.client
          .from(SupabaseConstants.deliveryCharges)
          .delete()
          .eq('id', id);
      await _loadDeliveryCharges();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to remove delivery charge: $e');
      return false;
    }
  }

  /// Get delivery charge for a city
  double getChargeForCity(String city) {
    final match = state.deliveryCharges
        .where((dc) => (dc['city'] as String).toLowerCase() == city.toLowerCase())
        .toList();
    if (match.isNotEmpty) {
      return (match.first['charge'] as num).toDouble();
    }
    return 0;
  }

  /// Get courier names list
  List<String> get courierNames {
    return state.couriers.map((c) => c['name'] as String).toList();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

/// Convenience providers
final courierNamesProvider = Provider<List<String>>((ref) {
  return ref.watch(settingsProvider).couriers
      .map((c) => c['name'] as String)
      .toList();
});

final deliveryChargesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(settingsProvider).deliveryCharges;
});
