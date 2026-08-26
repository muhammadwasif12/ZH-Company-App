import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/product_model.dart';
import '../providers/products_provider.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(productsProvider);

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final isWide = outerConstraints.maxWidth > 700;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, isWide ? 4 : 10, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isWide) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Products Catalog',
                            style: AppTypography.h1.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Manage product catalog & stock',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton.icon(
                      onPressed: () => _showAddProductDialog(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Product'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showAddProductDialog(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Product'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: _buildProductsBody(context, ref, productsState),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductsBody(BuildContext context, WidgetRef ref, ProductsState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.products.isEmpty) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: Center(
          child: EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No products in catalog',
            subtitle: 'Click "Add Product" to add your first cosmetic item.',
            action: ElevatedButton.icon(
              onPressed: () => _showAddProductDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add Product Now'),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        if (isMobile) {
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.products.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = state.products[index];
              return Card(
                margin: EdgeInsets.zero,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: !item.isActive
                                  ? AppColors.error.withValues(alpha: 0.1)
                                  : item.isOutOfStock
                                      ? AppColors.error.withValues(alpha: 0.15)
                                      : item.isLowStock
                                          ? AppColors.warning.withValues(alpha: 0.15)
                                          : AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                            ),
                            child: Text(
                              !item.isActive
                                  ? 'Disabled'
                                  : item.isOutOfStock
                                      ? 'Out of Stock'
                                      : item.isLowStock
                                          ? 'Low Stock'
                                          : 'In Stock',
                              style: AppTypography.caption.copyWith(
                                color: !item.isActive
                                    ? AppColors.error
                                    : item.isOutOfStock
                                        ? AppColors.error
                                        : item.isLowStock
                                            ? AppColors.warning
                                            : AppColors.success,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SKU: ${item.sku ?? "-"} • ${item.category ?? "Cosmetics"}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Rs. ${item.price.toStringAsFixed(0)}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Stock: ${item.stockQuantity} units',
                            style: AppTypography.caption.copyWith(
                              color: item.isLowStock ? AppColors.error : AppColors.textTertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_note_rounded, size: 20, color: AppColors.info),
                                tooltip: 'Edit Product',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                                onPressed: () => _showEditProductDialog(context, ref, item),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded, size: 20, color: AppColors.error),
                                tooltip: 'Delete Product',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                                onPressed: () => _confirmDeleteProduct(context, ref, item),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.products.length + 1,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: 14,
                  ),
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: _headerText('PRODUCT NAME')),
                      Expanded(flex: 2, child: _headerText('SKU')),
                      Expanded(flex: 2, child: _headerText('CATEGORY')),
                      Expanded(flex: 2, child: _headerText('PRICE')),
                      Expanded(flex: 2, child: _headerText('COST PRICE')),
                      Expanded(flex: 2, child: _headerText('STOCK QTY')),
                      Expanded(flex: 2, child: _headerText('STATUS')),
                      Expanded(flex: 2, child: _headerText('ACTIONS')),
                    ],
                  ),
                );
              }

              final item = state.products[index - 1];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.name,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.sku ?? '-',
                        style: AppTypography.mono.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.category ?? 'Cosmetics',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Rs. ${item.price.toStringAsFixed(0)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.costPrice != null
                            ? 'Rs. ${item.costPrice!.toStringAsFixed(0)}'
                            : '-',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${item.stockQuantity} units',
                        style: AppTypography.bodySmall.copyWith(
                          color: item.isLowStock
                              ? AppColors.error
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: !item.isActive
                                ? AppColors.error.withValues(alpha: 0.1)
                                : item.isOutOfStock
                                    ? AppColors.error.withValues(alpha: 0.15)
                                    : item.isLowStock
                                        ? AppColors.warning.withValues(
                                            alpha: 0.15,
                                          )
                                        : AppColors.success.withValues(
                                            alpha: 0.15,
                                          ),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusFull,
                            ),
                          ),
                          child: Text(
                            !item.isActive
                                ? 'Disabled'
                                : item.isOutOfStock
                                    ? 'Out of Stock'
                                    : item.isLowStock
                                        ? 'Low Stock'
                                        : 'In Stock',
                            style: AppTypography.caption.copyWith(
                              color: !item.isActive
                                  ? AppColors.error
                                  : item.isOutOfStock
                                      ? AppColors.error
                                      : item.isLowStock
                                          ? AppColors.warning
                                          : AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_note_rounded,
                              size: 20,
                              color: AppColors.info,
                            ),
                            tooltip: 'Edit Product',
                            onPressed: () => _showEditProductDialog(
                              context,
                              ref,
                              item,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_rounded,
                              size: 20,
                              color: AppColors.error,
                            ),
                            tooltip: 'Delete Product',
                            onPressed: () => _confirmDeleteProduct(
                              context,
                              ref,
                              item,
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
        );
      },
    );
  }

  Widget _headerText(String text) {
    return Text(
      text,
      style: AppTypography.label.copyWith(
        color: AppColors.textTertiary,
        fontSize: 11,
      ),
    );
  }

  void _showAddProductDialog(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProductFormScreen(),
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, WidgetRef ref, ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductFormScreen(product: product),
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, WidgetRef ref, ProductModel product) async {
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Delete Product',
      message: 'Are you sure you want to delete "${product.name}"? This action cannot be undone.',
      confirmText: 'Delete Product',
      confirmColor: AppColors.error,
    );

    if (confirm == true) {
      final success = await ref.read(productsProvider.notifier).deleteProduct(product.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Product deleted' : 'Failed to delete product'),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }
}

class ProductFormScreen extends StatelessWidget {
  final ProductModel? product;
  const ProductFormScreen({super.key, this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          product != null ? 'Edit Product' : 'Add New Product',
          style: AppTypography.h2.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: product != null ? _EditProductDialog(product: product!) : const _AddProductDialog(),
      ),
    );
  }
}

