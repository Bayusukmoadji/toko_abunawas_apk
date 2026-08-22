import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/batch_model.dart';
import 'batch_repository.dart';

class _RetryStockOutException implements Exception {
  const _RetryStockOutException();
}

class _StockOutPreparation {
  final BatchModel scannedBatch;
  final BatchModel fifoBatch;

  final List<BatchModel> activeBatches;

  final int actualTotalStock;
  final int cachedTotalStock;

  final Timestamp? productUpdatedAt;

  const _StockOutPreparation({
    required this.scannedBatch,
    required this.fifoBatch,
    required this.activeBatches,
    required this.actualTotalStock,
    required this.cachedTotalStock,
    required this.productUpdatedAt,
  });
}

class _StockOutAllocation {
  final BatchModel batch;
  final int qty;

  const _StockOutAllocation({
    required this.batch,
    required this.qty,
  });

  int get remainingAfter {
    return batch.remainingQty - qty;
  }
}

class StockOutRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final BatchRepository _batchRepository = BatchRepository();

  CollectionReference<Map<String, dynamic>> get _batchesCollection {
    return _firestore.collection(
      'batches',
    );
  }

  CollectionReference<Map<String, dynamic>> get _productsCollection {
    return _firestore.collection(
      'products',
    );
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

  Timestamp? _parseTimestamp(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value;
    }

    return null;
  }

  String _normalizeText(String value) {
    return value.trim();
  }

  String _normalizeLocation(
    String value,
  ) {
    return value.trim().toUpperCase();
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
    final String normalizedStatus = batch.status.trim().toLowerCase();

    return normalizedStatus == 'active' && batch.remainingQty > 0;
  }

  String _batchCodeForComparison(
    BatchModel batch,
  ) {
    final String code = batch.batchCode.trim().toUpperCase();

    if (code.isNotEmpty) {
      return code;
    }

    return batch.id.trim().toUpperCase();
  }

  int _extractSequence(
    String batchCode,
  ) {
    final List<String> parts = batchCode.trim().split('-');

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
    // Prioritas 1:
    // tanggal penerimaan.
    final int receivedComparison = first.receivedAt.compareTo(
      second.receivedAt,
    );

    if (receivedComparison != 0) {
      return receivedComparison;
    }

    // Prioritas 2:
    // waktu pembuatan.
    final int createdComparison = first.createdAt.compareTo(
      second.createdAt,
    );

    if (createdComparison != 0) {
      return createdComparison;
    }

    // Prioritas 3:
    // nomor urut pada kode batch.
    final String firstCode = _batchCodeForComparison(first);

    final String secondCode = _batchCodeForComparison(second);

    final int firstSequence = _extractSequence(firstCode);

    final int secondSequence = _extractSequence(secondCode);

    if (firstSequence > 0 &&
        secondSequence > 0 &&
        firstSequence != secondSequence) {
      return firstSequence.compareTo(
        secondSequence,
      );
    }

    // Tie breaker:
    // kode batch.
    final int codeComparison = firstCode.compareTo(
      secondCode,
    );

    if (codeComparison != 0) {
      return codeComparison;
    }

    return first.id.compareTo(second.id);
  }

  String _formatDate(
    DateTime date,
  ) {
    final String day = date.day.toString().padLeft(2, '0');

    final String month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _getLocationZone(
    String location,
  ) {
    final String normalized = _normalizeLocation(location);

    if (normalized.startsWith('X')) {
      return 'backup';
    }

    return 'main';
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
    return <String, dynamic>{
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
    final DocumentSnapshot<Map<String, dynamic>> batchDocument =
        await _batchesCollection.doc(batchId).get();

    if (!batchDocument.exists || batchDocument.data() == null) {
      throw Exception(
        'Batch tidak ditemukan.',
      );
    }

    final BatchModel scannedBatch = BatchModel.fromMap(
      batchDocument.id,
      batchDocument.data()!,
    );

    if (!_isBatchEligibleForFifo(
      scannedBatch,
    )) {
      throw Exception(
        'Batch sudah tidak aktif atau stoknya telah habis.',
      );
    }

    final String productId = scannedBatch.productId.trim();

    if (productId.isEmpty) {
      throw Exception(
        'Produk pada batch tidak valid.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> productDocument =
        await _productsCollection.doc(productId).get();

    if (!productDocument.exists || productDocument.data() == null) {
      throw Exception(
        'Produk tidak ditemukan.',
      );
    }

    final Map<String, dynamic> productData = productDocument.data()!;

    final QuerySnapshot<Map<String, dynamic>> productBatchesSnapshot =
        await _batchesCollection
            .where(
              'productId',
              isEqualTo: productId,
            )
            .get();

    final List<BatchModel> activeBatches = productBatchesSnapshot.docs
        .map(
          (
            QueryDocumentSnapshot<Map<String, dynamic>> document,
          ) {
            return BatchModel.fromMap(
              document.id,
              document.data(),
            );
          },
        )
        .where(
          _isBatchEligibleForFifo,
        )
        .toList();

    if (activeBatches.isEmpty) {
      throw Exception(
        'Tidak ada batch aktif untuk produk ini.',
      );
    }

    activeBatches.sort(
      _compareBatchesForFifo,
    );

    final BatchModel fifoBatch = activeBatches.first;

    final int actualTotalStock = activeBatches.fold<int>(
      0,
      (
        int accumulator,
        BatchModel batch,
      ) {
        return accumulator + batch.remainingQty;
      },
    );

    return _StockOutPreparation(
      scannedBatch: scannedBatch,
      fifoBatch: fifoBatch,
      activeBatches: activeBatches,
      actualTotalStock: actualTotalStock,
      cachedTotalStock: _parseInt(
        productData['totalStock'],
      ),
      productUpdatedAt: _parseTimestamp(
        productData['updatedAt'],
      ),
    );
  }

  void _validateScannedBatchIsFifo(
    _StockOutPreparation preparation,
  ) {
    final BatchModel scannedBatch = preparation.scannedBatch;

    final BatchModel fifoBatch = preparation.fifoBatch;

    if (scannedBatch.id == fifoBatch.id) {
      return;
    }

    final String fifoDate = _formatDate(
      fifoBatch.receivedAt.toDate(),
    );

    final String location = fifoBatch.storageLocation.trim().isEmpty
        ? '-'
        : fifoBatch.storageLocation.trim();

    throw Exception(
      'Batch tidak sesuai urutan FIFO.\n'
      'Batch yang harus dikeluarkan terlebih dahulu adalah '
      '${fifoBatch.batchCode}, tanggal masuk $fifoDate, '
      'lokasi $location, dengan sisa '
      '${fifoBatch.remainingQty} ${fifoBatch.unit}.',
    );
  }

  List<_StockOutAllocation> _createAllocationPlan({
    required List<BatchModel> activeBatches,
    required int requestedQty,
  }) {
    if (requestedQty <= 0) {
      throw Exception(
        'Jumlah stok keluar harus lebih dari 0.',
      );
    }

    int remainingRequest = requestedQty;

    final List<_StockOutAllocation> allocations = <_StockOutAllocation>[];

    for (final BatchModel batch in activeBatches) {
      if (remainingRequest <= 0) {
        break;
      }

      if (!_isBatchEligibleForFifo(
        batch,
      )) {
        continue;
      }

      final int availableQty = batch.remainingQty;

      final int allocatedQty =
          remainingRequest <= availableQty ? remainingRequest : availableQty;

      if (allocatedQty <= 0) {
        continue;
      }

      allocations.add(
        _StockOutAllocation(
          batch: batch,
          qty: allocatedQty,
        ),
      );

      remainingRequest -= allocatedQty;
    }

    if (remainingRequest > 0) {
      throw Exception(
        'Jumlah stok keluar melebihi total stok aktif produk.',
      );
    }

    return allocations;
  }

  Map<String, dynamic> _buildPreviewResult({
    required _StockOutPreparation preparation,
    required int qty,
    required List<_StockOutAllocation> allocations,
  }) {
    return <String, dynamic>{
      'productId': preparation.scannedBatch.productId,
      'productName': preparation.scannedBatch.productName,
      'requestedQty': qty,
      'unit': preparation.scannedBatch.unit,
      'totalActiveStock': preparation.actualTotalStock,
      'totalStockAfter': preparation.actualTotalStock - qty,
      'batchCount': allocations.length,
      'isCrossBatch': allocations.length > 1,
      'allocations': allocations.map(
        (
          _StockOutAllocation allocation,
        ) {
          final BatchModel batch = allocation.batch;

          return <String, dynamic>{
            'batchId': batch.id,
            'batchCode': batch.batchCode,
            'receivedAt': _formatDate(
              batch.receivedAt.toDate(),
            ),
            'storageLocation': batch.storageLocation.trim().isEmpty
                ? '-'
                : batch.storageLocation.trim(),
            'remainingQtyBefore': batch.remainingQty,
            'allocatedQty': allocation.qty,
            'remainingQtyAfter': allocation.remainingAfter,
            'unit': batch.unit,
            'statusAfter': allocation.remainingAfter == 0 ? 'empty' : 'active',
          };
        },
      ).toList(),
    };
  }

  /// Menampilkan rencana pembagian FIFO
  /// sebelum transaksi dikonfirmasi.
  Future<Map<String, dynamic>> previewStockOut({
    required String batchId,
    required int qty,
  }) async {
    final String cleanBatchId = _normalizeText(batchId);

    if (cleanBatchId.isEmpty) {
      throw Exception(
        'ID batch tidak valid.',
      );
    }

    if (qty <= 0) {
      throw Exception(
        'Jumlah stok keluar harus lebih dari 0.',
      );
    }

    final _StockOutPreparation preparation = await _prepareStockOut(
      batchId: cleanBatchId,
    );

    _validateScannedBatchIsFifo(
      preparation,
    );

    if (qty > preparation.actualTotalStock) {
      throw Exception(
        'Jumlah stok keluar melebihi total stok aktif produk. '
        'Total stok aktif saat ini adalah '
        '${preparation.actualTotalStock} '
        '${preparation.scannedBatch.unit}.',
      );
    }

    final List<_StockOutAllocation> allocations = _createAllocationPlan(
      activeBatches: preparation.activeBatches,
      requestedQty: qty,
    );

    return _buildPreviewResult(
      preparation: preparation,
      qty: qty,
      allocations: allocations,
    );
  }

  /// ============================================================
  /// FIFO STOCK OUT
  /// ============================================================
  ///
  /// Aturan:
  ///
  /// 1. QR pertama harus batch prioritas FIFO.
  /// 2. qty > 0.
  /// 3. qty boleh melebihi sisa batch pertama.
  /// 4. Sistem otomatis menggunakan batch berikutnya.
  /// 5. qty tidak boleh melebihi total stok aktif.
  /// 6. Seluruh perubahan dilakukan dalam satu
  ///    Firestore transaction.
  /// 7. Setiap detail batch memiliki transactionGroupId
  ///    yang sama.
  Future<Map<String, dynamic>> processStockOut({
    required String batchId,
    required int qty,
    required String performedBy,
    required String performedByName,
    required String notes,
  }) async {
    final String cleanBatchId = _normalizeText(batchId);

    final String cleanPerformedBy = _normalizeText(performedBy);

    final String cleanPerformedByName = _normalizeText(
      performedByName,
    );

    final String cleanNotes = _normalizeText(notes);

    if (cleanBatchId.isEmpty) {
      throw Exception(
        'ID batch tidak valid.',
      );
    }

    if (qty <= 0) {
      throw Exception(
        'Jumlah stok keluar harus lebih dari 0.',
      );
    }

    if (cleanPerformedBy.isEmpty) {
      throw Exception(
        'Data pengguna tidak valid.',
      );
    }

    // Pastikan kondisi lock lokasi
    // sesuai batch aktif sebelum transaksi.
    await _batchRepository.synchronizeStorageLocationLocks(
      force: true,
    );

    const int maximumAttempts = 5;

    for (int attempt = 1; attempt <= maximumAttempts; attempt++) {
      final _StockOutPreparation preparation = await _prepareStockOut(
        batchId: cleanBatchId,
      );

      _validateScannedBatchIsFifo(
        preparation,
      );

      if (qty > preparation.actualTotalStock) {
        throw Exception(
          'Jumlah stok keluar melebihi total stok aktif produk. '
          'Total stok aktif saat ini adalah '
          '${preparation.actualTotalStock} '
          '${preparation.scannedBatch.unit}.',
        );
      }

      final List<_StockOutAllocation> allocations = _createAllocationPlan(
        activeBatches: preparation.activeBatches,
        requestedQty: qty,
      );

      final String productId = preparation.scannedBatch.productId.trim();

      final DocumentReference<Map<String, dynamic>> productRef =
          _productsCollection.doc(
        productId,
      );

      final Map<String, DocumentReference<Map<String, dynamic>>> batchRefs =
          <String, DocumentReference<Map<String, dynamic>>>{};

      final Map<String, DocumentReference<Map<String, dynamic>>> locationRefs =
          <String, DocumentReference<Map<String, dynamic>>>{};

      for (final _StockOutAllocation allocation in allocations) {
        final BatchModel batch = allocation.batch;

        batchRefs[batch.id] = _batchesCollection.doc(
          batch.id,
        );

        final String location = _normalizeLocation(
          batch.storageLocation,
        );

        if (location.isEmpty) {
          throw Exception(
            'Lokasi batch ${batch.batchCode} belum tersedia.',
          );
        }

        locationRefs[batch.id] = _storageLocationsCollection.doc(location);
      }

      // ID kelompok dibuat satu kali.
      final String transactionGroupId = _transactionsCollection.doc().id;

      final List<DocumentReference<Map<String, dynamic>>> transactionRefs =
          <DocumentReference<Map<String, dynamic>>>[];

      for (int index = 0; index < allocations.length; index++) {
        final String detailNumber = (index + 1).toString().padLeft(2, '0');

        transactionRefs.add(
          _transactionsCollection.doc(
            '${transactionGroupId}_$detailNumber',
          ),
        );
      }

      try {
        final Map<String, dynamic> result =
            await _firestore.runTransaction<Map<String, dynamic>>(
          (
            Transaction transaction,
          ) async {
            // ===================================================
            // READ PRODUCT
            // ===================================================

            final DocumentSnapshot<Map<String, dynamic>> productSnapshot =
                await transaction.get(
              productRef,
            );

            if (!productSnapshot.exists || productSnapshot.data() == null) {
              throw Exception(
                'Produk tidak ditemukan.',
              );
            }

            final Map<String, dynamic> currentProductData =
                productSnapshot.data()!;

            final int currentCachedTotalStock = _parseInt(
              currentProductData['totalStock'],
            );

            final Timestamp? currentProductUpdatedAt = _parseTimestamp(
              currentProductData['updatedAt'],
            );

            final bool productHasChanged =
                currentCachedTotalStock != preparation.cachedTotalStock ||
                    !_areTimestampsEqual(
                      currentProductUpdatedAt,
                      preparation.productUpdatedAt,
                    );

            if (productHasChanged) {
              throw const _RetryStockOutException();
            }

            // ===================================================
            // READ BATCHES
            // ===================================================

            final Map<String, DocumentSnapshot<Map<String, dynamic>>>
                currentBatchSnapshots =
                <String, DocumentSnapshot<Map<String, dynamic>>>{};

            for (final _StockOutAllocation allocation in allocations) {
              final String currentBatchId = allocation.batch.id;

              currentBatchSnapshots[currentBatchId] = await transaction.get(
                batchRefs[currentBatchId]!,
              );
            }

            // ===================================================
            // READ LOCATIONS
            // ===================================================

            final Map<String, DocumentSnapshot<Map<String, dynamic>>>
                currentLocationSnapshots =
                <String, DocumentSnapshot<Map<String, dynamic>>>{};

            for (final _StockOutAllocation allocation in allocations) {
              final String currentBatchId = allocation.batch.id;

              currentLocationSnapshots[currentBatchId] = await transaction.get(
                locationRefs[currentBatchId]!,
              );
            }

            // ===================================================
            // REVALIDATION
            // ===================================================

            int validatedQty = 0;

            for (int index = 0; index < allocations.length; index++) {
              final _StockOutAllocation allocation = allocations[index];

              final BatchModel expectedBatch = allocation.batch;

              final DocumentSnapshot<Map<String, dynamic>> batchSnapshot =
                  currentBatchSnapshots[expectedBatch.id]!;

              if (!batchSnapshot.exists || batchSnapshot.data() == null) {
                throw const _RetryStockOutException();
              }

              final Map<String, dynamic> batchData = batchSnapshot.data()!;

              final String currentProductId =
                  (batchData['productId'] ?? '').toString().trim();

              final String currentStatus =
                  (batchData['status'] ?? '').toString().trim().toLowerCase();

              final int currentRemainingQty = _parseInt(
                batchData['remainingQty'],
              );

              final String currentLocation = _normalizeLocation(
                (batchData['storageLocation'] ?? '').toString(),
              );

              if (currentProductId != productId) {
                throw const _RetryStockOutException();
              }

              if (currentStatus != 'active' || currentRemainingQty <= 0) {
                throw const _RetryStockOutException();
              }

              if (currentRemainingQty != expectedBatch.remainingQty) {
                throw const _RetryStockOutException();
              }

              if (allocation.qty > currentRemainingQty) {
                throw const _RetryStockOutException();
              }

              final String expectedLocation = _normalizeLocation(
                expectedBatch.storageLocation,
              );

              if (currentLocation != expectedLocation) {
                throw const _RetryStockOutException();
              }

              final Map<String, dynamic>? locationData =
                  currentLocationSnapshots[expectedBatch.id]?.data();

              if (!_isLocationOccupied(
                    locationData,
                  ) ||
                  _getLockedBatchId(
                        locationData,
                      ) !=
                      expectedBatch.id) {
                throw Exception(
                  'Data lokasi $expectedLocation tidak sesuai '
                  'dengan batch ${expectedBatch.batchCode}.',
                );
              }

              validatedQty += allocation.qty;
            }

            if (validatedQty != qty) {
              throw const _RetryStockOutException();
            }

            final int newTotalStock = preparation.actualTotalStock - qty;

            if (newTotalStock < 0) {
              throw Exception(
                'Total stok produk tidak mencukupi.',
              );
            }

            final Timestamp now = Timestamp.now();

            // ===================================================
            // WRITES
            // ===================================================

            final List<Map<String, dynamic>> resultAllocations =
                <Map<String, dynamic>>[];

            for (int index = 0; index < allocations.length; index++) {
              final _StockOutAllocation allocation = allocations[index];

              final BatchModel batch = allocation.batch;

              final DocumentSnapshot<Map<String, dynamic>> batchSnapshot =
                  currentBatchSnapshots[batch.id]!;

              final Map<String, dynamic> batchData = batchSnapshot.data()!;

              final int currentRemainingQty = _parseInt(
                batchData['remainingQty'],
              );

              final int newRemainingQty = currentRemainingQty - allocation.qty;

              final String newStatus =
                  newRemainingQty == 0 ? 'empty' : 'active';

              final String batchCode =
                  (batchData['batchCode'] ?? batch.id).toString().trim();

              final String productName = (batchData['productName'] ??
                      preparation.scannedBatch.productName)
                  .toString()
                  .trim();

              final String unit =
                  (batchData['unit'] ?? preparation.scannedBatch.unit)
                      .toString()
                      .trim();

              final String location = _normalizeLocation(
                (batchData['storageLocation'] ?? batch.storageLocation)
                    .toString(),
              );

              // -------------------------
              // UPDATE BATCH
              // -------------------------

              transaction.update(
                batchRefs[batch.id]!,
                <String, dynamic>{
                  'remainingQty': newRemainingQty,
                  'status': newStatus,
                  'updatedAt': now,
                },
              );

              // -------------------------
              // UPDATE LOCATION
              // -------------------------

              if (newRemainingQty == 0) {
                transaction.set(
                  locationRefs[batch.id]!,
                  _buildFreeLocationData(
                    location: location,
                    now: now,
                  ),
                  SetOptions(
                    merge: true,
                  ),
                );
              } else {
                transaction.update(
                  locationRefs[batch.id]!,
                  <String, dynamic>{
                    'remainingQty': newRemainingQty,
                    'updatedAt': now,
                  },
                );
              }

              // -------------------------
              // CREATE TRANSACTION DETAIL
              // -------------------------

              final DocumentReference<Map<String, dynamic>> transactionRef =
                  transactionRefs[index];

              transaction.set(
                transactionRef,
                <String, dynamic>{
                  'id': transactionRef.id,
                  'type': 'stock_out',
                  'productId': productId,
                  'productName': productName,
                  'batchId': batch.id,
                  'batchCode': batchCode,
                  'qty': allocation.qty,
                  'unit': unit,
                  'performedBy': cleanPerformedBy,
                  'performedByName': cleanPerformedByName,
                  'notes': cleanNotes,

                  // =============================================
                  // FIELD BARU
                  // =============================================
                  'transactionGroupId': transactionGroupId,

                  'storageLocation': location,
                  'remainingQtyBefore': currentRemainingQty,
                  'remainingQtyAfter': newRemainingQty,
                  'totalStockAfter': newTotalStock,
                  'createdAt': now,
                },
              );

              resultAllocations.add(
                <String, dynamic>{
                  'transactionId': transactionRef.id,
                  'transactionGroupId': transactionGroupId,
                  'batchId': batch.id,
                  'batchCode': batchCode,
                  'receivedAt': _formatDate(
                    batch.receivedAt.toDate(),
                  ),
                  'storageLocation': location,
                  'qty': allocation.qty,
                  'remainingQtyBefore': currentRemainingQty,
                  'remainingQtyAfter': newRemainingQty,
                  'status': newStatus,
                  'locationReleased': newRemainingQty == 0,
                  'unit': unit,
                },
              );
            }

            // ===================================================
            // UPDATE PRODUCT TOTAL STOCK
            // ===================================================

            transaction.update(
              productRef,
              <String, dynamic>{
                'totalStock': newTotalStock,
                'updatedAt': now,
              },
            );

            return <String, dynamic>{
              'transactionGroupId': transactionGroupId,
              'transactionIds': transactionRefs
                  .map(
                    (
                      DocumentReference<Map<String, dynamic>> reference,
                    ) =>
                        reference.id,
                  )
                  .toList(),
              'batchId': preparation.scannedBatch.id,
              'batchCode': preparation.scannedBatch.batchCode,
              'productId': productId,
              'productName': preparation.scannedBatch.productName,
              'requestedQty': qty,
              'qty': qty,
              'unit': preparation.scannedBatch.unit,
              'batchCount': resultAllocations.length,
              'isCrossBatch': resultAllocations.length > 1,
              'allocations': resultAllocations,
              'totalStockBefore': preparation.actualTotalStock,
              'totalStockAfter': newTotalStock,
            };
          },
        );

        return result;
      } on _RetryStockOutException {
        if (attempt == maximumAttempts) {
          throw Exception(
            'Data stok berubah saat proses berlangsung. '
            'Silakan periksa kembali urutan FIFO dan ulangi proses.',
          );
        }

        // Data berubah saat transaksi lain berlangsung.
        // Buat ulang preparation dan allocation plan.
        continue;
      }
    }

    throw Exception(
      'Stok keluar gagal diproses.',
    );
  }
}
