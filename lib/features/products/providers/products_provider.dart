import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../models/product_model.dart';

class ProductsState {
  final List<ProductModel> products;
  final bool isLoading;
  final String? error;

  const ProductsState({this.products = const [], this.isLoading = false, this.error});

  ProductsState copyWith({List<ProductModel>? products, bool? isLoading, String? error}) {
    return ProductsState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProductsNotifier extends StateNotifier<ProductsState> {
  ProductsNotifier() : super(const ProductsState()) {
    loadProducts();
  }

  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseService.client
          .from(SupabaseConstants.products)
          .select()
          .order('name');

      final products = (response as List)
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(products: products, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load products: $e');
    }
  }

  Future<bool> createProduct(Map<String, dynamic> data) async {
    try {
      await SupabaseService.client.from(SupabaseConstants.products).insert(data);
      await loadProducts();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create product: $e');
      return false;
    }
  }

  Future<bool> updateProduct(String id, Map<String, dynamic> updates) async {
    try {
      await SupabaseService.client
          .from(SupabaseConstants.products)
          .update(updates)
          .eq('id', id);
      await loadProducts();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update product: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      await SupabaseService.client.from(SupabaseConstants.products).delete().eq('id', id);
      await loadProducts();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete product: $e');
      return false;
    }
  }

  /// Deduct stock when an order is delivered
  Future<void> deductStock(String productName, int qty) async {
    try {
      final products = state.products.where((p) => p.name == productName).toList();
      if (products.isNotEmpty) {
        final product = products.first;
        final newQty = (product.stockQuantity - qty).clamp(0, 999999);
        await updateProduct(product.id, {'stock_quantity': newQty});
      }
    } catch (_) {}
  }

  List<ProductModel> get lowStockProducts {
    return state.products.where((p) => p.isLowStock && p.isActive).toList();
  }
}

final productsProvider = StateNotifierProvider<ProductsNotifier, ProductsState>((ref) {
  return ProductsNotifier();
});

final lowStockProvider = Provider<List<ProductModel>>((ref) {
  return ref.watch(productsProvider).products
      .where((p) => p.isLowStock && p.isActive)
      .toList();
});