// ─── Add Product Dialog ──────────────────────────────
class _AddProductDialog extends ConsumerStatefulWidget {
  const _AddProductDialog();

  @override
  ConsumerState<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<_AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Cosmetics');
  final _priceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _stockController = TextEditingController(text: '100');
  final _lowStockController = TextEditingController(text: '10');
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await ref.read(productsProvider.notifier).createProduct({
      'name': _nameController.text.trim(),
      'sku': _skuController.text.trim().isNotEmpty ? _skuController.text.trim() : null,
      'category': _categoryController.text.trim(),
      'price': double.tryParse(_priceController.text) ?? 0,
      'cost_price': double.tryParse(_costPriceController.text),
      'stock_quantity': int.tryParse(_stockController.text) ?? 0,
      'low_stock_threshold': int.tryParse(_lowStockController.text) ?? 10,
      'is_active': true,
    });

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product added successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() {
          _error = 'Failed to add product';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  AppTextField(
                    label: 'Product Name *',
                    controller: _nameController,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  LayoutBuilder(builder: (ctx, constraints) {
                    final isNarrow = constraints.maxWidth < 400;
                    if (isNarrow) {
                      return Column(children: [
                        AppTextField(label: 'SKU / Item Code', controller: _skuController),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(label: 'Category', controller: _categoryController),
                      ]);
                    }
                    return Row(children: [
                      Expanded(child: AppTextField(label: 'SKU / Item Code', controller: _skuController)),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: AppTextField(label: 'Category', controller: _categoryController)),
                    ]);
                  }),
                  const SizedBox(height: AppSpacing.lg),

                  LayoutBuilder(builder: (ctx, constraints) {
                    final isNarrow = constraints.maxWidth < 400;
                    if (isNarrow) {
                      return Column(children: [
                        AppTextField(label: 'Selling Price (Rs.) *', controller: _priceController, keyboardType: TextInputType.number, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(label: 'Cost Price (Rs.)', controller: _costPriceController, keyboardType: TextInputType.number),
                      ]);
                    }
                    return Row(children: [
                      Expanded(child: AppTextField(label: 'Selling Price (Rs.) *', controller: _priceController, keyboardType: TextInputType.number, validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: AppTextField(label: 'Cost Price (Rs.)', controller: _costPriceController, keyboardType: TextInputType.number)),
                    ]);
                  }),
                  const SizedBox(height: AppSpacing.lg),

                  LayoutBuilder(builder: (ctx, constraints) {
                    final isNarrow = constraints.maxWidth < 400;
                    if (isNarrow) {
                      return Column(children: [
                        AppTextField(label: 'Stock Quantity', controller: _stockController, keyboardType: TextInputType.number),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(label: 'Low Stock Threshold', controller: _lowStockController, keyboardType: TextInputType.number),
                      ]);
                    }
                    return Row(children: [
                      Expanded(child: AppTextField(label: 'Stock Quantity', controller: _stockController, keyboardType: TextInputType.number)),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: AppTextField(label: 'Low Stock Threshold', controller: _lowStockController, keyboardType: TextInputType.number)),
                    ]);
                  }),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(_isLoading ? 'Saving...' : 'Save Product'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Edit Product Dialog ──────────────────────────────
class _EditProductDialog extends ConsumerStatefulWidget {
  final ProductModel product;
  const _EditProductDialog({required this.product});

  @override
  ConsumerState<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends ConsumerState<_EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _categoryController;
  late TextEditingController _priceController;
  late TextEditingController _costPriceController;
  late TextEditingController _stockController;
  late TextEditingController _lowStockController;
  late bool _isActive;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _skuController = TextEditingController(text: widget.product.sku ?? '');
    _categoryController = TextEditingController(text: widget.product.category ?? 'Cosmetics');
    _priceController = TextEditingController(text: widget.product.price.toString());
    _costPriceController = TextEditingController(text: widget.product.costPrice?.toString() ?? '');
    _stockController = TextEditingController(text: widget.product.stockQuantity.toString());
    _lowStockController = TextEditingController(text: widget.product.lowStockThreshold.toString());
    _isActive = widget.product.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final updates = {
      'name': _nameController.text.trim(),
      'sku': _skuController.text.trim().isNotEmpty ? _skuController.text.trim() : null,
      'category': _categoryController.text.trim(),
      'price': double.tryParse(_priceController.text) ?? widget.product.price,
      'cost_price': double.tryParse(_costPriceController.text),
      'stock_quantity': int.tryParse(_stockController.text) ?? widget.product.stockQuantity,
      'low_stock_threshold': int.tryParse(_lowStockController.text) ?? widget.product.lowStockThreshold,
      'is_active': _isActive,
    };

    final success = await ref.read(productsProvider.notifier).updateProduct(widget.product.id, updates);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() {
          _error = 'Failed to update product';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  AppTextField(
                    label: 'Product Name *',
                    controller: _nameController,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  LayoutBuilder(builder: (ctx, constraints) {
                    final isNarrow = constraints.maxWidth < 400;
                    if (isNarrow) {
                      return Column(children: [
                        AppTextField(label: 'SKU', controller: _skuController),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(label: 'Category', controller: _categoryController),
                      ]);
                    }
                    return Row(children: [
                      Expanded(child: AppTextField(label: 'SKU', controller: _skuController)),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: AppTextField(label: 'Category', controller: _categoryController)),
                    ]);
                  }),
                  const SizedBox(height: AppSpacing.lg),

                  LayoutBuilder(builder: (ctx, constraints) {
                    final isNarrow = constraints.maxWidth < 400;
                    if (isNarrow) {
                      return Column(children: [
                        AppTextField(label: 'Selling Price (Rs.) *', controller: _priceController, keyboardType: TextInputType.number),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(label: 'Cost Price (Rs.)', controller: _costPriceController, keyboardType: TextInputType.number),
                      ]);
                    }
                    return Row(children: [
                      Expanded(child: AppTextField(label: 'Selling Price (Rs.) *', controller: _priceController, keyboardType: TextInputType.number)),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: AppTextField(label: 'Cost Price (Rs.)', controller: _costPriceController, keyboardType: TextInputType.number)),
                    ]);
                  }),
                  const SizedBox(height: AppSpacing.lg),

                  LayoutBuilder(builder: (ctx, constraints) {
                    final isNarrow = constraints.maxWidth < 400;
                    if (isNarrow) {
                      return Column(children: [
                        AppTextField(label: 'Stock Quantity', controller: _stockController, keyboardType: TextInputType.number),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(label: 'Low Stock Threshold', controller: _lowStockController, keyboardType: TextInputType.number),
                      ]);
                    }
                    return Row(children: [
                      Expanded(child: AppTextField(label: 'Stock Quantity', controller: _stockController, keyboardType: TextInputType.number)),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: AppTextField(label: 'Low Stock Threshold', controller: _lowStockController, keyboardType: TextInputType.number)),
                    ]);
                  }),
                  const SizedBox(height: AppSpacing.lg),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Active Product Status', style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary)),
                    value: _isActive,
                    activeThumbColor: AppColors.success,
                    onChanged: (val) => setState(() => _isActive = val),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(_isLoading ? 'Saving...' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
