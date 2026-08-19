import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/enums.dart';
import '../../orders/providers/orders_provider.dart';

class CodLedgerScreen extends ConsumerStatefulWidget {
  const CodLedgerScreen({super.key});

  @override
  ConsumerState<CodLedgerScreen> createState() => _CodLedgerScreenState();
}

class _CodLedgerScreenState extends ConsumerState<CodLedgerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dashboardStatsProvider);
    final ordersState = ref.watch(ordersProvider);
    final orders = ordersState.orders;

    final totalCod = (stats['total_cod'] as num?)?.toDouble() ?? 0.0;
    final deliveredCod = (stats['delivered_cod'] as num?)?.toDouble() ?? 0.0;
    final pendingCod = (stats['pending_cod'] as num?)?.toDouble() ?? 0.0;

    // Filter entries based on search & status
    final filteredOrders = orders.where((o) {
      // Status filter
      if (_statusFilter != 'all' && o.status != _statusFilter) {
        return false;
      }
      // Search filter (Order ID, Customer name, City, Mobile)
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchId = o.displayId.toLowerCase().contains(query);
        final matchCustomer = o.customerName.toLowerCase().contains(query);
        final matchCity = o.city.toLowerCase().contains(query);
        final matchMobile = o.customerMobile.toLowerCase().contains(query);
        if (!matchId && !matchCustomer && !matchCity && !matchMobile) {
          return false;
        }
      }
      return true;
    }).toList();

    final filteredTotalNet = filteredOrders.fold<double>(
      0.0,
      (sum, item) => sum + item.netCod,
    );

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Moved up higher)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'COD Ledger',
                          style: AppTypography.h1.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Auto-Synced',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cash on delivery reconciliation, tracking, and settlement records',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Top KPI Cards (Compact & elevated)
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 1000
                  ? (constraints.maxWidth - 3 * AppSpacing.md) / 4
                  : (constraints.maxWidth - AppSpacing.md) / 2;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: KpiCard(
                      title: 'Total COD',
                      value: 'Rs. ${totalCod.toStringAsFixed(0)}',
                      icon: Icons.account_balance_wallet,
                      color: AppColors.info,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: KpiCard(
                      title: 'Delivered COD',
                      value: 'Rs. ${deliveredCod.toStringAsFixed(0)}',
                      icon: Icons.check_circle,
                      color: AppColors.delivered,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: KpiCard(
                      title: 'Pending COD',
                      value: 'Rs. ${pendingCod.toStringAsFixed(0)}',
                      icon: Icons.hourglass_empty,
                      color: AppColors.pending,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: KpiCard(
                      title: 'Net Payable',
                      value:
                          'Rs. ${(deliveredCod - pendingCod).abs().toStringAsFixed(0)}',
                      icon: Icons.payments_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Search and Status Filters
          LayoutBuilder(
            builder: (context, constraints) {
              final searchField = TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by Order ID, Customer, City or Mobile...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textTertiary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                );
              final statusFilter = Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    icon: const Icon(
                      Icons.filter_list_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _statusFilter = val;
                        });
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All Statuses'),
                      ),
                      DropdownMenuItem(
                        value: 'delivered',
                        child: Text('Delivered'),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(
                        value: 'returned',
                        child: Text('Returned'),
                      ),
                    ],
                  ),
                ),
              );
              if (constraints.maxWidth < 460) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [searchField, const SizedBox(height: AppSpacing.sm), statusFilter]);
              }
              return Row(children: [Expanded(child: searchField), const SizedBox(width: AppSpacing.sm), statusFilter]);
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // Ledger Table Container (Keyboard safe & responsive height)
          Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height * 0.55,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: ordersState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredOrders.isEmpty
                    ? const Center(
                        child: EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No COD entries found',
                          subtitle:
                              'Try clearing your search filters or wait for new orders to sync.',
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 700) {
                            return _mobileLedgerList(filteredOrders, filteredTotalNet);
                          }
                          final minWidth = constraints.maxWidth > 900
                              ? constraints.maxWidth
                              : 900.0;
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: minWidth),
                              child: SizedBox(
                                width: minWidth,
                                child: Column(
                                  children: [
                                    // Table Header
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.xl,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant
                                            .withValues(alpha: 0.5),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(20),
                                          topRight: Radius.circular(20),
                                        ),
                                        border: const Border(
                                          bottom: BorderSide(
                                            color: AppColors.border,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          _header('ORDER ID', 2),
                                          _header('CUSTOMER', 3),
                                          _header('CITY', 2),
                                          _header('COD AMOUNT', 2),
                                          _header('DELIVERY CHG', 2),
                                          _header('NET COD', 2),
                                          _header('STATUS', 2),
                                          _header('DATE', 2),
                                        ],
                                      ),
                                    ),

                                    // Table Body
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: filteredOrders.length,
                                      separatorBuilder: (_, _) =>
                                          const Divider(
                                        height: 1,
                                        color: AppColors.border,
                                      ),
                                      itemBuilder: (context, i) {
                                        final o = filteredOrders[i];
                                        final statusEnum =
                                            OrderStatus.fromString(o.status);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.xl,
                                            vertical: AppSpacing.sm,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  o.displayId,
                                                  style: AppTypography.mono
                                                      .copyWith(
                                                    color: AppColors.primary,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  o.customerName,
                                                  style: AppTypography
                                                      .bodySmall
                                                      .copyWith(
                                                    color:
                                                        AppColors.textPrimary,
                                                    fontWeight:
                                                        FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  o.city,
                                                  style: AppTypography
                                                      .bodySmall
                                                      .copyWith(
                                                    color: AppColors
                                                        .textSecondary,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  'Rs. ${o.codAmount.toStringAsFixed(0)}',
                                                  style: AppTypography
                                                      .bodySmall
                                                      .copyWith(
                                                    color: AppColors.success,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  'Rs. ${o.deliveryCharges.toStringAsFixed(0)}',
                                                  style: AppTypography
                                                      .bodySmall
                                                      .copyWith(
                                                    color: AppColors
                                                        .textTertiary,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  'Rs. ${o.netCod.toStringAsFixed(0)}',
                                                  style: AppTypography
                                                      .bodySmall
                                                      .copyWith(
                                                    color: AppColors.info,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: StatusBadge(
                                                    status: statusEnum,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  '${o.orderDate.day}/${o.orderDate.month}/${o.orderDate.year}',
                                                  style: AppTypography
                                                      .caption
                                                      .copyWith(
                                                    color: AppColors
                                                        .textTertiary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),

                                    // Summary Footer Row
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.xl,
                                        vertical: 12,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(20),
                                          bottomRight: Radius.circular(20),
                                        ),
                                        border: Border(
                                          top: BorderSide(
                                            color: AppColors.border,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Total (${filteredOrders.length} entries)',
                                            style:
                                                AppTypography.bodySmall.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            'Total Net COD: Rs. ${filteredTotalNet.toStringAsFixed(0)}',
                                            style:
                                                AppTypography.bodySmall.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _mobileLedgerList(List<dynamic> orders, double totalNet) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
          child: Row(
            children: [
              Expanded(child: Text('${orders.length} ${orders.length == 1 ? 'entry' : 'entries'}', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
              Text('Net: Rs. ${totalNet.toStringAsFixed(0)}', style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => _mobileLedgerCard(orders[index]),
        ),
      ],
    );
  }

  Widget _mobileLedgerCard(dynamic order) {
    final status = OrderStatus.fromString(order.status);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(order.displayId, style: AppTypography.mono.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 2),
            Text(order.customerName.isEmpty ? 'Unnamed customer' : order.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.h4.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ])),
          StatusBadge(status: status, fontSize: 10),
        ]),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(builder: (context, constraints) {
          final cellWidth = constraints.maxWidth >= 360 ? (constraints.maxWidth - AppSpacing.sm) / 2 : constraints.maxWidth;
          return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            SizedBox(width: cellWidth, child: _ledgerDetail('City', order.city.isEmpty ? 'Not specified' : order.city)),
            SizedBox(width: cellWidth, child: _ledgerDetail('Order date', '${order.orderDate.day}/${order.orderDate.month}/${order.orderDate.year}')),
            SizedBox(width: cellWidth, child: _ledgerDetail('COD amount', 'Rs. ${order.codAmount.toStringAsFixed(0)}', color: AppColors.success)),
            SizedBox(width: cellWidth, child: _ledgerDetail('Delivery charge', 'Rs. ${order.deliveryCharges.toStringAsFixed(0)}')),
            SizedBox(width: cellWidth, child: _ledgerDetail('Net COD', 'Rs. ${order.netCod.toStringAsFixed(0)}', color: AppColors.info)),
          ]);
        }),
      ]),
    );
  }

  Widget _ledgerDetail(String label, String value, {Color? color}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTypography.caption.copyWith(color: AppColors.textTertiary, fontSize: 10, letterSpacing: 0.3)),
    const SizedBox(height: 1),
    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall.copyWith(color: color ?? AppColors.textPrimary, fontWeight: FontWeight.w500)),
  ]);

  Widget _header(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          color: AppColors.textTertiary,
          fontSize: 11,
        ),
      ),
    );
  }
}
