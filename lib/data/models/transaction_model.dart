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
  final Timestamp createdAt;

  TransactionModel({
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
    required this.createdAt,
  });

  factory TransactionModel.fromMap(String id, Map<String, dynamic> map) {
    return TransactionModel(
      id: id,
      type: map['type'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      batchId: map['batchId'] ?? '',
      batchCode: map['batchCode'] ?? '',
      qty: map['qty'] ?? 0,
      unit: map['unit'] ?? '',
      performedBy: map['performedBy'] ?? '',
      performedByName: map['performedByName'] ?? '',
      notes: map['notes'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
      'createdAt': createdAt,
    };
  }
}
