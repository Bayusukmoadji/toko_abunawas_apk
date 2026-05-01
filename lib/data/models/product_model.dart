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
      minimumStock: map['minimumStock'] ?? 0,
      totalStock: map['totalStock'] ?? 0,
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
}
