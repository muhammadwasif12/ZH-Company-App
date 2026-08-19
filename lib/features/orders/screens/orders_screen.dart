import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/external_activity_guard.dart';
import '../../../models/enums.dart';
import '../../../models/order_model.dart';
import '../../../models/staff_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/screens/settings_screen.dart';
import '../../staff/providers/staff_provider.dart';
import '../providers/orders_provider.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  final bool staffOnly;
  const OrdersScreen({super.key, this.staffOnly = false});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrderStatus? _statusFilter;
  String? _staffFilterId;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Refresh after every role/session transition before opening Orders.
    Future.microtask(() => ref.read(ordersProvider.notifier).loadOrders());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OrderModel> _filteredOrders(List<OrderModel> orders) {
    var result = orders;
    if (widget.staffOnly) {
      final userId = ref.read(authProvider).supabaseUser?.id;
      if (userId != null) {
        result = result.where((o) => o.staffId == userId).toList();
      } else {
        result = const <OrderModel>[];
      }
    }
    if (_statusFilter != null) {
      result = result.where((o) => o.status == _statusFilter!.value).toList();
    }
    if (_staffFilterId != null) {
      // Older records can use the staff-row ID, whereas current records use
      // the auth/profile user ID. Match both IDs for the selected staff member.
      final selectedStaff = ref
          .read(staffProvider)
          .staff
          .where(
            (staff) =>
                staff.userId == _staffFilterId || staff.id == _staffFilterId,
          )
          .toList();
      final staffIds = <String>{_staffFilterId!};
      if (selectedStaff.isNotEmpty) {
        staffIds
          ..add(selectedStaff.first.id)
          ..add(selectedStaff.first.userId);
      }
      result = result
          .where((order) => staffIds.contains(order.staffId))
          .toList();
    }
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result
          .where(
            (o) =>
                o.customerName.toLowerCase().contains(q) ||
                o.customerMobile.contains(q) ||
                o.productName.toLowerCase().contains(q) ||
                o.city.toLowerCase().contains(q) ||
                (o.orderId?.toLowerCase().contains(q) ?? false) ||
                (o.trackingNumber?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersProvider);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: AppSpacing.md),
          _buildFilters(),
          const SizedBox(height: AppSpacing.xl),
          _buildOrdersTable(ordersState),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.staffOnly ? 'My Orders' : 'Orders',
                style: AppTypography.h1.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Manage and track all orders',
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
          onPressed: () => _showOrderForm(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New Order'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final searchWidget = SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() {}),
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textPrimary,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          hintText: 'Search orders...',
          hintStyle: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
            fontSize: 12,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          fillColor: AppColors.surfaceVariant.withValues(alpha: 0.6),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );

    final dropdownWidget = Container(
      height: 44,
      width: 135,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<OrderStatus?>(
          isExpanded: true,
          value: _statusFilter,
          hint: Text(
            'Status',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.textTertiary,
          ),
          dropdownColor: AppColors.surface,
          items: [
            DropdownMenuItem<OrderStatus?>(
              value: null,
              child: Text(
                'All Statuses',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                ),
              ),
            ),
            ...OrderStatus.values.map((status) {
              return DropdownMenuItem(
                value: status,
                child: StatusBadge(status: status, fontSize: 10),
              );
            }),
          ],
          onChanged: (val) => setState(() => _statusFilter = val),
        ),
      ),
    );

    final matchingStaff = ref
        .watch(staffProvider)
        .staff
        .where((s) => s.userId == _staffFilterId || s.id == _staffFilterId)
        .toList();
    final selectedStaff = matchingStaff.isEmpty ? null : matchingStaff.first;
    final isAdmin = ref.watch(currentRoleProvider) == UserRole.admin;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: searchWidget),
              const SizedBox(width: AppSpacing.sm),
              dropdownWidget,
            ],
          ),
          if (isAdmin) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showStaffFilterDialog,
                icon: const Icon(Icons.badge_outlined, size: 17),
                label: Text(
                  selectedStaff == null
                      ? 'Filter by Staff Member'
                      : 'Staff: ${selectedStaff.name} • ${selectedStaff.staffCode.isNotEmpty ? selectedStaff.staffCode : selectedStaff.userId.substring(0, 8)}',
                ),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showStaffFilterDialog() async {
    final staff = ref.read(staffProvider).staff;
    final selected = await showDialog<String?>(
      context: context,
      builder: (_) => _StaffFilterDialog(staff: staff),
    );
    if (!mounted || selected == null) return;
    setState(() => _staffFilterId = selected.isEmpty ? null : selected);
  }

  Widget _buildOrdersTable(OrdersState state) {
    if (state.isLoading) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final orders = _filteredOrders(state.orders);
    final isAdmin = ref.watch(currentRoleProvider) == UserRole.admin;

    if (orders.isEmpty) {
      return Container(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'No orders found',
            subtitle: 'Try adjusting filters or tap + to create a new order',
            action: ElevatedButton.icon(
              onPressed: () => _showOrderForm(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create Order'),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orders.length,
      padding: const EdgeInsets.only(bottom: 20),
      itemBuilder: (context, index) {
        final o = orders[index];
        final statusEnum = OrderStatus.values.firstWhere(
          (s) => s.value == o.status,
          orElse: () => OrderStatus.pending,
        );
        final canEdit =
            isAdmin ||
            (widget.staffOnly &&
                o.status == SupabaseConstants.statusPending);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Slidable(
            key: ValueKey(o.id),
            startActionPane: canEdit
                ? ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (_) => _showOrderForm(context, order: o),
                        backgroundColor: AppColors.info,
                        foregroundColor: Colors.white,
                        icon: Icons.edit_rounded,
                        label: 'Edit',
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(16),
                        ),
                      ),
                    ],
                  )
                : null,
            endActionPane: isAdmin
                ? ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (_) => _confirmDelete(o),
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        icon: Icons.delete_rounded,
                        label: 'Delete',
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(16),
                        ),
                      ),
                    ],
                  )
                : null,
            child: Card(
              margin: EdgeInsets.zero,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                onTap: canEdit
                    ? () => _showOrderForm(context, order: o)
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('This order is locked after dispatch.'),
                        ),
                      ),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                o.displayId,
                                style: AppTypography.mono.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${o.orderDate.day}/${o.orderDate.month}/${o.orderDate.year}',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          StatusBadge(status: statusEnum, fontSize: 11),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Created by: ${o.staffName ?? 'Unknown staff'}${o.staffCode?.isNotEmpty == true ? ' (${o.staffCode})' : ''}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          'STAFF • ${o.staffCode?.isNotEmpty == true ? o.staffCode : ((o.staffId?.length ?? 0) > 8 ? o.staffId!.substring(0, 8) : (o.staffId ?? 'Deleted staff'))}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.info,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.customerName,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${o.customerMobile} • ${o.city}',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Rs. ${o.codAmount.toStringAsFixed(0)}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${o.quantity}x ${o.productName}',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (o.courierCompany != null ||
                          o.trackingNumber != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Courier: ${o.courierCompany ?? "N/A"}${o.trackingNumber != null ? "  •  Trk: ${o.trackingNumber}" : ""}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showOrderForm(BuildContext context, {OrderModel? order}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OrderFormScreen(order: order)),
    );
  }

  void _confirmDelete(OrderModel order) async {
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Delete Order',
      message: 'Delete order "${order.displayId}" for ${order.customerName}?',
      confirmText: 'Delete',
      confirmColor: AppColors.error,
    );
    if (confirm == true) {
      final success = await ref
          .read(ordersProvider.notifier)
          .deleteOrder(order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Order deleted' : 'Failed to delete'),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }
}

class _StaffFilterDialog extends StatefulWidget {
  final List<StaffModel> staff;

  const _StaffFilterDialog({required this.staff});

  @override
  State<_StaffFilterDialog> createState() => _StaffFilterDialogState();
}

class _StaffFilterDialogState extends State<_StaffFilterDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = widget.staff.where((staff) {
      return query.isEmpty ||
          staff.name.toLowerCase().contains(query) ||
          staff.staffCode.toLowerCase().contains(query) ||
          staff.userId.toLowerCase().contains(query);
    }).toList();
    final media = MediaQuery.of(context);
    final maxContentHeight = (media.size.height - media.viewInsets.bottom - 180)
        .clamp(180.0, 420.0)
        .toDouble();

    return AlertDialog(
      title: const Text('Filter Orders by Staff'),
      content: SizedBox(
        width: 420,
        height: maxContentHeight,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search name, code or ID',
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: filtered.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ListTile(
                      leading: const Icon(Icons.select_all),
                      title: const Text('All staff'),
                      onTap: () => Navigator.pop(context, ''),
                    );
                  }
                  final staff = filtered[index - 1];
                  final code = staff.staffCode.isNotEmpty
                      ? staff.staffCode
                      : staff.userId.substring(0, 8);
                  return ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(
                      staff.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('Staff ID: $code'),
                    onTap: () => Navigator.pop(context, staff.userId),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderFormScreen extends StatelessWidget {
  final OrderModel? order;
  const OrderFormScreen({super.key, this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          order != null ? 'Edit Order' : 'Create New Order',
          style: AppTypography.h2.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(child: OrderFormDialog(order: order)),
    );
  }
}

/// Order creation/edit dialog
class OrderFormDialog extends ConsumerStatefulWidget {
  final OrderModel? order;
  const OrderFormDialog({super.key, this.order});

  @override
  ConsumerState<OrderFormDialog> createState() => _OrderFormDialogState();
}

class _OrderFormDialogState extends ConsumerState<OrderFormDialog> {
  static const _otherCourierValue = '__other_courier__';
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerMobileController = TextEditingController();
  final _customerWhatsappController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _productNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _codAmountController = TextEditingController();
  final _deliveryChargesController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  final _trackingController = TextEditingController();
  final _notesController = TextEditingController();
  final _customCourierController = TextEditingController();
  String? _selectedCourier;
  String _selectedStatus = SupabaseConstants.statusPending;
  bool _isLoading = false;
  String? _error;
  File? _proofImage;

  bool get isEditing => widget.order != null;

  @override
  void initState() {
    super.initState();
    _recoverLostImage();
    if (isEditing) {
      final o = widget.order!;
      _customerNameController.text = o.customerName;
      _customerMobileController.text = o.customerMobile;
      _customerWhatsappController.text = o.customerWhatsapp ?? '';
      _addressController.text = o.address;
      _cityController.text = o.city;
      _productNameController.text = o.productName;
      _quantityController.text = o.quantity.toString();
      _codAmountController.text = o.codAmount.toString();
      _deliveryChargesController.text = o.deliveryCharges.toString();
      _discountController.text = o.discount.toString();
      _trackingController.text = o.trackingNumber ?? '';
      _notesController.text = o.notes ?? '';
      _selectedCourier = o.courierCompany;
      _selectedStatus = o.status;
    }
    _restoreOrderDraft();
  }

  Future<void> _saveOrderDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('order_form_draft', [
      _customerNameController.text,
      _customerMobileController.text,
      _customerWhatsappController.text,
      _addressController.text,
      _cityController.text,
      _productNameController.text,
      _quantityController.text,
      _codAmountController.text,
      _deliveryChargesController.text,
      _discountController.text,
      _trackingController.text,
      _notesController.text,
      _selectedCourier ?? '',
      _customCourierController.text,
    ]);
  }

  Future<void> _restoreOrderDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getStringList('order_form_draft');
    if (!mounted || draft == null || draft.length < 14 || isEditing) return;
    final fields = [
      _customerNameController,
      _customerMobileController,
      _customerWhatsappController,
      _addressController,
      _cityController,
      _productNameController,
      _quantityController,
      _codAmountController,
      _deliveryChargesController,
      _discountController,
      _trackingController,
      _notesController,
    ];
    for (var i = 0; i < fields.length; i++) {
      fields[i].text = draft[i];
    }
    _customCourierController.text = draft[13];
    setState(() => _selectedCourier = draft[12].isEmpty ? null : draft[12]);
  }

  Future<void> _recoverLostImage() async {
    final lostData = await ImagePicker().retrieveLostData();
    if (!mounted || lostData.isEmpty || lostData.file == null) return;
    setState(() => _proofImage = File(lostData.file!.path));
  }

  void _showFullProofImage({File? file, String? url}) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: file != null
                  ? Image.file(file, fit: BoxFit.contain)
                  : Image.network(url!, fit: BoxFit.contain),
            ),
            IconButton.filled(
              tooltip: 'Close preview',
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerMobileController.dispose();
    _customerWhatsappController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _productNameController.dispose();
    _quantityController.dispose();
    _codAmountController.dispose();
    _deliveryChargesController.dispose();
    _discountController.dispose();
    _trackingController.dispose();
    _notesController.dispose();
    _customCourierController.dispose();
    super.dispose();
  }

  Future<void> _pickProofImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Attach Proof Image',
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primary,
                ),
                title: Text(
                  'Take Photo (Camera)',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.info,
                ),
                title: Text(
                  'Choose from Gallery',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null) {
      await _saveOrderDraft();
      ExternalActivityGuard.isActive = true;
      try {
        final XFile? image = await picker.pickImage(
          source: source,
          imageQuality: 80,
        );
        if (image != null && mounted) {
          setState(() => _proofImage = File(image.path));
        }
      } finally {
        ExternalActivityGuard.isActive = false;
      }
    }
  }

  String _shareOrderDetails() {
    final orderNumber = widget.order?.displayId ?? 'New order';
    final courier = _selectedCourier == _otherCourierValue
        ? _customCourierController.text.trim()
        : _selectedCourier;
    final lines = <String>[
      '*Order: $orderNumber*',
      'Customer: ${_customerNameController.text.trim()}',
      'Mobile: ${_customerMobileController.text.trim()}',
      if (_customerWhatsappController.text.trim().isNotEmpty)
        'WhatsApp: ${_customerWhatsappController.text.trim()}',
      'Address: ${_addressController.text.trim()}, ${_cityController.text.trim()}',
      'Product: ${_productNameController.text.trim()} x ${_quantityController.text.trim()}',
      'COD: Rs. ${_codAmountController.text.trim()}',
      'Delivery fee: Rs. ${_deliveryChargesController.text.trim()}',
      if (_discountController.text.trim().isNotEmpty &&
          _discountController.text.trim() != '0')
        'Discount: Rs. ${_discountController.text.trim()}',
    ];
    if (courier != null && courier.isNotEmpty) {
      lines.add('Courier: $courier');
    }
    if (_trackingController.text.trim().isNotEmpty) {
      lines.add('Tracking: ${_trackingController.text.trim()}');
    }
    if (_notesController.text.trim().isNotEmpty) {
      lines.add('Notes: ${_notesController.text.trim()}');
    }
    if (_proofImage == null && widget.order?.proofImageUrl != null) {
      lines.add('Proof image: ${widget.order!.proofImageUrl}');
    }
    return lines.join('\n');
  }

  Future<void> _shareOrderOnWhatsApp() async {
    final details = _shareOrderDetails();
    if (_proofImage != null) {
      await Share.shareXFiles(
        [XFile(_proofImage!.path)],
        text: details,
        subject: 'Order ${widget.order?.displayId ?? ''}',
      );
    } else {
      await Share.share(
        details,
        subject: 'Order ${widget.order?.displayId ?? ''}',
      );
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
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _error!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Text(
                    'Customer Information',
                    style: AppTypography.h4.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Customer Name *',
                    hint: 'Full name',
                    controller: _customerNameController,
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Mobile Number *',
                    hint: '03XX-XXXXXXX',
                    controller: _customerMobileController,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Builder(
                    builder: (context) {
                      final mobile = _customerMobileController.text.trim();
                      if (mobile.isEmpty) return const SizedBox.shrink();
                      final blacklist = const <Map<String, dynamic>>[];
                      final match = blacklist.firstWhere(
                        (b) =>
                            (b['customer_mobile'] ?? '').toString().trim() ==
                            mobile,
                        orElse: () => {},
                      );
                      if (match.isNotEmpty) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                            border: Border.all(color: AppColors.error),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.block,
                                color: AppColors.error,
                                size: 20,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  '⚠️ WARNING: Phone number is BLACKLISTED! Reason: ${match['reason'] ?? "Flagged customer"}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'WhatsApp',
                          hint: '03XX-XXXXXXX',
                          controller: _customerWhatsappController,
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppTextField(
                          label: 'City *',
                          hint: 'City',
                          controller: _cityController,
                          onChanged: _applyDeliveryChargeForCity,
                          validator: (v) =>
                              v?.isEmpty == true ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Complete Address *',
                    hint: 'Full delivery address',
                    controller: _addressController,
                    maxLines: 2,
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Product & Pricing',
                    style: AppTypography.h4.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: AppTextField(
                          label: 'Product Name *',
                          hint: 'Product',
                          controller: _productNameController,
                          validator: (v) =>
                              v?.isEmpty == true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppTextField(
                          label: 'Qty *',
                          hint: '1',
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              v?.isEmpty == true ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'COD Amount *',
                          hint: 'Rs. 0',
                          controller: _codAmountController,
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              v?.isEmpty == true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppTextField(
                          label: 'Delivery Fee',
                          hint: 'Rs. 0',
                          controller: _deliveryChargesController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Shipping & Proof',
                    style: AppTypography.h4.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Consumer(
                    builder: (context, ref, _) {
                      final savedCouriers =
                          ref
                              .watch(couriersProvider)
                              .map((courier) => courier['name']?.toString())
                              .whereType<String>()
                              .where((name) => name.trim().isNotEmpty)
                              .toSet()
                              .toList()
                            ..sort();
                      final selectedCourier = _selectedCourier;
                      if (selectedCourier != null &&
                          selectedCourier != _otherCourierValue &&
                          !savedCouriers.contains(selectedCourier)) {
                        savedCouriers.add(selectedCourier);
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Courier Company (optional)',
                                      style: AppTypography.label.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd,
                                        ),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedCourier,
                                          isExpanded: true,
                                          hint: Text(
                                            'Courier',
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                                  color: AppColors.textTertiary,
                                                ),
                                          ),
                                          dropdownColor: AppColors.surface,
                                          items: [
                                            ...savedCouriers.map(
                                              (courier) =>
                                                  DropdownMenuItem<String>(
                                                    value: courier,
                                                    child: Text(
                                                      courier,
                                                      style: AppTypography
                                                          .bodySmall
                                                          .copyWith(
                                                            color: AppColors
                                                                .textPrimary,
                                                          ),
                                                    ),
                                                  ),
                                            ),
                                            DropdownMenuItem<String>(
                                              value: _otherCourierValue,
                                              child: Text(
                                                'Other (type name)',
                                                style: AppTypography.bodySmall
                                                    .copyWith(
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                              ),
                                            ),
                                          ],
                                          onChanged: (val) => setState(
                                            () => _selectedCourier = val,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: AppTextField(
                                  label: 'Tracking ID',
                                  hint: 'Tracking #',
                                  controller: _trackingController,
                                ),
                              ),
                            ],
                          ),
                          if (_selectedCourier == _otherCourierValue) ...[
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              label: 'Other courier company',
                              hint: 'Type courier company name',
                              controller: _customCourierController,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (ref.watch(currentRoleProvider) == UserRole.admin) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Order Status',
                      ),
                      items: OrderStatus.values
                          .map(
                            (status) => DropdownMenuItem<String>(
                              value: status.value,
                              child: Text(status.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(
                        () => _selectedStatus = value ?? _selectedStatus,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  OutlinedButton.icon(
                    onPressed: _pickProofImage,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: const Text('Attach Proof / Receipt Image'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                  if (_proofImage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _showFullProofImage(file: _proofImage),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                            child: Image.file(
                              _proofImage!,
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton.filled(
                            tooltip: 'Remove image',
                            onPressed: () => setState(() => _proofImage = null),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ],
                    ),
                  ] else if (isEditing &&
                      widget.order!.proofImageUrl != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    GestureDetector(
                      onTap: () =>
                          _showFullProofImage(url: widget.order!.proofImageUrl),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        child: Image.network(
                          widget.order!.proofImageUrl!,
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Notes',
                    hint: 'Additional notes...',
                    controller: _notesController,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Share order on WhatsApp',
                onPressed: _shareOrderOnWhatsApp,
                icon: const Icon(Icons.share_outlined),
                color: AppColors.success,
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AppSpacing.md),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? 'Update Order' : 'Create Order'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orderData = <String, dynamic>{
        if (ref.read(currentRoleProvider) == UserRole.admin)
          'status': _selectedStatus,
        'customer_name': _customerNameController.text.trim(),
        'customer_mobile': _customerMobileController.text.trim(),
        'customer_whatsapp': _customerWhatsappController.text.trim().isNotEmpty
            ? _customerWhatsappController.text.trim()
            : null,
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'product_name': _productNameController.text.trim(),
        'quantity': int.tryParse(_quantityController.text) ?? 1,
        'cod_amount': double.tryParse(_codAmountController.text) ?? 0,
        'delivery_charges':
            double.tryParse(_deliveryChargesController.text) ?? 0,
        'discount': double.tryParse(_discountController.text) ?? 0,
        'courier_company': _selectedCourier == _otherCourierValue
            ? (_customCourierController.text.trim().isEmpty
                  ? null
                  : _customCourierController.text.trim())
            : _selectedCourier,
        'tracking_number': _trackingController.text.trim().isNotEmpty
            ? _trackingController.text.trim()
            : null,
        'notes': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      };

      final lockedStatus =
          _selectedStatus == SupabaseConstants.statusDelivered ||
          _selectedStatus == SupabaseConstants.statusReturned;
      final statusChanged =
          !isEditing || _selectedStatus != widget.order?.status;
      final hasProof =
          _proofImage != null ||
          (widget.order?.proofImageUrl?.isNotEmpty ?? false);
      if (ref.read(currentRoleProvider) == UserRole.admin &&
          lockedStatus &&
          statusChanged &&
          !hasProof) {
        setState(() {
          _error =
              'Proof image is required before marking an order Delivered or Return.';
          _isLoading = false;
        });
        return;
      }

      // Learn a new city at runtime: once an admin/staff enters a fee for a
      // city not yet configured in Settings, persist it for future orders.
      final city = _cityController.text.trim();
      final enteredFee = double.tryParse(_deliveryChargesController.text) ?? 0;
      final cityExists = ref
          .read(deliveryChargesProvider)
          .any(
            (row) =>
                (row['city'] ?? '').toString().trim().toLowerCase() ==
                city.toLowerCase(),
          );
      if (city.isNotEmpty && enteredFee > 0 && !cityExists) {
        await ref.read(deliveryChargesProvider.notifier).add(city, enteredFee);
      }

      // The image is optional: save the order even if its upload is unavailable.
      if (_proofImage != null) {
        try {
          final proofImageUrl = await CloudinaryService.uploadImage(
            _proofImage!,
            folder: 'beon_cosmetic/orders',
          );
          if (proofImageUrl != null) {
            orderData['proof_image_url'] = proofImageUrl;
          }
        } catch (_) {}
      }

      final bool success;
      if (isEditing) {
        success = await ref
            .read(ordersProvider.notifier)
            .updateOrder(widget.order!.id, orderData);
      } else {
        success = await ref
            .read(ordersProvider.notifier)
            .createOrder(orderData);
      }

      if (mounted) {
        if (success) {
          final navigator = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('order_form_draft');
          if (mounted) {
            navigator.pop();
            messenger.showSnackBar(
              SnackBar(
                content: Text(isEditing ? 'Order updated!' : 'Order created!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } else {
          setState(() {
            _error = ref.read(ordersProvider).error ?? 'Failed to save order';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyDeliveryChargeForCity(String city) {
    final normalized = city.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final match = ref.read(deliveryChargesProvider).where((row) {
      return (row['city'] ?? '').toString().trim().toLowerCase() == normalized;
    }).toList();
    if (match.isNotEmpty) {
      _deliveryChargesController.text =
          ((match.first['charge'] as num?)?.toDouble() ?? 0).toStringAsFixed(0);
    }
  }
}
