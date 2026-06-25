import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';

enum ProductDeleteAction {
  deleted,
  archived,
}

class ProductDeleteResult {
  final ProductDeleteAction action;
  final String message;

  const ProductDeleteResult({
    required this.action,
    required this.message,
  });
}

class ProductRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _productsCollection {
    return _firestore.collection('products');
  }

  CollectionReference<Map<String, dynamic>> get _batchesCollection {
    return _firestore.collection('batches');
  }

  Future<ProductModel?> getProductById(String productId) async {
    try {
      final doc = await _productsCollection.doc(productId).get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return ProductModel.fromMap(
        doc.id,
        doc.data()!,
      );
    } catch (e) {
      throw Exception('Gagal mengambil data produk: $e');
    }
  }

  Stream<List<ProductModel>> getProductsStream({
    bool includeInactive = true,
  }) {
    return _productsCollection.snapshots().map((snapshot) {
      final products = snapshot.docs.map((doc) {
        return ProductModel.fromMap(
          doc.id,
          doc.data(),
        );
      }).where((product) {
        if (includeInactive) return true;
        return product.isActive;
      }).toList();

      products.sort((a, b) => a.name.compareTo(b.name));

      return products;
    });
  }

  Stream<List<ProductModel>> getActiveProductsStream() {
    return getProductsStream(includeInactive: false);
  }

  Future<List<ProductModel>> getProducts({
    bool includeInactive = true,
  }) async {
    try {
      final snapshot = await _productsCollection.get();

      final products = snapshot.docs.map((doc) {
        return ProductModel.fromMap(
          doc.id,
          doc.data(),
        );
      }).where((product) {
        if (includeInactive) return true;
        return product.isActive;
      }).toList();

      products.sort((a, b) => a.name.compareTo(b.name));

      return products;
    } catch (e) {
      throw Exception('Gagal mengambil daftar produk: $e');
    }
  }

  Future<List<ProductModel>> getActiveProducts() async {
    return getProducts(includeInactive: false);
  }

  Future<void> createProduct({
    required String name,
    required String code,
    required String category,
    required String unit,
    required int minimumStock,
    required bool isActive,
  }) async {
    final cleanedName = name.trim();
    final cleanedCategory = category.trim().isEmpty ? 'Beras' : category.trim();
    final cleanedUnit = unit.trim().isEmpty ? 'karung' : unit.trim();

    if (cleanedName.isEmpty) {
      throw Exception('Nama produk tidak boleh kosong.');
    }

    if (minimumStock < 0) {
      throw Exception('Minimum stok tidak boleh kurang dari 0.');
    }

    final cleanedCode = code.trim().isEmpty
        ? await _generateUniqueProductCode(cleanedName)
        : _normalizeCode(code);

    await _ensureProductCodeIsUnique(code: cleanedCode);

    final docRef = _productsCollection.doc();
    final now = Timestamp.now();

    await docRef.set({
      'id': docRef.id,
      'name': cleanedName,
      'code': cleanedCode,
      'category': cleanedCategory,
      'unit': cleanedUnit,
      'minimumStock': minimumStock,
      'minStock': minimumStock,
      'totalStock': 0,
      'isActive': isActive,
      'isDeleted': false,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> updateProduct({
    required String productId,
    required String name,
    required String code,
    required String category,
    required String unit,
    required int minimumStock,
    required bool isActive,
  }) async {
    final cleanedName = name.trim();
    final cleanedCategory = category.trim().isEmpty ? 'Beras' : category.trim();
    final cleanedUnit = unit.trim().isEmpty ? 'karung' : unit.trim();

    if (productId.trim().isEmpty) {
      throw Exception('ID produk tidak valid.');
    }

    if (cleanedName.isEmpty) {
      throw Exception('Nama produk tidak boleh kosong.');
    }

    if (minimumStock < 0) {
      throw Exception('Minimum stok tidak boleh kurang dari 0.');
    }

    final cleanedCode = code.trim().isEmpty
        ? await _generateUniqueProductCode(
            cleanedName,
            excludedProductId: productId,
          )
        : _normalizeCode(code);

    await _ensureProductCodeIsUnique(
      code: cleanedCode,
      excludedProductId: productId,
    );

    await _productsCollection.doc(productId).update({
      'id': productId,
      'name': cleanedName,
      'code': cleanedCode,
      'category': cleanedCategory,
      'unit': cleanedUnit,
      'minimumStock': minimumStock,
      'minStock': minimumStock,
      'isActive': isActive,
      'isDeleted': false,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> updateProductActiveStatus({
    required String productId,
    required bool isActive,
  }) async {
    await _productsCollection.doc(productId).update({
      'isActive': isActive,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> increaseTotalStock({
    required String productId,
    required int qty,
  }) async {
    if (qty <= 0) {
      throw Exception('Jumlah stok harus lebih dari 0.');
    }

    await _productsCollection.doc(productId).update({
      'totalStock': FieldValue.increment(qty),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> decreaseTotalStock({
    required String productId,
    required int qty,
  }) async {
    if (qty <= 0) {
      throw Exception('Jumlah stok harus lebih dari 0.');
    }

    await _productsCollection.doc(productId).update({
      'totalStock': FieldValue.increment(-qty),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> syncTotalStockFromBatches({
    required String productId,
  }) async {
    try {
      final snapshot = await _batchesCollection
          .where('productId', isEqualTo: productId)
          .get();

      int totalStock = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final status = (data['status'] ?? '').toString().toLowerCase().trim();
        final remainingQtyRaw = data['remainingQty'] ?? 0;

        int remainingQty = 0;

        if (remainingQtyRaw is int) {
          remainingQty = remainingQtyRaw;
        } else if (remainingQtyRaw is double) {
          remainingQty = remainingQtyRaw.toInt();
        } else if (remainingQtyRaw is num) {
          remainingQty = remainingQtyRaw.toInt();
        }

        if (status == 'active' && remainingQty > 0) {
          totalStock += remainingQty;
        }
      }

      await _productsCollection.doc(productId).update({
        'totalStock': totalStock,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Gagal sinkronisasi total stok produk: $e');
    }
  }

  Future<ProductDeleteResult> deleteProduct({
    required String productId,
  }) async {
    if (productId.trim().isEmpty) {
      throw Exception('ID produk tidak valid.');
    }

    final usedBatchSnapshot = await _batchesCollection
        .where('productId', isEqualTo: productId)
        .limit(1)
        .get();

    if (usedBatchSnapshot.docs.isNotEmpty) {
      await _productsCollection.doc(productId).update({
        'isActive': false,
        'isDeleted': true,
        'deletedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      return const ProductDeleteResult(
        action: ProductDeleteAction.archived,
        message:
            'Produk sudah pernah digunakan pada batch, sehingga tidak dihapus permanen dan hanya dinonaktifkan.',
      );
    }

    await _productsCollection.doc(productId).delete();

    return const ProductDeleteResult(
      action: ProductDeleteAction.deleted,
      message: 'Produk berhasil dihapus permanen.',
    );
  }

  Future<void> _ensureProductCodeIsUnique({
    required String code,
    String? excludedProductId,
  }) async {
    final normalizedCode = _normalizeCode(code);

    final snapshot = await _productsCollection
        .where('code', isEqualTo: normalizedCode)
        .get();

    for (final doc in snapshot.docs) {
      if (excludedProductId != null && doc.id == excludedProductId) {
        continue;
      }

      throw Exception('Kode produk "$normalizedCode" sudah digunakan.');
    }
  }

  Future<String> _generateUniqueProductCode(
    String name, {
    String? excludedProductId,
  }) async {
    final normalizedName = _normalizeCode(name);
    final baseCode = normalizedName.isEmpty ? 'PRODUCT' : normalizedName;

    String candidateCode = baseCode;
    int counter = 2;

    while (await _isProductCodeExists(
      code: candidateCode,
      excludedProductId: excludedProductId,
    )) {
      candidateCode = '${baseCode}_$counter';
      counter++;
    }

    return candidateCode;
  }

  Future<bool> _isProductCodeExists({
    required String code,
    String? excludedProductId,
  }) async {
    final snapshot =
        await _productsCollection.where('code', isEqualTo: code).get();

    for (final doc in snapshot.docs) {
      if (excludedProductId != null && doc.id == excludedProductId) {
        continue;
      }

      return true;
    }

    return false;
  }

  String _normalizeCode(String value) {
    final cleaned = value
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return cleaned;
  }
}
