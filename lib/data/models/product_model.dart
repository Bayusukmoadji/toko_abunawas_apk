class ProductModel {
  final String id;
  final String name;
  final String code;
  final String category;
  final String unit;
  final int minimumStock;
  final int totalStock;
  final bool isActive;

  ProductModel({
    required this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.unit,
    required this.minimumStock,
    required this.totalStock,
    required this.isActive,
  });

  factory ProductModel.fromMap(String id, Map<String, dynamic> map) {
    return ProductModel(
      id: id,
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      category: map['category'] ?? '',
      unit: map['unit'] ?? '',

      // Aman untuk field baru minimumStock dan field lama minStock
      minimumStock: _toInt(map['minimumStock'] ?? map['minStock']),

      // Total stok produk dari Firestore
      totalStock: _toInt(map['totalStock']),

      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'category': category,
      'unit': unit,
      'minimumStock': minimumStock,
      'totalStock': totalStock,
      'isActive': isActive,
    };
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is double) return value.toInt();

    if (value is num) return value.toInt();

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }
}
