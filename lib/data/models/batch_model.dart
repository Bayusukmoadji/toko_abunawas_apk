import 'package:cloud_firestore/cloud_firestore.dart';

class BatchModel {
  final String id;
  final String productId;
  final String productName;
  final String batchCode;
  final Timestamp receivedAt;
  final int initialQty;
  final int remainingQty;
  final String unit;
  final String qrCodeValue;
  final String status;
  final String storageLocation;
  final String createdBy;
  final String createdByName;
  final String notes;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  BatchModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.batchCode,
    required this.receivedAt,
    required this.initialQty,
    required this.remainingQty,
    required this.unit,
    required this.qrCodeValue,
    required this.status,
    required this.storageLocation,
    required this.createdBy,
    required this.createdByName,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BatchModel.fromMap(String id, Map<String, dynamic> map) {
    return BatchModel(
      id: id,
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      batchCode: map['batchCode'] ?? '',
      receivedAt: map['receivedAt'] ?? Timestamp.now(),
      initialQty: map['initialQty'] ?? 0,
      remainingQty: map['remainingQty'] ?? 0,
      unit: map['unit'] ?? '',
      qrCodeValue: map['qrCodeValue'] ?? '',
      status: map['status'] ?? 'active',
      storageLocation: map['storageLocation'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? '',
      notes: map['notes'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'batchCode': batchCode,
      'receivedAt': receivedAt,
      'initialQty': initialQty,
      'remainingQty': remainingQty,
      'unit': unit,
      'qrCodeValue': qrCodeValue,
      'status': status,
      'storageLocation': storageLocation,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
