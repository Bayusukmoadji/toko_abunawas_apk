import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createStockInTransaction({
    required String productId,
    required String productName,
    required String batchId,
    required String batchCode,
    required int qty,
    required String unit,
    required String performedBy,
    required String performedByName,
    required String notes,
  }) async {
    await _firestore.collection('transactions').add({
      'type': 'stock_in',
      'productId': productId,
      'productName': productName,
      'batchId': batchId,
      'batchCode': batchCode,
      'qty': qty,
      'unit': unit,
      'performedBy': performedBy,
      'performedByName': performedByName,
      'notes': notes,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> createStockOutTransaction({
    required String productId,
    required String productName,
    required String batchId,
    required String batchCode,
    required int qty,
    required String unit,
    required String performedBy,
    required String performedByName,
    required String notes,
  }) async {
    await _firestore.collection('transactions').add({
      'type': 'stock_out',
      'productId': productId,
      'productName': productName,
      'batchId': batchId,
      'batchCode': batchCode,
      'qty': qty,
      'unit': unit,
      'performedBy': performedBy,
      'performedByName': performedByName,
      'notes': notes,
      'createdAt': Timestamp.now(),
    });
  }

  Stream<List<TransactionModel>> getTransactionsStream() {
    return _firestore
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TransactionModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }
}
