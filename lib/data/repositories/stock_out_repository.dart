import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/batch_model.dart';
import 'batch_repository.dart';

class _RetryStockOutException implements Exception {
  const _RetryStockOutException();
}

class _StockOutPreparation {
  final BatchModel scannedBatch;
  final BatchModel fifoBatch;
  final int actualTotalStock;
  final int cachedTotalStock;
  final Timestamp? productUpdatedAt;
  final Timestamp? batchUpdatedAt;

  const _StockOutPreparation({
    required this.scannedBatch,
    required this.fifoBatch,
    required this.actualTotalStock,
    required this.cachedTotalStock,
    required this.productUpdatedAt,
    required this.batchUpdatedAt,
  });
}

class StockOutRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final BatchRepository _batchRepository = BatchRepository();

  CollectionReference<Map<String, dynamic>> get _batchesCollection {
    return _firestore.collection('batches');
  }

  CollectionReference<Map<String, dynamic>> get _productsCollection {
    return _firestore.collection('products');
  }

  CollectionReference<Map<String, dynamic>> get _transactionsCollection {
    return _firestore.collection(
      'transactions',
    );
  }

  CollectionReference<Map<String, dynamic>> get _storageLocationsCollection {
    return _firestore.collection(
      'storage_locations',
    );
  }

  int _parseInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _normalizeLocation(String value) {
    return value.trim().toUpperCase();
  }

  Timestamp? _parseTimestamp(dynamic value) {
    return value is Timestamp ? value : null;
  }

  bool _areTimestampsEqual(
    Timestamp? first,
    Timestamp? second,
  ) {
    if (first == null && second == null) {
      return true;
    }

    if (first == null || second == null) {
      return false;
    }

    return first.seconds == second.seconds &&
        first.nanoseconds == second.nanoseconds;
  }

  bool _isBatchEligibleForFifo(
    BatchModel batch,
  ) {
    return batch.status.trim().toLowerCase() == 'active' &&
        batch.remainingQty > 0;
  }

  String _getBatchCodeForFifo(
    BatchModel batch,
  ) {
    final code = batch.batchCode.trim().toUpperCase();

    return code.isEmpty ? batch.id.trim().toUpperCase() : code;
  }

  int _extractSequenceFromBatchCode(
    String batchCode,
  ) {
    final parts = batchCode.trim().split('-');

    if (parts.isEmpty) {
      return 0;
    }

    return int.tryParse(
          parts.last.trim(),
        ) ??
        0;
  }

  int _compareBatchesForFifo(
    BatchModel first,
    BatchModel second,
  ) {
    final receivedAtComparison = first.receivedAt.compareTo(
      second.receivedAt,
    );

    if (receivedAtComparison != 0) {
      return receivedAtComparison;
    }

    final createdAtComparison = first.createdAt.compareTo(
      second.createdAt,
    );

    if (createdAtComparison != 0) {
      return createdAtComparison;
    }

    final firstCode = _getBatchCodeForFifo(first);

    final secondCode = _getBatchCodeForFifo(second);

    final firstSequence = _extractSequenceFromBatchCode(
      firstCode,
    );

    final secondSequence = _extractSequenceFromBatchCode(
      secondCode,
    );

    if (firstSequence > 0 &&
        secondSequence > 0 &&
        firstSequence != secondSequence) {
      return firstSequence.compareTo(
        secondSequence,
      );
    }

    final codeComparison = firstCode.compareTo(secondCode);

    if (codeComparison != 0) {
      return codeComparison;
    }

    return first.id.trim().toUpperCase().compareTo(
          second.id.trim().toUpperCase(),
        );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _getLocationZone(String location) {
    return _normalizeLocation(location).startsWith('X') ? 'backup' : 'main';
  }

  bool _isLocationOccupied(
    Map<String, dynamic>? data,
  ) {
    return data?['isOccupied'] == true;
  }

  String _getLockedBatchId(
    Map<String, dynamic>? data,
  ) {
    return (data?['batchId'] ?? '').toString().trim();
  }

  Map<String, dynamic> _buildFreeLocationData({
    required String location,
    required Timestamp now,
  }) {
    return {
      'id': location,
      'location': location,
      'zone': _getLocationZone(location),
      'isOccupied': false,
      'batchId': null,
      'batchCode': null,
      'productId': null,
      'productName': null,
      'remainingQty': 0,
      'occupiedAt': null,
      'releasedAt': now,
      'updatedAt': now,
    };
  }

  Future<_StockOutPreparation> _prepareStockOut({
    required String batchId,
  }) async {
    final batchDocument = await _batchesCollection.doc(batchId).get();

    if (!batchDocument.exists || batchDocument.data() == null) {
      throw Exception(
        'Batch tidak ditemukan.',
      );
    }

    final scannedBatch = BatchModel.fromMap(
      batchDocument.id,
      batchDocument.data()!,
    );

    if (!_isBatchEligibleForFifo(
      scannedBatch,
    )) {
      throw Exception(
        'Batch sudah tidak aktif atau '
        'stoknya telah habis.',
      );
    }

    final productId = scannedBatch.productId.trim();

    if (productId.isEmpty) {
      throw Exception(
        'Produk pada batch tidak valid.',
      );
    }

    final productDocument = await _productsCollection.doc(productId).get();

    if (!productDocument.exists || productDocument.data() == null) {
      throw Exception(
        'Produk tidak ditemukan.',
      );
    }

    final productData = productDocument.data()!;

    final productBatchesSnapshot = await _batchesCollection
        .where(
          'productId',
          isEqualTo: productId,
        )
        .get();

    final activeBatches = productBatchesSnapshot.docs
        .map(
          (document) => BatchModel.fromMap(
            document.id,
            document.data(),
          ),
        )
        .where(
          _isBatchEligibleForFifo,
        )
        .toList()
      ..sort(
        _compareBatchesForFifo,
      );

    if (activeBatches.isEmpty) {
      throw Exception(
        'Tidak ada batch aktif untuk '
        'produk ini.',
      );
    }

    final actualTotalStock = activeBatches.fold<int>(
      0,
      (total, batch) => total + batch.remainingQty,
    );

    return _StockOutPreparation(
      scannedBatch: scannedBatch,
      fifoBatch: activeBatches.first,
      actualTotalStock: actualTotalStock,
      cachedTotalStock: _parseInt(
        productData['totalStock'],
      ),
      productUpdatedAt: _parseTimestamp(
        productData['updatedAt'],
      ),
      batchUpdatedAt: _parseTimestamp(
        batchDocument.data()!['updatedAt'],
      ),
    );
  }

  Future<Map<String, dynamic>> processStockOut({
    required String batchId,
    required int qty,
    required String performedBy,
    required String performedByName,
    required String notes,
  }) async {
    final cleanBatchId = batchId.trim();

    final cleanPerformedBy = performedBy.trim();

    final cleanPerformedByName = performedByName.trim();

    final cleanNotes = notes.trim();

    if (cleanBatchId.isEmpty) {
      throw Exception(
        'ID batch tidak valid.',
      );
    }

    if (qty <= 0) {
      throw Exception(
        'Jumlah stok keluar harus '
        'lebih dari 0.',
      );
    }

    if (cleanPerformedBy.isEmpty) {
      throw Exception(
        'Data pengguna tidak valid.',
      );
    }

    await _batchRepository.synchronizeStorageLocationLocks(
      force: true,
    );

    const maximumAttempts = 5;

    for (var attempt = 1; attempt <= maximumAttempts; attempt++) {
      final preparation = await _prepareStockOut(
        batchId: cleanBatchId,
      );

      final scannedBatch = preparation.scannedBatch;

      final fifoBatch = preparation.fifoBatch;

      if (fifoBatch.id != scannedBatch.id) {
        final fifoDate = _formatDate(
          fifoBatch.receivedAt.toDate(),
        );

        final fifoLocation = fifoBatch.storageLocation.trim().isEmpty
            ? '-'
            : fifoBatch.storageLocation.trim();

        throw Exception(
          'Batch tidak sesuai urutan FIFO. '
          'Batch yang harus dikeluarkan '
          'terlebih dahulu adalah '
          '${fifoBatch.batchCode}, tanggal '
          'masuk $fifoDate, lokasi '
          '$fifoLocation, dengan sisa '
          '${fifoBatch.remainingQty} '
          '${fifoBatch.unit}.',
        );
      }

      if (qty > scannedBatch.remainingQty) {
        throw Exception(
          'Jumlah stok keluar melebihi '
          'sisa stok batch. Sisa stok '
          'saat ini adalah '
          '${scannedBatch.remainingQty} '
          '${scannedBatch.unit}.',
        );
      }

      if (preparation.actualTotalStock < qty) {
        throw Exception(
          'Jumlah stok keluar melebihi '
          'total stok produk.',
        );
      }

      final productId = scannedBatch.productId.trim();

      final productRef = _productsCollection.doc(
        productId,
      );

      final batchRef = _batchesCollection.doc(
        cleanBatchId,
      );

      final location = _normalizeLocation(
        scannedBatch.storageLocation,
      );

      if (location.isEmpty) {
        throw Exception(
          'Lokasi batch belum tersedia.',
        );
      }

      final locationRef = _storageLocationsCollection.doc(
        location,
      );

      final transactionRef = _transactionsCollection.doc();

      try {
        return await _firestore.runTransaction<Map<String, dynamic>>(
          (transaction) async {
            final productSnapshot = await transaction.get(
              productRef,
            );

            final batchSnapshot = await transaction.get(
              batchRef,
            );

            final locationSnapshot = await transaction.get(
              locationRef,
            );

            if (!productSnapshot.exists || productSnapshot.data() == null) {
              throw Exception(
                'Produk tidak ditemukan.',
              );
            }

            if (!batchSnapshot.exists || batchSnapshot.data() == null) {
              throw Exception(
                'Batch tidak ditemukan.',
              );
            }

            final currentProductData = productSnapshot.data()!;

            final currentBatchData = batchSnapshot.data()!;

            final currentLocationData = locationSnapshot.data();

            final productHasChanged = _parseInt(
                      currentProductData['totalStock'],
                    ) !=
                    preparation.cachedTotalStock ||
                !_areTimestampsEqual(
                  _parseTimestamp(
                    currentProductData['updatedAt'],
                  ),
                  preparation.productUpdatedAt,
                );

            final batchHasChanged = !_areTimestampsEqual(
              _parseTimestamp(
                currentBatchData['updatedAt'],
              ),
              preparation.batchUpdatedAt,
            );

            if (productHasChanged || batchHasChanged) {
              throw const _RetryStockOutException();
            }

            final currentProductId =
                (currentBatchData['productId'] ?? '').toString().trim();

            final currentStatus = (currentBatchData['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

            final currentRemainingQty = _parseInt(
              currentBatchData['remainingQty'],
            );

            final currentLocation = _normalizeLocation(
              (currentBatchData['storageLocation'] ?? '').toString(),
            );

            if (currentProductId != productId) {
              throw Exception(
                'Produk batch tidak sesuai.',
              );
            }

            if (currentStatus != 'active' || currentRemainingQty <= 0) {
              throw Exception(
                'Batch sudah tidak aktif '
                'atau stoknya telah habis.',
              );
            }

            if (qty > currentRemainingQty) {
              throw Exception(
                'Jumlah stok keluar '
                'melebihi sisa stok batch. '
                'Sisa stok saat ini adalah '
                '$currentRemainingQty '
                '${scannedBatch.unit}.',
              );
            }

            if (currentLocation != location) {
              throw const _RetryStockOutException();
            }

            if (!_isLocationOccupied(
                  currentLocationData,
                ) ||
                _getLockedBatchId(
                      currentLocationData,
                    ) !=
                    cleanBatchId) {
              throw Exception(
                'Data lokasi $location '
                'tidak sesuai dengan batch.',
              );
            }

            final newRemainingQty = currentRemainingQty - qty;

            final newTotalStock = preparation.actualTotalStock - qty;

            final newStatus = newRemainingQty == 0 ? 'empty' : 'active';

            if (newTotalStock < 0) {
              throw Exception(
                'Total stok produk '
                'tidak mencukupi.',
              );
            }

            final now = Timestamp.now();

            final batchCode = (currentBatchData['batchCode'] ?? cleanBatchId)
                .toString()
                .trim();

            final productName =
                (currentBatchData['productName'] ?? scannedBatch.productName)
                    .toString()
                    .trim();

            final unit = (currentBatchData['unit'] ?? scannedBatch.unit)
                .toString()
                .trim();

            final updatedSearchKeywords =
                BatchRepository.buildSearchKeywordsFromMap(
              documentId: cleanBatchId,
              data: currentBatchData,
              overrideStatus: newStatus,
              overrideRemainingQty: newRemainingQty,
            );

            transaction.update(
              batchRef,
              {
                'remainingQty': newRemainingQty,
                'status': newStatus,
                'searchKeywords': updatedSearchKeywords,
                'updatedAt': now,
              },
            );

            transaction.update(
              productRef,
              {
                'totalStock': newTotalStock,
                'updatedAt': now,
              },
            );

            if (newRemainingQty == 0) {
              transaction.set(
                locationRef,
                _buildFreeLocationData(
                  location: location,
                  now: now,
                ),
                SetOptions(merge: true),
              );
            } else {
              transaction.update(
                locationRef,
                {
                  'remainingQty': newRemainingQty,
                  'updatedAt': now,
                },
              );
            }

            transaction.set(
              transactionRef,
              {
                'id': transactionRef.id,
                'type': 'stock_out',
                'productId': productId,
                'productName': productName,
                'batchId': cleanBatchId,
                'batchCode': batchCode,
                'qty': qty,
                'unit': unit,
                'performedBy': cleanPerformedBy,
                'performedByName': cleanPerformedByName,
                'notes': cleanNotes,
                'storageLocation': location,
                'remainingQtyBefore': currentRemainingQty,
                'remainingQtyAfter': newRemainingQty,
                'totalStockAfter': newTotalStock,
                'createdAt': now,
              },
            );

            return {
              'transactionId': transactionRef.id,
              'batchId': cleanBatchId,
              'batchCode': batchCode,
              'productId': productId,
              'qty': qty,
              'remainingQty': newRemainingQty,
              'totalStock': newTotalStock,
              'status': newStatus,
              'location': location,
              'locationReleased': newRemainingQty == 0,
            };
          },
        );
      } on _RetryStockOutException {
        if (attempt == maximumAttempts) {
          throw Exception(
            'Data stok berubah saat proses '
            'berlangsung. Silakan periksa '
            'kembali urutan FIFO dan '
            'ulangi proses.',
          );
        }
      }
    }

    throw Exception(
      'Stok keluar gagal diproses.',
    );
  }
}
