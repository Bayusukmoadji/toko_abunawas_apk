import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ProductModel>> getActiveProducts() async {
    final snapshot = await _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => ProductModel.fromMap(doc.id, doc.data()))
        .toList();
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
}
