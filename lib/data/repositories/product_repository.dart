import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';

class ProductRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ProductModel>> getActiveProducts() async {
    final snapshot = await _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) {
      return ProductModel.fromMap(doc.id, doc.data());
    }).toList();
  }

  Stream<List<ProductModel>> getActiveProductsStream() {
    return _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ProductModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Future<void> increaseTotalStock({
    required String productId,
    required int qty,
  }) async {
    await _firestore.collection('products').doc(productId).update({
      'totalStock': FieldValue.increment(qty),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> decreaseTotalStock({
    required String productId,
    required int qty,
  }) async {
    await _firestore.collection('products').doc(productId).update({
      'totalStock': FieldValue.increment(-qty),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> syncTotalStockFromBatches({
    required String productId,
  }) async {
    final snapshot = await _firestore
        .collection('batches')
        .where('productId', isEqualTo: productId)
        .get();

    int total = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final status = (data['status'] ?? '').toString().toLowerCase().trim();

      final remainingQtyRaw = data['remainingQty'];
      final remainingQty = _toInt(remainingQtyRaw);

      if (status == 'active' && remainingQty > 0) {
        total += remainingQty;
      }
    }

    await _firestore.collection('products').doc(productId).update({
      'totalStock': total,
      'updatedAt': Timestamp.now(),
    });
  }

  int _toInt(dynamic value) {
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
