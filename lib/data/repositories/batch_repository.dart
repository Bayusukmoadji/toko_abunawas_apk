import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/batch_model.dart';

class BatchRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, String>> createBatch({
    required String productId,
    required String productName,
    required DateTime receivedAt,
    required int qty,
    required String unit,
    required String storageLocation,
    required String createdBy,
    required String createdByName,
    required String notes,
  }) async {
    final batchRef = _firestore.collection('batches').doc();
    final counterRef = _firestore.collection('counters').doc('batches');

    final result = await _firestore.runTransaction<Map<String, String>>(
      (transaction) async {
        final counterSnapshot = await transaction.get(counterRef);

        int lastNumber = 0;

        if (counterSnapshot.exists && counterSnapshot.data() != null) {
          lastNumber = counterSnapshot.data()!['lastNumber'] ?? 0;
        }

        final nextNumber = lastNumber + 1;
        final batchCode = 'BT-${nextNumber.toString().padLeft(4, '0')}';
        final now = Timestamp.now();

        transaction.set(
          counterRef,
          {
            'lastNumber': nextNumber,
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );

        transaction.set(batchRef, {
          'productId': productId,
          'productName': productName,
          'batchCode': batchCode,
          'receivedAt': Timestamp.fromDate(receivedAt),
          'initialQty': qty,
          'remainingQty': qty,
          'unit': unit,
          'qrCodeValue': batchRef.id,
          'status': 'active',
          'storageLocation': storageLocation,
          'createdBy': createdBy,
          'createdByName': createdByName,
          'notes': notes,
          'createdAt': now,
          'updatedAt': now,
        });

        return {
          'batchId': batchRef.id,
          'batchCode': batchCode,
        };
      },
    );

    return result;
  }

  Stream<List<BatchModel>> getBatchesStream() {
    return _firestore
        .collection('batches')
        .orderBy('receivedAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return BatchModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Future<BatchModel?> getBatchById(String batchId) async {
    final doc = await _firestore.collection('batches').doc(batchId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return BatchModel.fromMap(doc.id, doc.data()!);
  }

  Future<BatchModel?> getBatchByQrValue(String qrCodeValue) async {
    final doc = await _firestore.collection('batches').doc(qrCodeValue).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return BatchModel.fromMap(doc.id, doc.data()!);
  }

  Future<BatchModel?> getOldestActiveBatchByProductId(String productId) async {
    final snapshot = await _firestore
        .collection('batches')
        .where('productId', isEqualTo: productId)
        .get();

    final batches = snapshot.docs
        .map((doc) => BatchModel.fromMap(doc.id, doc.data()))
        .where((batch) => batch.status == 'active' && batch.remainingQty > 0)
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
    final batchRef = _firestore.collection('batches').doc(batchId);

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
