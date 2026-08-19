class ProductModel {
  final String id;
  final String name;
  final String? sku;
  final String? description;
  final double price;
  final double? costPrice;
  final int stockQuantity;
  final int lowStockThreshold;
  final String? category;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    required this.name,
    this.sku,
    this.description,
    required this.price,
    this.costPrice,
    this.stockQuantity = 0,
    this.lowStockThreshold = 10,
    this.category,
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => stockQuantity <= lowStockThreshold;
  bool get isOutOfStock => stockQuantity <= 0;
  double get profit => costPrice != null ? price - costPrice! : 0;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String?,
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      costPrice: (json['cost_price'] as num?)?.toDouble(),
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      lowStockThreshold: json['low_stock_threshold'] as int? ?? 10,
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sku': sku,
      'description': description,
      'price': price,
      'cost_price': costPrice,
      'stock_quantity': stockQuantity,
      'low_stock_threshold': lowStockThreshold,
      'category': category,
      'image_url': imageUrl,
      'is_active': isActive,
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? sku,
    String? description,
    double? price,
    double? costPrice,
    int? stockQuantity,
    int? lowStockThreshold,
    String? category,
    String? imageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      description: description ?? this.description,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
