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
    return _firestore.collection(
      'transactions',
    );
  }

  String _normalizeText(String value) {
    return value.trim();
  }

  /// ============================================================
  /// STOCK IN
  /// ============================================================
  ///
  /// Transaksi stok masuk tetap menggunakan struktur lama.
  /// transactionGroupId tidak wajib karena satu stok masuk
  /// menghasilkan satu batch.
  Future<String> createStockInTransaction({
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
    if (qty <= 0) {
      throw Exception(
        'Jumlah stok masuk harus lebih dari 0.',
      );
    }

    final DocumentReference<Map<String, dynamic>> transactionRef =
        _transactionsCollection.doc();

    await transactionRef.set(
      <String, dynamic>{
        'type': 'stock_in',
        'productId': _normalizeText(productId),
        'productName': _normalizeText(productName),
        'batchId': _normalizeText(batchId),
        'batchCode': _normalizeText(batchCode),
        'qty': qty,
        'unit': _normalizeText(unit),
        'performedBy': _normalizeText(performedBy),
        'performedByName': _normalizeText(
          performedByName,
        ),
        'notes': _normalizeText(notes),
        'createdAt': Timestamp.now(),
      },
    );

    return transactionRef.id;
  }

  /// ============================================================
  /// STOCK OUT LEGACY / SINGLE BATCH
  /// ============================================================
  ///
  /// Fungsi ini dipertahankan untuk kompatibilitas apabila
  /// masih ada bagian lama aplikasi yang memanggil
  /// TransactionRepository secara langsung.
  ///
  /// Proses FIFO lintas-batch utama menggunakan
  /// StockOutRepository.
  Future<String> createStockOutTransaction({
    required String productId,
    required String productName,
    required String batchId,
    required String batchCode,
    required int qty,
    required String unit,
    required String performedBy,
    required String performedByName,
    required String notes,
    String? transactionGroupId,
    String? storageLocation,
    int? remainingQtyBefore,
    int? remainingQtyAfter,
    int? totalStockAfter,
  }) async {
    if (qty <= 0) {
      throw Exception(
        'Jumlah stok keluar harus lebih dari 0.',
      );
    }

    final DocumentReference<Map<String, dynamic>> transactionRef =
        _transactionsCollection.doc();

    final String resolvedGroupId = transactionGroupId?.trim().isNotEmpty == true
        ? transactionGroupId!.trim()
        : transactionRef.id;

    final Map<String, dynamic> data = <String, dynamic>{
      'id': transactionRef.id,
      'type': 'stock_out',
      'productId': _normalizeText(productId),
      'productName': _normalizeText(productName),
      'batchId': _normalizeText(batchId),
      'batchCode': _normalizeText(batchCode),
      'qty': qty,
      'unit': _normalizeText(unit),
      'performedBy': _normalizeText(performedBy),
      'performedByName': _normalizeText(
        performedByName,
      ),
      'notes': _normalizeText(notes),
      'transactionGroupId': resolvedGroupId,
      'createdAt': Timestamp.now(),
    };

    if (storageLocation != null && storageLocation.trim().isNotEmpty) {
      data['storageLocation'] = storageLocation.trim();
    }

    if (remainingQtyBefore != null) {
      data['remainingQtyBefore'] = remainingQtyBefore;
    }

    if (remainingQtyAfter != null) {
      data['remainingQtyAfter'] = remainingQtyAfter;
    }

    if (totalStockAfter != null) {
      data['totalStockAfter'] = totalStockAfter;
    }

    await transactionRef.set(data);

    return transactionRef.id;
  }

  /// ============================================================
  /// STREAM
  /// ============================================================

  Stream<List<TransactionModel>> getTransactionsStream() {
    return _transactionsCollection
        .orderBy(
          'createdAt',
          descending: true,
        )
        .limit(100)
        .snapshots()
        .map(
      (
        QuerySnapshot<Map<String, dynamic>> snapshot,
      ) {
        return snapshot.docs.map(
          (
            QueryDocumentSnapshot<Map<String, dynamic>> document,
          ) {
            return TransactionModel.fromMap(
              document.id,
              document.data(),
            );
          },
        ).toList();
      },
    );
  }

  /// ============================================================
  /// PAGINATION
  /// ============================================================

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
      query = query.where(
        'productId',
        isEqualTo: productId.trim(),
      );
    }

    if (type != null && type.trim().isNotEmpty) {
      query = query.where(
        'type',
        isEqualTo: type.trim(),
      );
    }

    if (startDate != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(
          startDate,
        ),
      );
    }

    if (endDate != null) {
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: Timestamp.fromDate(
          endDate,
        ),
      );
    }

    query = query
        .orderBy(
          'createdAt',
          descending: true,
        )
        .limit(limit);

    if (startAfterDocument != null) {
      query = query.startAfterDocument(
        startAfterDocument,
      );
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

    final List<TransactionModel> transactions = snapshot.docs.map(
      (
        QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
        return TransactionModel.fromMap(
          document.id,
          document.data(),
        );
      },
    ).toList();

    return TransactionPageResult(
      transactions: transactions,
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  /// ============================================================
  /// REPORT
  /// ============================================================

  Future<List<TransactionModel>> getTransactionsForReport({
    String? productId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    int maxLimit = 5000,
  }) async {
    Query<Map<String, dynamic>> query = _transactionsCollection;

    if (productId != null && productId.trim().isNotEmpty) {
      query = query.where(
        'productId',
        isEqualTo: productId.trim(),
      );
    }

    if (type != null && type.trim().isNotEmpty) {
      query = query.where(
        'type',
        isEqualTo: type.trim(),
      );
    }

    if (startDate != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(
          startDate,
        ),
      );
    }

    if (endDate != null) {
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: Timestamp.fromDate(
          endDate,
        ),
      );
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query
        .orderBy(
          'createdAt',
          descending: true,
        )
        .limit(maxLimit)
        .get();

    return snapshot.docs.map(
      (
        QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
        return TransactionModel.fromMap(
          document.id,
          document.data(),
        );
      },
    ).toList();
  }

  /// Mengambil seluruh detail transaksi yang berasal
  /// dari satu permintaan stok keluar lintas-batch.
  ///
  /// Tidak menggunakan query Firestore tambahan yang
  /// memerlukan composite index karena data yang baru
  /// sudah mempunyai field transactionGroupId.
  Future<List<TransactionModel>> getTransactionsByGroupId(
    String transactionGroupId,
  ) async {
    final String cleanGroupId = transactionGroupId.trim();

    if (cleanGroupId.isEmpty) {
      return <TransactionModel>[];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _transactionsCollection
            .where(
              'transactionGroupId',
              isEqualTo: cleanGroupId,
            )
            .get();

    final List<TransactionModel> result = snapshot.docs.map(
      (
        QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
        return TransactionModel.fromMap(
          document.id,
          document.data(),
        );
      },
    ).toList();

    result.sort(
      (
        TransactionModel first,
        TransactionModel second,
      ) {
        return first.createdAt.compareTo(
          second.createdAt,
        );
      },
    );

    return result;
  }
}
