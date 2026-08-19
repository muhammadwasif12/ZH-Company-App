class OrderModel {
  final String id;
  final String? orderId; // Auto-generated display ID like "BO-00001"
  final DateTime orderDate;
  /// Null when the originating staff account was permanently deleted.
  final String? staffId;
  final String? staffName;
  final String? staffCode;
  final String customerName;
  final String customerMobile;
  final String? customerWhatsapp;
  final String address;
  final String city;
  final String productName;
  final int quantity;
  final double codAmount;
  final double deliveryCharges;
  final double discount;
  final String? courierCompany;
  final String? trackingNumber;
  final String status;
  final String? notes;
  final String? proofImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderModel({
    required this.id,
    this.orderId,
    required this.orderDate,
    this.staffId,
    this.staffName,
    this.staffCode,
    required this.customerName,
    required this.customerMobile,
    this.customerWhatsapp,
    required this.address,
    required this.city,
    required this.productName,
    this.quantity = 1,
    required this.codAmount,
    this.deliveryCharges = 0,
    this.discount = 0,
    this.courierCompany,
    this.trackingNumber,
    this.status = 'pending',
    this.notes,
    this.proofImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  double get totalAmount => codAmount + deliveryCharges - discount;
  double get netCod => codAmount - discount;
  String get displayId => orderId ?? (id.length >= 8 ? id.substring(0, 8) : id);

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String?,
      orderDate: DateTime.parse(json['order_date'] as String),
      staffId: json['staff_id'] as String?,
      staffName: json['staff_name'] as String?,
      staffCode: json['staff_code'] as String?,
      customerName: json['customer_name'] as String? ?? '',
      customerMobile: json['customer_mobile'] as String? ?? '',
      customerWhatsapp: json['customer_whatsapp'] as String?,
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      codAmount: (json['cod_amount'] as num?)?.toDouble() ?? 0,
      deliveryCharges: (json['delivery_charges'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      courierCompany: json['courier_company'] as String?,
      trackingNumber: json['tracking_number'] as String?,
      status: json['status'] as String? ?? 'pending',
      notes: json['notes'] as String?,
      proofImageUrl: json['proof_image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_date': orderDate.toIso8601String(),
      'staff_id': staffId,
      'staff_name': staffName,
      'staff_code': staffCode,
      'customer_name': customerName,
      'customer_mobile': customerMobile,
      'customer_whatsapp': customerWhatsapp,
      'address': address,
      'city': city,
      'product_name': productName,
      'quantity': quantity,
      'cod_amount': codAmount,
      'delivery_charges': deliveryCharges,
      'discount': discount,
      'courier_company': courierCompany,
      'tracking_number': trackingNumber,
      'status': status,
      'notes': notes,
      'proof_image_url': proofImageUrl,
    };
  }

  OrderModel copyWith({
    String? id,
    String? orderId,
    DateTime? orderDate,
    String? staffId,
    String? staffName,
    String? staffCode,
    String? customerName,
    String? customerMobile,
    String? customerWhatsapp,
    String? address,
    String? city,
    String? productName,
    int? quantity,
    double? codAmount,
    double? deliveryCharges,
    double? discount,
    String? courierCompany,
    String? trackingNumber,
    String? status,
    String? notes,
    String? proofImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      orderDate: orderDate ?? this.orderDate,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      staffCode: staffCode ?? this.staffCode,
      customerName: customerName ?? this.customerName,
      customerMobile: customerMobile ?? this.customerMobile,
      customerWhatsapp: customerWhatsapp ?? this.customerWhatsapp,
      address: address ?? this.address,
      city: city ?? this.city,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      codAmount: codAmount ?? this.codAmount,
      deliveryCharges: deliveryCharges ?? this.deliveryCharges,
      discount: discount ?? this.discount,
      courierCompany: courierCompany ?? this.courierCompany,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
