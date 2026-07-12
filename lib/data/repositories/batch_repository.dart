import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/batch_model.dart';

class BatchPageResult {
  final List<BatchModel> batches;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const BatchPageResult({
    required this.batches,
    required this.lastDocument,
    required this.hasMore,
  });
}

class BatchRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _batchesCollection {
    return _firestore.collection('batches');
  }

  CollectionReference<Map<String, dynamic>> get _countersCollection {
    return _firestore.collection('counters');
  }

  String _formatDateKey(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year$month$day';
  }

  String _formatSequence(int value) {
    return value.toString().padLeft(3, '0');
  }

  String _normalizeProductCode(String productCode) {
    return productCode.trim().toUpperCase();
  }

  String _normalizeCounterId(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return normalized.isEmpty ? 'unknown' : normalized;
  }

  String _normalizeLocation(String value) {
    return value.trim().toUpperCase();
  }

  String _buildBatchCode({
    required DateTime receivedAt,
    required String productCode,
    required int sequenceNumber,
  }) {
    final dateKey = _formatDateKey(receivedAt);
    final cleanProductCode = _normalizeProductCode(productCode);
    final sequence = _formatSequence(sequenceNumber);

    return 'BATCH-$dateKey-$cleanProductCode-$sequence';
  }

  int _extractSequenceFromBatchCode(String batchCode) {
    final parts = batchCode.trim().split('-');

    if (parts.isEmpty) {
      return 0;
    }

    final lastPart = parts.last.trim();

    return int.tryParse(lastPart) ?? 0;
  }

  bool _isBatchEmpty(BatchModel batch) {
    final normalizedStatus = batch.status.toLowerCase().trim();

    return normalizedStatus == 'empty' ||
        normalizedStatus == 'depleted' ||
        batch.remainingQty <= 0;
  }

  Future<int> _getExistingMaxSequenceByProduct({
    required String productId,
  }) async {
    final snapshot =
        await _batchesCollection.where('productId', isEqualTo: productId).get();

    int maxSequence = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final batchCode = (data['batchCode'] ?? doc.id).toString();
      final sequence = _extractSequenceFromBatchCode(batchCode);

      if (sequence > maxSequence) {
        maxSequence = sequence;
      }
    }

    return maxSequence;
  }

  Future<Set<String>> getOccupiedStorageLocations() async {
    final snapshot =
        await _batchesCollection.where('status', isEqualTo: 'active').get();

    final locations = <String>{};

    for (final doc in snapshot.docs) {
      final batch = BatchModel.fromMap(doc.id, doc.data());

      if (_isBatchEmpty(batch)) {
        continue;
      }

      final location = _normalizeLocation(batch.storageLocation);

      if (location.isNotEmpty) {
        locations.add(location);
      }
    }

    return locations;
  }

  Future<Map<String, String>> createBatch({
    required String productId,
    required String productCode,
    required String productName,
    required DateTime receivedAt,
    required int qty,
    required String unit,
    required String storageLocation,
    required String createdBy,
    required String createdByName,
    required String notes,
  }) async {
    final cleanProductCode = _normalizeProductCode(productCode);
    final cleanLocation = _normalizeLocation(storageLocation);

    if (productId.trim().isEmpty) {
      throw Exception('Product ID tidak valid.');
    }

    if (cleanProductCode.isEmpty) {
      throw Exception('Kode produk tidak valid.');
    }

    if (qty <= 0) {
      throw Exception('Jumlah stok masuk harus lebih dari 0.');
    }

    if (cleanLocation.isEmpty) {
      throw Exception('Lokasi batch wajib diisi.');
    }

    final counterId = 'batch_sequence_${_normalizeCounterId(productId)}';
    final counterRef = _countersCollection.doc(counterId);

    final existingMaxSequence = await _getExistingMaxSequenceByProduct(
      productId: productId,
    );

    final result = await _firestore.runTransaction<Map<String, String>>(
      (transaction) async {
        final counterSnapshot = await transaction.get(counterRef);

        int lastNumber = existingMaxSequence;

        if (counterSnapshot.exists && counterSnapshot.data() != null) {
          final data = counterSnapshot.data()!;
          final counterLastNumber = data['lastNumber'] ?? 0;

          if (counterLastNumber is int) {
            lastNumber = counterLastNumber > existingMaxSequence
                ? counterLastNumber
                : existingMaxSequence;
          }
        }

        final nextNumber = lastNumber + 1;

        final batchCode = _buildBatchCode(
          receivedAt: receivedAt,
          productCode: cleanProductCode,
          sequenceNumber: nextNumber,
        );

        final batchRef = _batchesCollection.doc(batchCode);
        final existingBatchSnapshot = await transaction.get(batchRef);

        if (existingBatchSnapshot.exists) {
          throw Exception(
            'Kode batch $batchCode sudah ada. Silakan coba simpan ulang.',
          );
        }

        final now = Timestamp.now();

        transaction.set(
          counterRef,
          {
            'id': counterId,
            'productId': productId,
            'productCode': cleanProductCode,
            'lastNumber': nextNumber,
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );

        transaction.set(batchRef, {
          'id': batchCode,
          'productId': productId,
          'productName': productName,
          'productCode': cleanProductCode,
          'batchCode': batchCode,
          'receivedAt': Timestamp.fromDate(receivedAt),
          'initialQty': qty,
          'remainingQty': qty,
          'unit': unit,
          'qrCodeValue': batchCode,
          'status': 'active',
          'storageLocation': cleanLocation,
          'createdBy': createdBy,
          'createdByName': createdByName,
          'notes': notes,
          'createdAt': now,
          'updatedAt': now,
        });

        return {
          'batchId': batchCode,
          'batchCode': batchCode,
          'qrCodeValue': batchCode,
        };
      },
    );

    return result;
  }

  Stream<List<BatchModel>> getBatchesStream() {
    return _batchesCollection
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return BatchModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Future<BatchPageResult> getBatchesPage({
    String statusFilter = 'Aktif',
    DateTime? receivedDate,
    int limit = 30,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    Query<Map<String, dynamic>> query = _batchesCollection;

    if (statusFilter == 'Aktif') {
      query = query.where('status', isEqualTo: 'active');
    } else if (statusFilter == 'Habis') {
      query = query.where('status', whereIn: ['empty', 'depleted']);
    }

    if (receivedDate != null) {
      final startDate = DateTime(
        receivedDate.year,
        receivedDate.month,
        receivedDate.day,
      );

      final endDate = DateTime(
        receivedDate.year,
        receivedDate.month,
        receivedDate.day,
        23,
        59,
        59,
      );

      query = query
          .where(
            'receivedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where(
            'receivedAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate),
          );
    }

    query = query.orderBy('receivedAt', descending: true).limit(limit);

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.get();

    final batches = snapshot.docs.map((doc) {
      return BatchModel.fromMap(doc.id, doc.data());
    }).toList();

    return BatchPageResult(
      batches: batches,
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<BatchModel?> getBatchById(String batchId) async {
    final doc = await _batchesCollection.doc(batchId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return BatchModel.fromMap(doc.id, doc.data()!);
  }

  Future<BatchModel?> getBatchByQrValue(String qrCodeValue) async {
    final cleanQrValue = qrCodeValue.trim();

    if (cleanQrValue.isEmpty) {
      return null;
    }

    final docById = await _batchesCollection.doc(cleanQrValue).get();

    if (docById.exists && docById.data() != null) {
      return BatchModel.fromMap(docById.id, docById.data()!);
    }

    final qrSnapshot = await _batchesCollection
        .where('qrCodeValue', isEqualTo: cleanQrValue)
        .limit(1)
        .get();

    if (qrSnapshot.docs.isNotEmpty) {
      final doc = qrSnapshot.docs.first;
      return BatchModel.fromMap(doc.id, doc.data());
    }

    final batchCodeSnapshot = await _batchesCollection
        .where('batchCode', isEqualTo: cleanQrValue)
        .limit(1)
        .get();

    if (batchCodeSnapshot.docs.isNotEmpty) {
      final doc = batchCodeSnapshot.docs.first;
      return BatchModel.fromMap(doc.id, doc.data());
    }

    return null;
  }

  Future<BatchModel?> getOldestActiveBatchByProductId(String productId) async {
    final snapshot =
        await _batchesCollection.where('productId', isEqualTo: productId).get();

    final batches = snapshot.docs
        .map((doc) => BatchModel.fromMap(doc.id, doc.data()))
        .where((batch) => !_isBatchEmpty(batch))
        .toList();

    if (batches.isEmpty) {
      return null;
    }

    batches.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));

    return batches.first;
  }

  Future<void> decreaseBatchStock({
    required String batchId,
    required int qty,
  }) async {
    final batchRef = _batchesCollection.doc(batchId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(batchRef);

      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Batch tidak ditemukan.');
      }

      final data = snapshot.data()!;
      final currentRemainingQty = data['remainingQty'] ?? 0;

      if (currentRemainingQty < qty) {
        throw Exception('Jumlah keluar melebihi sisa stok batch.');
      }

      final newRemainingQty = currentRemainingQty - qty;

      transaction.update(batchRef, {
        'remainingQty': newRemainingQty,
        'status': newRemainingQty == 0 ? 'empty' : 'active',
        'updatedAt': Timestamp.now(),
      });
    });
  }
}
