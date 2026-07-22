import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/transaction_model.dart';

class TransactionPageResult {
  final List<TransactionModel> transactions;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const TransactionPageResult({
    required this.transactions,
    required this.lastDocument,
    required this.hasMore,
  });
}

class TransactionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _transactionsCollection {
    return _firestore.collection('transactions');
  }

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
    await _transactionsCollection.add({
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
    await _transactionsCollection.add({
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
    return _transactionsCollection
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TransactionModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Stream<List<TransactionModel>> getTransactionsByDateRangeStream({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final cleanStartDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final cleanEndDate = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    return _transactionsCollection
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(cleanStartDate),
        )
        .where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(cleanEndDate),
        )
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TransactionModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Future<TransactionPageResult> getTransactionsPage({
    String? productId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    Query<Map<String, dynamic>> query = _transactionsCollection;

    if (productId != null && productId.trim().isNotEmpty) {
      query = query.where('productId', isEqualTo: productId.trim());
    }

    if (type != null && type.trim().isNotEmpty) {
      query = query.where('type', isEqualTo: type.trim());
    }

    if (startDate != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    query = query.orderBy('createdAt', descending: true).limit(limit);

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.get();

    final transactions = snapshot.docs.map((doc) {
      return TransactionModel.fromMap(doc.id, doc.data());
    }).toList();

    return TransactionPageResult(
      transactions: transactions,
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<List<TransactionModel>> getTransactionsForReport({
    String? productId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    int maxLimit = 5000,
  }) async {
    Query<Map<String, dynamic>> query = _transactionsCollection;

    if (productId != null && productId.trim().isNotEmpty) {
      query = query.where('productId', isEqualTo: productId.trim());
    }

    if (type != null && type.trim().isNotEmpty) {
      query = query.where('type', isEqualTo: type.trim());
    }

    if (startDate != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(maxLimit)
        .get();

    return snapshot.docs.map((doc) {
      return TransactionModel.fromMap(doc.id, doc.data());
    }).toList();
  }
}
