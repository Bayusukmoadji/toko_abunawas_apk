import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String type;

  final String productId;
  final String productName;

  final String batchId;
  final String batchCode;

  final int qty;
  final String unit;

  final String performedBy;
  final String performedByName;

  final String notes;

  /// Identitas satu permintaan transaksi.
  ///
  /// Pada FIFO lintas-batch, beberapa dokumen stock_out
  /// dapat memiliki transactionGroupId yang sama.
  ///
  /// Contoh:
  /// GROUP-ABC
  /// ├── batch 1 -> 20 karung
  /// └── batch 2 -> 5 karung
  final String transactionGroupId;

  /// Field tambahan untuk audit transaksi stok keluar.
  final String? storageLocation;
  final int? remainingQtyBefore;
  final int? remainingQtyAfter;
  final int? totalStockAfter;

  final Timestamp createdAt;

  const TransactionModel({
    required this.id,
    required this.type,
    required this.productId,
    required this.productName,
    required this.batchId,
    required this.batchCode,
    required this.qty,
    required this.unit,
    required this.performedBy,
    required this.performedByName,
    required this.notes,
    required this.transactionGroupId,
    required this.createdAt,
    this.storageLocation,
    this.remainingQtyBefore,
    this.remainingQtyAfter,
    this.totalStockAfter,
  });

  static int? _parseNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static int _parseInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static Timestamp _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value;
    }

    if (value is DateTime) {
      return Timestamp.fromDate(value);
    }

    return Timestamp.now();
  }

  /// Digunakan untuk data historis yang dibuat sebelum
  /// field transactionGroupId diterapkan.
  ///
  /// Jika document ID berbentuk:
  ///
  /// ABC123_01
  /// ABC123_02
  ///
  /// maka group ID akan diturunkan menjadi:
  ///
  /// ABC123
  ///
  /// Untuk dokumen lama biasa, document ID menjadi fallback.
  static String _deriveTransactionGroupId(
    String documentId,
    dynamic rawGroupId,
  ) {
    final String explicitGroupId = rawGroupId?.toString().trim() ?? '';

    if (explicitGroupId.isNotEmpty) {
      return explicitGroupId;
    }

    final RegExp suffixPattern = RegExp(
      r'^(.*)_([0-9]{2})$',
    );

    final RegExpMatch? match = suffixPattern.firstMatch(documentId);

    if (match != null) {
      final String prefix = match.group(1)?.trim() ?? '';

      if (prefix.isNotEmpty) {
        return prefix;
      }
    }

    return documentId;
  }

  factory TransactionModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return TransactionModel(
      id: id,
      type: (map['type'] ?? '').toString().trim(),
      productId: (map['productId'] ?? '').toString().trim(),
      productName: (map['productName'] ?? '').toString().trim(),
      batchId: (map['batchId'] ?? '').toString().trim(),
      batchCode: (map['batchCode'] ?? '').toString().trim(),
      qty: _parseInt(
        map['qty'],
      ),
      unit: (map['unit'] ?? '').toString().trim(),
      performedBy: (map['performedBy'] ?? '').toString().trim(),
      performedByName: (map['performedByName'] ?? '').toString().trim(),
      notes: (map['notes'] ?? '').toString().trim(),
      transactionGroupId: _deriveTransactionGroupId(
        id,
        map['transactionGroupId'],
      ),
      storageLocation: map['storageLocation']?.toString().trim().isEmpty == true
          ? null
          : map['storageLocation']?.toString().trim(),
      remainingQtyBefore: _parseNullableInt(
        map['remainingQtyBefore'],
      ),
      remainingQtyAfter: _parseNullableInt(
        map['remainingQtyAfter'],
      ),
      totalStockAfter: _parseNullableInt(
        map['totalStockAfter'],
      ),
      createdAt: _parseTimestamp(
        map['createdAt'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = <String, dynamic>{
      'type': type,
      'productId': productId,
      'productName': productName,
      'batchId': batchId,
      'batchCode': batchCode,
      'qty': qty,
      'unit': unit,
      'performedBy': performedBy,
      'performedByName': performedByName,
      'notes': notes,
      'transactionGroupId': transactionGroupId,
      'createdAt': createdAt,
    };

    if (storageLocation != null) {
      data['storageLocation'] = storageLocation;
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

    return data;
  }

  bool get isStockIn {
    return type.trim().toLowerCase() == 'stock_in';
  }

  bool get isStockOut {
    return type.trim().toLowerCase() == 'stock_out';
  }

  bool get hasCrossBatchGroup {
    return transactionGroupId.isNotEmpty;
  }
}
