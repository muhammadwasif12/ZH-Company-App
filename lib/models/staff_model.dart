class StaffModel {
  final String id;
  final String userId;
  final String staffCode;
  final String name;
  final String? email;
  final String? phone;
  final String commissionType; // 'fixed' or 'percentage'
  final double commissionValue;
  final double returnPenalty;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StaffModel({
    required this.id,
    required this.userId,
    required this.staffCode,
    required this.name,
    this.email,
    this.phone,
    this.commissionType = 'fixed',
    this.commissionValue = 100.0,
    this.returnPenalty = 100.0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      staffCode: json['staff_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      commissionType: json['commission_type'] as String? ?? 'fixed',
      commissionValue: (json['commission_value'] as num?)?.toDouble() ?? 100.0,
      returnPenalty: (json['return_penalty'] as num?)?.toDouble() ?? 100.0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'staff_code': staffCode,
      'name': name,
      'email': email,
      'phone': phone,
      'commission_type': commissionType,
      'commission_value': commissionValue,
      'return_penalty': returnPenalty,
      'is_active': isActive,
    };
  }

  StaffModel copyWith({
    String? id,
    String? userId,
    String? staffCode,
    String? name,
    String? email,
    String? phone,
    String? commissionType,
    double? commissionValue,
    double? returnPenalty,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StaffModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      staffCode: staffCode ?? this.staffCode,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      commissionType: commissionType ?? this.commissionType,
      commissionValue: commissionValue ?? this.commissionValue,
      returnPenalty: returnPenalty ?? this.returnPenalty,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
