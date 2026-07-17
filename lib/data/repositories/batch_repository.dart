import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

class BatchProductFilterOption {
  final String id;
  final String name;
  final String code;

  const BatchProductFilterOption({
    required this.id,
    required this.name,
    required this.code,
  });
}

class _LocationOccupancy {
  final String batchId;
  final String batchCode;
  final String productId;
  final String productName;
  final int remainingQty;
  final Timestamp occupiedAt;

  const _LocationOccupancy({
    required this.batchId,
    required this.batchCode,
    required this.productId,
    required this.productName,
    required this.remainingQty,
    required this.occupiedAt,
  });
}

class BatchRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  bool _storageLocksSynchronized = false;

  static const List<String> mainStorageLocations = [
    'A1',
    'A2',
    'A3',
    'A4',
    'A5',
    'A6',
    'A7',
    'A8',
    'A9',
    'A10',
    'B1',
    'B2',
    'B3',
    'B4',
    'B5',
    'B6',
    'B7',
    'B8',
    'B9',
    'B10',
    'C1',
    'C2',
    'C3',
    'C4',
    'C5',
    'C6',
    'C7',
    'C8',
    'C9',
    'C10',
    'D1',
    'D2',
    'D3',
    'D4',
    'D5',
  ];

  static const List<String> backupStorageLocations = [
    'X1',
    'X2',
    'X3',
    'X4',
    'X5',
  ];

  static List<String> get allStorageLocations {
    return [
      ...mainStorageLocations,
      ...backupStorageLocations,
    ];
  }

  static const int _maximumSearchPrefixLength = 24;
  static const int _maximumSearchKeywordLength = 250;
  static const int _maximumNotesSearchWords = 30;

  CollectionReference<Map<String, dynamic>> get _batchesCollection {
    return _firestore.collection('batches');
  }

  CollectionReference<Map<String, dynamic>> get _countersCollection {
    return _firestore.collection('counters');
  }

  CollectionReference<Map<String, dynamic>> get _productsCollection {
    return _firestore.collection('products');
  }

  CollectionReference<Map<String, dynamic>> get _transactionsCollection {
    return _firestore.collection('transactions');
  }

  CollectionReference<Map<String, dynamic>> get _usersCollection {
    return _firestore.collection('users');
  }

  CollectionReference<Map<String, dynamic>> get _batchMovementsCollection {
    return _firestore.collection('batch_movements');
  }

  CollectionReference<Map<String, dynamic>> get _storageLocationsCollection {
    return _firestore.collection('storage_locations');
  }

  static String normalizeSearchKeyword(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static void _addKeyword(
    Set<String> keywords,
    dynamic value,
  ) {
    final normalized = normalizeSearchKeyword(
      value?.toString() ?? '',
    );

    if (normalized.isEmpty || normalized.length > _maximumSearchKeywordLength) {
      return;
    }

    keywords.add(normalized);
  }

  static void _addSearchValue(
    Set<String> keywords,
    dynamic value, {
    bool includeWholeValue = true,
    bool includeCompactValue = true,
    bool includePrefixes = true,
    int maximumWords = 30,
  }) {
    final normalized = normalizeSearchKeyword(
      value?.toString() ?? '',
    );

    if (normalized.isEmpty) {
      return;
    }

    final words = normalized
        .split(' ')
        .where((word) => word.isNotEmpty)
        .take(maximumWords)
        .toList();

    if (includeWholeValue) {
      _addKeyword(keywords, normalized);
    }

    if (includeCompactValue) {
      final compactValue = normalized.replaceAll(' ', '');

      if (compactValue.length >= 2) {
        _addKeyword(keywords, compactValue);
      }
    }

    for (final word in words) {
      _addKeyword(keywords, word);

      if (!includePrefixes || word.length < 2) {
        continue;
      }

      final maximumPrefixLength = word.length < _maximumSearchPrefixLength
          ? word.length
          : _maximumSearchPrefixLength;

      for (var length = 2; length <= maximumPrefixLength; length++) {
        _addKeyword(
          keywords,
          word.substring(0, length),
        );
      }
    }
  }

  static String _indonesianMonthName(int month) {
    const names = [
      'januari',
      'februari',
      'maret',
      'april',
      'mei',
      'juni',
      'juli',
      'agustus',
      'september',
      'oktober',
      'november',
      'desember',
    ];

    if (month < 1 || month > 12) {
      return '';
    }

    return names[month - 1];
  }

  static List<String> buildSearchKeywords({
    required String batchId,
    required String batchCode,
    required String qrCodeValue,
    required String productId,
    required String productName,
    required String productCode,
    required String storageLocation,
    required String createdBy,
    required String createdByName,
    required String unit,
    required String status,
    required int initialQty,
    required int remainingQty,
    required DateTime receivedAt,
    required String notes,
  }) {
    final keywords = <String>{};

    final mainValues = <dynamic>[
      batchId,
      batchCode,
      qrCodeValue,
      productId,
      productName,
      productCode,
      storageLocation,
      createdBy,
      createdByName,
      unit,
      initialQty,
      remainingQty,
      '$initialQty $unit',
      '$remainingQty $unit',
      '$remainingQty dari $initialQty $unit',
    ];

    for (final value in mainValues) {
      _addSearchValue(
        keywords,
        value,
      );
    }

    final normalizedStatus = normalizeSearchKeyword(
      status,
    );

    if (normalizedStatus == 'active' && remainingQty > 0) {
      for (final value in const [
        'active',
        'aktif',
        'batch aktif',
      ]) {
        _addSearchValue(
          keywords,
          value,
        );
      }
    } else if (const {
          'empty',
          'depleted',
          'inactive',
        }.contains(normalizedStatus) ||
        remainingQty <= 0) {
      for (final value in const [
        'empty',
        'depleted',
        'inactive',
        'habis',
        'tidak aktif',
        'batch habis',
      ]) {
        _addSearchValue(
          keywords,
          value,
        );
      }
    } else {
      _addSearchValue(
        keywords,
        normalizedStatus,
      );
    }

    final localDate = receivedAt.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();
    final monthName = _indonesianMonthName(
      localDate.month,
    );

    for (final value in [
      '$day/$month/$year',
      '$day-$month-$year',
      '$year-$month-$day',
      '$year/$month/$day',
      '${localDate.day} $monthName $year',
      '$day $monthName $year',
      monthName,
      year,
    ]) {
      _addSearchValue(
        keywords,
        value,
      );
    }

    _addSearchValue(
      keywords,
      notes,
      includeCompactValue: false,
      maximumWords: _maximumNotesSearchWords,
    );

    final result = keywords
        .where(
          (keyword) =>
              keyword.isNotEmpty &&
              keyword.length <= _maximumSearchKeywordLength,
        )
        .toList()
      ..sort();

    return result;
  }

  static List<String> buildSearchKeywordsFromMap({
    required String documentId,
    required Map<String, dynamic> data,
    String? overrideStorageLocation,
    String? overrideStatus,
    int? overrideRemainingQty,
  }) {
    final receivedAtRaw = data['receivedAt'];

    final receivedAt = receivedAtRaw is Timestamp
        ? receivedAtRaw.toDate()
        : receivedAtRaw is DateTime
            ? receivedAtRaw
            : DateTime.fromMillisecondsSinceEpoch(0);

    final initialQty = data['initialQty'] is num
        ? (data['initialQty'] as num).toInt()
        : int.tryParse(
              data['initialQty']?.toString() ?? '',
            ) ??
            0;

    final remainingQty = overrideRemainingQty ??
        (data['remainingQty'] is num
            ? (data['remainingQty'] as num).toInt()
            : int.tryParse(
                  data['remainingQty']?.toString() ?? '',
                ) ??
                0);

    return buildSearchKeywords(
      batchId: (data['id'] ?? documentId).toString(),
      batchCode: (data['batchCode'] ?? documentId).toString(),
      qrCodeValue: (data['qrCodeValue'] ?? documentId).toString(),
      productId: (data['productId'] ?? '').toString(),
      productName: (data['productName'] ?? '').toString(),
      productCode: (data['productCode'] ?? '').toString(),
      storageLocation:
          overrideStorageLocation ?? (data['storageLocation'] ?? '').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      unit: (data['unit'] ?? 'karung').toString(),
      status: overrideStatus ?? (data['status'] ?? '').toString(),
      initialQty: initialQty,
      remainingQty: remainingQty,
      receivedAt: receivedAt,
      notes: (data['notes'] ?? '').toString(),
    );
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

  DateTime _dateOnly(DateTime value) {
    final localDate = value.toLocal();

    return DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );
  }

  bool _isFutureDate(DateTime value) {
    final receivedDate = _dateOnly(value);
    final today = _dateOnly(DateTime.now());

    return receivedDate.isAfter(today);
  }

  String _getLocationZone(String location) {
    return isBackupStorageLocation(location) ? 'backup' : 'main';
  }

  String _buildBatchCode({
    required DateTime receivedAt,
    required String productCode,
    required int sequenceNumber,
  }) {
    final dateKey = _formatDateKey(receivedAt);
    final cleanProductCode = _normalizeProductCode(
      productCode,
    );
    final sequence = _formatSequence(
      sequenceNumber,
    );

    return 'BATCH-$dateKey-$cleanProductCode-$sequence';
  }

  int _extractSequenceFromBatchCode(String batchCode) {
    final parts = batchCode.trim().split('-');

    if (parts.isEmpty) {
      return 0;
    }

    return int.tryParse(
          parts.last.trim(),
        ) ??
        0;
  }

  String _getBatchCodeForFifo(BatchModel batch) {
    final batchCode = batch.batchCode.trim().toUpperCase();

    if (batchCode.isNotEmpty) {
      return batchCode;
    }

    return batch.id.trim().toUpperCase();
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

    final firstBatchCode = _getBatchCodeForFifo(
      first,
    );
    final secondBatchCode = _getBatchCodeForFifo(
      second,
    );

    final firstSequence = _extractSequenceFromBatchCode(
      firstBatchCode,
    );
    final secondSequence = _extractSequenceFromBatchCode(
      secondBatchCode,
    );

    if (firstSequence > 0 &&
        secondSequence > 0 &&
        firstSequence != secondSequence) {
      return firstSequence.compareTo(
        secondSequence,
      );
    }

    final batchCodeComparison = firstBatchCode.compareTo(
      secondBatchCode,
    );

    if (batchCodeComparison != 0) {
      return batchCodeComparison;
    }

    return first.id.trim().toUpperCase().compareTo(
          second.id.trim().toUpperCase(),
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

  bool _isBatchEligibleForFifo(
    BatchModel batch,
  ) {
    final normalizedStatus = batch.status.toLowerCase().trim();

    return normalizedStatus == 'active' && batch.remainingQty > 0;
  }

  bool _isBatchDataActive(
    Map<String, dynamic> data,
  ) {
    final status = (data['status'] ?? '').toString().toLowerCase().trim();

    final remainingQty = _parseInt(
      data['remainingQty'],
    );

    return status == 'active' && remainingQty > 0;
  }

  bool _isLocationLockOccupied(
    Map<String, dynamic>? data,
  ) {
    return data?['isOccupied'] == true;
  }

  String _getLockedBatchId(
    Map<String, dynamic>? data,
  ) {
    return (data?['batchId'] ?? '').toString().trim();
  }

  bool _isValidStorageLocation(String location) {
    final normalized = _normalizeLocation(
      location,
    );

    return allStorageLocations.contains(
      normalized,
    );
  }

  String _resolveUserName({
    required User authUser,
    Map<String, dynamic>? userData,
  }) {
    final firestoreName = (userData?['name'] ?? '').toString().trim();

    if (firestoreName.isNotEmpty) {
      return firestoreName;
    }

    final displayName = authUser.displayName?.trim() ?? '';

    if (displayName.isNotEmpty) {
      return displayName;
    }

    final email = authUser.email?.trim() ?? '';

    if (email.isNotEmpty) {
      return email;
    }

    return 'Pengguna';
  }

  Map<String, dynamic> _buildOccupiedLockData({
    required String location,
    required String batchId,
    required String batchCode,
    required String productId,
    required String productName,
    required int remainingQty,
    required Timestamp occupiedAt,
    required Timestamp updatedAt,
  }) {
    return {
      'id': location,
      'location': location,
      'zone': _getLocationZone(location),
      'isOccupied': true,
      'batchId': batchId,
      'batchCode': batchCode,
      'productId': productId,
      'productName': productName,
      'remainingQty': remainingQty,
      'occupiedAt': occupiedAt,
      'releasedAt': null,
      'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> _buildFreeLockData({
    required String location,
    required Timestamp updatedAt,
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
      'releasedAt': updatedAt,
      'updatedAt': updatedAt,
    };
  }

  bool _lockMatchesOccupancy({
    required Map<String, dynamic>? existingData,
    required String location,
    required _LocationOccupancy? expected,
  }) {
    if (existingData == null) {
      return false;
    }

    final existingLocation =
        (existingData['location'] ?? '').toString().trim().toUpperCase();

    final existingZone = (existingData['zone'] ?? '').toString().trim();

    if (existingLocation != location ||
        existingZone != _getLocationZone(location)) {
      return false;
    }

    if (expected == null) {
      return existingData['isOccupied'] == false &&
          _getLockedBatchId(
            existingData,
          ).isEmpty &&
          _parseInt(
                existingData['remainingQty'],
              ) ==
              0;
    }

    return existingData['isOccupied'] == true &&
        _getLockedBatchId(existingData) == expected.batchId &&
        _parseInt(
              existingData['remainingQty'],
            ) ==
            expected.remainingQty;
  }

  bool isMainStorageLocation(String location) {
    return mainStorageLocations.contains(
      _normalizeLocation(location),
    );
  }

  bool isBackupStorageLocation(String location) {
    return backupStorageLocations.contains(
      _normalizeLocation(location),
    );
  }

  Future<void> synchronizeStorageLocationLocks({
    bool force = false,
  }) async {
    if (_storageLocksSynchronized && !force) {
      return;
    }

    final activeBatchSnapshot = await _batchesCollection
        .where(
          'status',
          isEqualTo: 'active',
        )
        .get();

    final expectedOccupancies = <String, _LocationOccupancy>{};

    for (final document in activeBatchSnapshot.docs) {
      final data = document.data();

      if (!_isBatchDataActive(data)) {
        continue;
      }

      final location = _normalizeLocation(
        (data['storageLocation'] ?? '').toString(),
      );

      if (location.isEmpty) {
        throw Exception(
          'Batch aktif ${document.id} belum memiliki lokasi.',
        );
      }

      if (!_isValidStorageLocation(location)) {
        throw Exception(
          'Batch aktif ${document.id} memiliki lokasi '
          'tidak valid: $location.',
        );
      }

      final existingOccupancy = expectedOccupancies[location];

      if (existingOccupancy != null &&
          existingOccupancy.batchId != document.id) {
        throw Exception(
          'Ditemukan dua batch aktif pada lokasi '
          '$location: ${existingOccupancy.batchId} '
          'dan ${document.id}.',
        );
      }

      final createdAtRaw = data['createdAt'];

      final occupiedAt =
          createdAtRaw is Timestamp ? createdAtRaw : Timestamp.now();

      expectedOccupancies[location] = _LocationOccupancy(
        batchId: document.id,
        batchCode: (data['batchCode'] ?? document.id).toString().trim(),
        productId: (data['productId'] ?? '').toString().trim(),
        productName: (data['productName'] ?? '').toString().trim(),
        remainingQty: _parseInt(
          data['remainingQty'],
        ),
        occupiedAt: occupiedAt,
      );
    }

    final lockSnapshot = await _storageLocationsCollection.get();

    final existingLocks = <String, Map<String, dynamic>>{};

    for (final document in lockSnapshot.docs) {
      existingLocks[_normalizeLocation(document.id)] = document.data();
    }

    final writeBatch = _firestore.batch();
    final now = Timestamp.now();

    var hasChanges = false;

    for (final location in allStorageLocations) {
      final expected = expectedOccupancies[location];
      final existing = existingLocks[location];

      if (_lockMatchesOccupancy(
        existingData: existing,
        location: location,
        expected: expected,
      )) {
        continue;
      }

      final locationRef = _storageLocationsCollection.doc(
        location,
      );

      if (expected == null) {
        writeBatch.set(
          locationRef,
          _buildFreeLockData(
            location: location,
            updatedAt: now,
          ),
          SetOptions(merge: true),
        );
      } else {
        writeBatch.set(
          locationRef,
          _buildOccupiedLockData(
            location: location,
            batchId: expected.batchId,
            batchCode: expected.batchCode,
            productId: expected.productId,
            productName: expected.productName,
            remainingQty: expected.remainingQty,
            occupiedAt: expected.occupiedAt,
            updatedAt: now,
          ),
          SetOptions(merge: true),
        );
      }

      hasChanges = true;
    }

    if (hasChanges) {
      await writeBatch.commit();
    }

    _storageLocksSynchronized = true;
  }

  Future<int> _getExistingMaxSequenceByProduct({
    required String productId,
  }) async {
    final snapshot = await _batchesCollection
        .where(
          'productId',
          isEqualTo: productId,
        )
        .get();

    var maxSequence = 0;

    for (final document in snapshot.docs) {
      final data = document.data();

      final batchCode = (data['batchCode'] ?? document.id).toString();

      final sequence = _extractSequenceFromBatchCode(
        batchCode,
      );

      if (sequence > maxSequence) {
        maxSequence = sequence;
      }
    }

    return maxSequence;
  }

  Future<Set<String>> getOccupiedStorageLocations() async {
    await synchronizeStorageLocationLocks();

    final snapshot = await _storageLocationsCollection.get();

    final locations = <String>{};

    for (final document in snapshot.docs) {
      final data = document.data();

      if (data['isOccupied'] != true) {
        continue;
      }

      final location = _normalizeLocation(
        (data['location'] ?? document.id).toString(),
      );

      if (location.isNotEmpty) {
        locations.add(location);
      }
    }

    return locations;
  }

  Future<List<String>> getAvailableMainStorageLocations() async {
    await synchronizeStorageLocationLocks(
      force: true,
    );

    final occupiedLocations = await getOccupiedStorageLocations();

    return mainStorageLocations
        .where(
          (location) => !occupiedLocations.contains(
            location,
          ),
        )
        .toList();
  }

  Future<List<BatchProductFilterOption>> getBatchProductFilterOptions() async {
    final snapshot = await _productsCollection.get();

    final options = snapshot.docs.map((document) {
      final data = document.data();

      final name = (data['name'] ?? '').toString().trim();

      final code = (data['code'] ?? '').toString().trim();

      return BatchProductFilterOption(
        id: document.id,
        name: name.isEmpty ? 'Produk Tanpa Nama' : name,
        code: code,
      );
    }).toList();

    options.sort(
      (first, second) => first.name.toLowerCase().compareTo(
            second.name.toLowerCase(),
          ),
    );

    return options;
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
    final cleanProductId = productId.trim();

    final cleanInputProductCode = _normalizeProductCode(
      productCode,
    );

    final cleanInputProductName = productName.trim();

    final cleanInputUnit = unit.trim();

    final cleanLocation = _normalizeLocation(
      storageLocation,
    );

    final cleanCreatedBy = createdBy.trim();

    final cleanCreatedByName = createdByName.trim();

    final cleanNotes = notes.trim();

    final cleanReceivedAt = _dateOnly(receivedAt);

    if (_isFutureDate(cleanReceivedAt)) {
      throw Exception(
        'Tanggal masuk tidak boleh melebihi '
        'tanggal hari ini.',
      );
    }

    if (cleanProductId.isEmpty) {
      throw Exception(
        'Product ID tidak valid.',
      );
    }

    if (cleanInputProductCode.isEmpty) {
      throw Exception(
        'Kode produk tidak valid.',
      );
    }

    if (cleanInputProductName.isEmpty) {
      throw Exception(
        'Nama produk tidak valid.',
      );
    }

    if (qty <= 0) {
      throw Exception(
        'Jumlah stok masuk harus lebih dari 0.',
      );
    }

    if (cleanInputUnit.isEmpty) {
      throw Exception(
        'Satuan produk tidak valid.',
      );
    }

    if (!_isValidStorageLocation(
      cleanLocation,
    )) {
      throw Exception(
        'Lokasi penyimpanan $cleanLocation '
        'tidak valid.',
      );
    }

    if (cleanCreatedBy.isEmpty) {
      throw Exception(
        'Data pengguna tidak valid.',
      );
    }

    await synchronizeStorageLocationLocks(
      force: true,
    );

    final counterId = 'batch_sequence_'
        '${_normalizeCounterId(cleanProductId)}';

    final counterRef = _countersCollection.doc(counterId);

    final productRef = _productsCollection.doc(
      cleanProductId,
    );

    final locationRef = _storageLocationsCollection.doc(
      cleanLocation,
    );

    final existingMaxSequence = await _getExistingMaxSequenceByProduct(
      productId: cleanProductId,
    );

    return _firestore.runTransaction<Map<String, String>>(
      (transaction) async {
        final counterSnapshot = await transaction.get(
          counterRef,
        );

        final productSnapshot = await transaction.get(
          productRef,
        );

        final locationSnapshot = await transaction.get(
          locationRef,
        );

        if (!productSnapshot.exists || productSnapshot.data() == null) {
          throw Exception(
            'Produk tidak ditemukan.',
          );
        }

        final productData = productSnapshot.data()!;

        final isProductActive = productData['isActive'] == true;

        final isProductDeleted = productData['isDeleted'] == true;

        if (!isProductActive || isProductDeleted) {
          throw Exception(
            'Produk sudah tidak aktif dan '
            'tidak dapat digunakan.',
          );
        }

        final locationData = locationSnapshot.data();

        if (_isLocationLockOccupied(
          locationData,
        )) {
          final lockedBatchId = _getLockedBatchId(
            locationData,
          );

          throw Exception(
            'Lokasi $cleanLocation baru saja '
            'digunakan oleh batch '
            '$lockedBatchId. Pilih lokasi lain.',
          );
        }

        final storedProductCode = _normalizeProductCode(
          (productData['code'] ?? cleanInputProductCode).toString(),
        );

        final storedProductName =
            (productData['name'] ?? cleanInputProductName).toString().trim();

        final storedUnit =
            (productData['unit'] ?? cleanInputUnit).toString().trim();

        if (storedProductCode.isEmpty) {
          throw Exception(
            'Kode produk pada database '
            'tidak valid.',
          );
        }

        if (storedProductName.isEmpty) {
          throw Exception(
            'Nama produk pada database '
            'tidak valid.',
          );
        }

        if (storedUnit.isEmpty) {
          throw Exception(
            'Satuan produk pada database '
            'tidak valid.',
          );
        }

        var lastNumber = existingMaxSequence;

        if (counterSnapshot.exists && counterSnapshot.data() != null) {
          final counterLastNumber = _parseInt(
            counterSnapshot.data()!['lastNumber'],
          );

          if (counterLastNumber > lastNumber) {
            lastNumber = counterLastNumber;
          }
        }

        final nextNumber = lastNumber + 1;

        final batchCode = _buildBatchCode(
          receivedAt: cleanReceivedAt,
          productCode: storedProductCode,
          sequenceNumber: nextNumber,
        );

        final batchRef = _batchesCollection.doc(
          batchCode,
        );

        final stockInTransactionRef = _transactionsCollection.doc(
          'STOCK-IN-$batchCode',
        );

        final existingBatchSnapshot = await transaction.get(
          batchRef,
        );

        if (existingBatchSnapshot.exists) {
          throw Exception(
            'Kode batch $batchCode sudah ada. '
            'Silakan coba simpan ulang.',
          );
        }

        final now = Timestamp.now();

        final searchKeywords = buildSearchKeywords(
          batchId: batchCode,
          batchCode: batchCode,
          qrCodeValue: batchCode,
          productId: cleanProductId,
          productName: storedProductName,
          productCode: storedProductCode,
          storageLocation: cleanLocation,
          createdBy: cleanCreatedBy,
          createdByName: cleanCreatedByName,
          unit: storedUnit,
          status: 'active',
          initialQty: qty,
          remainingQty: qty,
          receivedAt: cleanReceivedAt,
          notes: cleanNotes,
        );

        transaction.set(
          counterRef,
          {
            'id': counterId,
            'productId': cleanProductId,
            'productCode': storedProductCode,
            'lastNumber': nextNumber,
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );

        transaction.set(
          batchRef,
          {
            'id': batchCode,
            'productId': cleanProductId,
            'productName': storedProductName,
            'productCode': storedProductCode,
            'batchCode': batchCode,
            'receivedAt': Timestamp.fromDate(
              cleanReceivedAt,
            ),
            'initialQty': qty,
            'remainingQty': qty,
            'unit': storedUnit,
            'qrCodeValue': batchCode,
            'status': 'active',
            'storageLocation': cleanLocation,
            'createdBy': cleanCreatedBy,
            'createdByName': cleanCreatedByName,
            'notes': cleanNotes,
            'searchKeywords': searchKeywords,
            'createdAt': now,
            'updatedAt': now,
          },
        );

        transaction.update(
          productRef,
          {
            'totalStock': FieldValue.increment(qty),
            'updatedAt': now,
          },
        );

        transaction.set(
          stockInTransactionRef,
          {
            'id': stockInTransactionRef.id,
            'type': 'stock_in',
            'productId': cleanProductId,
            'productName': storedProductName,
            'batchId': batchCode,
            'batchCode': batchCode,
            'qty': qty,
            'unit': storedUnit,
            'performedBy': cleanCreatedBy,
            'performedByName': cleanCreatedByName,
            'notes': cleanNotes,
            'createdAt': now,
          },
        );

        transaction.set(
          locationRef,
          _buildOccupiedLockData(
            location: cleanLocation,
            batchId: batchCode,
            batchCode: batchCode,
            productId: cleanProductId,
            productName: storedProductName,
            remainingQty: qty,
            occupiedAt: now,
            updatedAt: now,
          ),
          SetOptions(merge: true),
        );

        return {
          'batchId': batchCode,
          'batchCode': batchCode,
          'qrCodeValue': batchCode,
          'transactionId': stockInTransactionRef.id,
        };
      },
    );
  }

  Future<void> moveBatchFromBackupToMain({
    required String batchId,
    required String targetLocation,
  }) async {
    final cleanBatchId = batchId.trim();

    final cleanTargetLocation = _normalizeLocation(
      targetLocation,
    );

    if (cleanBatchId.isEmpty) {
      throw Exception(
        'ID batch tidak valid.',
      );
    }

    if (!isMainStorageLocation(
      cleanTargetLocation,
    )) {
      throw Exception(
        'Lokasi tujuan harus berada '
        'di dalam gudang.',
      );
    }

    final authUser = _firebaseAuth.currentUser;

    if (authUser == null) {
      throw Exception(
        'Sesi pengguna tidak ditemukan. '
        'Silakan login kembali.',
      );
    }

    await synchronizeStorageLocationLocks(
      force: true,
    );

    final batchRef = _batchesCollection.doc(
      cleanBatchId,
    );

    final userRef = _usersCollection.doc(
      authUser.uid,
    );

    final movementRef = _batchMovementsCollection.doc();

    await _firestore.runTransaction<void>(
      (transaction) async {
        final batchSnapshot = await transaction.get(
          batchRef,
        );

        final userSnapshot = await transaction.get(
          userRef,
        );

        if (!batchSnapshot.exists || batchSnapshot.data() == null) {
          throw Exception(
            'Batch tidak ditemukan.',
          );
        }

        final batchData = batchSnapshot.data()!;

        final currentStatus =
            (batchData['status'] ?? '').toString().toLowerCase().trim();

        final currentRemainingQty = _parseInt(
          batchData['remainingQty'],
        );

        final currentLocation = _normalizeLocation(
          (batchData['storageLocation'] ?? '').toString(),
        );

        if (currentStatus != 'active' || currentRemainingQty <= 0) {
          throw Exception(
            'Batch sudah tidak aktif atau '
            'stoknya telah habis.',
          );
        }

        if (!isBackupStorageLocation(
          currentLocation,
        )) {
          throw Exception(
            'Batch hanya dapat dipindahkan '
            'apabila berada di lokasi X1-X5.',
          );
        }

        final sourceLocationRef = _storageLocationsCollection.doc(
          currentLocation,
        );

        final targetLocationRef = _storageLocationsCollection.doc(
          cleanTargetLocation,
        );

        final sourceLockSnapshot = await transaction.get(
          sourceLocationRef,
        );

        final targetLockSnapshot = await transaction.get(
          targetLocationRef,
        );

        final sourceLockData = sourceLockSnapshot.data();

        final targetLockData = targetLockSnapshot.data();

        if (!_isLocationLockOccupied(
              sourceLockData,
            ) ||
            _getLockedBatchId(
                  sourceLockData,
                ) !=
                cleanBatchId) {
          throw Exception(
            'Data lokasi asal '
            '$currentLocation tidak sesuai '
            'dengan batch ini.',
          );
        }

        if (_isLocationLockOccupied(
          targetLockData,
        )) {
          final lockedBatchId = _getLockedBatchId(
            targetLockData,
          );

          throw Exception(
            'Lokasi $cleanTargetLocation '
            'baru saja digunakan oleh batch '
            '$lockedBatchId.',
          );
        }

        final movedByName = _resolveUserName(
          authUser: authUser,
          userData: userSnapshot.data(),
        );

        final batchCode =
            (batchData['batchCode'] ?? cleanBatchId).toString().trim();

        final productId = (batchData['productId'] ?? '').toString().trim();

        final productName = (batchData['productName'] ?? '').toString().trim();

        final unit = (batchData['unit'] ?? 'Karung').toString().trim();

        final now = Timestamp.now();

        final updatedSearchKeywords = buildSearchKeywordsFromMap(
          documentId: cleanBatchId,
          data: batchData,
          overrideStorageLocation: cleanTargetLocation,
        );

        transaction.update(
          batchRef,
          {
            'storageLocation': cleanTargetLocation,
            'searchKeywords': updatedSearchKeywords,
            'updatedAt': now,
            'lastLocationTransferAt': now,
            'lastLocationTransferBy': authUser.uid,
            'lastLocationTransferByName': movedByName,
            'lastLocationTransferFrom': currentLocation,
            'lastLocationTransferTo': cleanTargetLocation,
          },
        );

        transaction.set(
          sourceLocationRef,
          _buildFreeLockData(
            location: currentLocation,
            updatedAt: now,
          ),
          SetOptions(merge: true),
        );

        transaction.set(
          targetLocationRef,
          _buildOccupiedLockData(
            location: cleanTargetLocation,
            batchId: cleanBatchId,
            batchCode: batchCode,
            productId: productId,
            productName: productName,
            remainingQty: currentRemainingQty,
            occupiedAt: now,
            updatedAt: now,
          ),
          SetOptions(merge: true),
        );

        transaction.set(
          movementRef,
          {
            'id': movementRef.id,
            'type': 'location_transfer',
            'batchId': cleanBatchId,
            'batchCode': batchCode,
            'productId': productId,
            'productName': productName,
            'fromLocation': currentLocation,
            'toLocation': cleanTargetLocation,
            'remainingQty': currentRemainingQty,
            'unit': unit,
            'movedBy': authUser.uid,
            'movedByName': movedByName,
            'movedAt': now,
            'createdAt': now,
          },
        );
      },
    );

    _storageLocksSynchronized = true;
  }

  Stream<List<BatchModel>> getBatchesStream() {
    return _batchesCollection
        .orderBy(
          'receivedAt',
          descending: true,
        )
        .snapshots()
        .map(
      (snapshot) {
        return snapshot.docs
            .map(
              (document) => BatchModel.fromMap(
                document.id,
                document.data(),
              ),
            )
            .toList();
      },
    );
  }

  Stream<List<BatchModel>> getActiveBatchesStream({
    String? productId,
    DateTime? receivedDate,
    String searchQuery = '',
  }) {
    Query<Map<String, dynamic>> query = _batchesCollection.where(
      'status',
      isEqualTo: 'active',
    );

    final cleanProductId = productId?.trim() ?? '';

    final cleanSearchKeyword = normalizeSearchKeyword(
      searchQuery,
    );

    if (cleanProductId.isNotEmpty) {
      query = query.where(
        'productId',
        isEqualTo: cleanProductId,
      );
    }

    if (receivedDate != null) {
      final startDate = DateTime(
        receivedDate.year,
        receivedDate.month,
        receivedDate.day,
      );

      final endDate = startDate.add(
        const Duration(days: 1),
      );

      query = query
          .where(
            'receivedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              startDate,
            ),
          )
          .where(
            'receivedAt',
            isLessThan: Timestamp.fromDate(
              endDate,
            ),
          );
    }

    if (cleanSearchKeyword.isNotEmpty) {
      query = query.where(
        'searchKeywords',
        arrayContains: cleanSearchKeyword,
      );
    }

    return query.snapshots().map(
      (snapshot) {
        final batches = snapshot.docs
            .map(
              (document) => BatchModel.fromMap(
                document.id,
                document.data(),
              ),
            )
            .where(
              (batch) => batch.remainingQty > 0,
            )
            .toList();

        batches.sort(
          (first, second) {
            final receivedAtComparison = second.receivedAt.compareTo(
              first.receivedAt,
            );

            if (receivedAtComparison != 0) {
              return receivedAtComparison;
            }

            final createdAtComparison = second.createdAt.compareTo(
              first.createdAt,
            );

            if (createdAtComparison != 0) {
              return createdAtComparison;
            }

            return second.batchCode.toUpperCase().compareTo(
                  first.batchCode.toUpperCase(),
                );
          },
        );

        return batches;
      },
    );
  }

  Future<BatchPageResult> getBatchesPage({
    String statusFilter = 'Habis',
    String? productId,
    DateTime? receivedDate,
    String searchQuery = '',
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    final cleanStatusFilter = statusFilter.trim().toLowerCase();

    final cleanProductId = productId?.trim() ?? '';

    final cleanSearchKeyword = normalizeSearchKeyword(
      searchQuery,
    );

    if (limit <= 0) {
      throw Exception(
        'Batas data harus lebih dari 0.',
      );
    }

    Query<Map<String, dynamic>> query = _batchesCollection;

    if (cleanStatusFilter == 'aktif') {
      query = query.where(
        'status',
        isEqualTo: 'active',
      );
    } else if (cleanStatusFilter == 'habis') {
      query = query.where(
        'status',
        whereIn: const [
          'empty',
          'depleted',
        ],
      );
    }

    if (cleanProductId.isNotEmpty) {
      query = query.where(
        'productId',
        isEqualTo: cleanProductId,
      );
    }

    if (receivedDate != null) {
      final startDate = DateTime(
        receivedDate.year,
        receivedDate.month,
        receivedDate.day,
      );

      final endDate = startDate.add(
        const Duration(days: 1),
      );

      query = query
          .where(
            'receivedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              startDate,
            ),
          )
          .where(
            'receivedAt',
            isLessThan: Timestamp.fromDate(
              endDate,
            ),
          );
    }

    if (cleanSearchKeyword.isNotEmpty) {
      query = query.where(
        'searchKeywords',
        arrayContains: cleanSearchKeyword,
      );
    }

    query = query
        .orderBy(
          'receivedAt',
          descending: true,
        )
        .limit(limit + 1);

    if (startAfterDocument != null) {
      query = query.startAfterDocument(
        startAfterDocument,
      );
    }

    final snapshot = await query.get();

    final hasMore = snapshot.docs.length > limit;

    final visibleDocuments =
        hasMore ? snapshot.docs.take(limit).toList() : snapshot.docs;

    final batches = visibleDocuments
        .map(
          (document) => BatchModel.fromMap(
            document.id,
            document.data(),
          ),
        )
        .toList();

    return BatchPageResult(
      batches: batches,
      lastDocument: visibleDocuments.isEmpty ? null : visibleDocuments.last,
      hasMore: hasMore,
    );
  }

  Future<BatchModel?> getBatchById(
    String batchId,
  ) async {
    final document = await _batchesCollection.doc(batchId).get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    return BatchModel.fromMap(
      document.id,
      document.data()!,
    );
  }

  Future<BatchModel?> getBatchByQrValue(
    String qrCodeValue,
  ) async {
    final cleanQrValue = qrCodeValue.trim();

    if (cleanQrValue.isEmpty) {
      return null;
    }

    final documentById = await _batchesCollection.doc(cleanQrValue).get();

    if (documentById.exists && documentById.data() != null) {
      return BatchModel.fromMap(
        documentById.id,
        documentById.data()!,
      );
    }

    final qrSnapshot = await _batchesCollection
        .where(
          'qrCodeValue',
          isEqualTo: cleanQrValue,
        )
        .limit(1)
        .get();

    if (qrSnapshot.docs.isNotEmpty) {
      final document = qrSnapshot.docs.first;

      return BatchModel.fromMap(
        document.id,
        document.data(),
      );
    }

    final batchCodeSnapshot = await _batchesCollection
        .where(
          'batchCode',
          isEqualTo: cleanQrValue,
        )
        .limit(1)
        .get();

    if (batchCodeSnapshot.docs.isNotEmpty) {
      final document = batchCodeSnapshot.docs.first;

      return BatchModel.fromMap(
        document.id,
        document.data(),
      );
    }

    return null;
  }

  Future<BatchModel?> getOldestActiveBatchByProductId(
    String productId,
  ) async {
    final cleanProductId = productId.trim();

    if (cleanProductId.isEmpty) {
      return null;
    }

    final snapshot = await _batchesCollection
        .where(
          'productId',
          isEqualTo: cleanProductId,
        )
        .get();

    final batches = snapshot.docs
        .map(
          (document) => BatchModel.fromMap(
            document.id,
            document.data(),
          ),
        )
        .where(
          _isBatchEligibleForFifo,
        )
        .toList();

    if (batches.isEmpty) {
      return null;
    }

    batches.sort(
      _compareBatchesForFifo,
    );

    return batches.first;
  }

  Future<void> decreaseBatchStock({
    required String batchId,
    required int qty,
  }) async {
    final cleanBatchId = batchId.trim();

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

    await synchronizeStorageLocationLocks(
      force: true,
    );

    final batchRef = _batchesCollection.doc(
      cleanBatchId,
    );

    await _firestore.runTransaction<void>(
      (transaction) async {
        final batchSnapshot = await transaction.get(
          batchRef,
        );

        if (!batchSnapshot.exists || batchSnapshot.data() == null) {
          throw Exception(
            'Batch tidak ditemukan.',
          );
        }

        final data = batchSnapshot.data()!;

        final currentRemainingQty = _parseInt(
          data['remainingQty'],
        );

        final currentStatus =
            (data['status'] ?? '').toString().toLowerCase().trim();

        final currentLocation = _normalizeLocation(
          (data['storageLocation'] ?? '').toString(),
        );

        if (currentStatus != 'active' || currentRemainingQty <= 0) {
          throw Exception(
            'Batch sudah tidak aktif atau '
            'stoknya telah habis.',
          );
        }

        if (currentRemainingQty < qty) {
          throw Exception(
            'Jumlah keluar melebihi '
            'sisa stok batch.',
          );
        }

        if (!_isValidStorageLocation(
          currentLocation,
        )) {
          throw Exception(
            'Lokasi batch '
            '$currentLocation tidak valid.',
          );
        }

        final locationRef = _storageLocationsCollection.doc(
          currentLocation,
        );

        final locationSnapshot = await transaction.get(
          locationRef,
        );

        final locationData = locationSnapshot.data();

        if (!_isLocationLockOccupied(
              locationData,
            ) ||
            _getLockedBatchId(
                  locationData,
                ) !=
                cleanBatchId) {
          throw Exception(
            'Data penguncian lokasi '
            '$currentLocation tidak sesuai '
            'dengan batch.',
          );
        }

        final newRemainingQty = currentRemainingQty - qty;

        final newStatus = newRemainingQty == 0 ? 'empty' : 'active';

        final now = Timestamp.now();

        final updatedSearchKeywords = buildSearchKeywordsFromMap(
          documentId: cleanBatchId,
          data: data,
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

        if (newRemainingQty == 0) {
          transaction.set(
            locationRef,
            _buildFreeLockData(
              location: currentLocation,
              updatedAt: now,
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
      },
    );

    _storageLocksSynchronized = true;
  }
}
