import 'package:cloud_firestore/cloud_firestore.dart';

class BatchConditionCheckModel {
  final String id;
  final String batchId;
  final String batchCode;
  final String productId;
  final String productName;

  final String packagingCondition;
  final String odorCondition;
  final String pestCondition;
  final String physicalCondition;
  final String storageCondition;

  final String resultStatus;
  final List<String> findings;
  final String notes;

  final String checkedById;
  final String checkedByName;
  final Timestamp checkedAt;

  const BatchConditionCheckModel({
    required this.id,
    required this.batchId,
    required this.batchCode,
    required this.productId,
    required this.productName,
    required this.packagingCondition,
    required this.odorCondition,
    required this.pestCondition,
    required this.physicalCondition,
    required this.storageCondition,
    required this.resultStatus,
    required this.findings,
    required this.notes,
    required this.checkedById,
    required this.checkedByName,
    required this.checkedAt,
  });

  bool get needsAttention => resultStatus == 'needs_attention';

  String get statusLabel {
    return needsAttention ? 'Perlu Perhatian' : 'Normal';
  }

  factory BatchConditionCheckModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return BatchConditionCheckModel(
      id: id,
      batchId: (map['batchId'] ?? '').toString(),
      batchCode: (map['batchCode'] ?? '').toString(),
      productId: (map['productId'] ?? '').toString(),
      productName: (map['productName'] ?? '').toString(),
      packagingCondition: (map['packagingCondition'] ?? '').toString(),
      odorCondition: (map['odorCondition'] ?? '').toString(),
      pestCondition: (map['pestCondition'] ?? '').toString(),
      physicalCondition: (map['physicalCondition'] ?? '').toString(),
      storageCondition: (map['storageCondition'] ?? '').toString(),
      resultStatus: (map['resultStatus'] ?? 'normal').toString(),
      findings: List<String>.from(
        (map['findings'] as List<dynamic>? ?? const [])
            .map((item) => item.toString()),
      ),
      notes: (map['notes'] ?? '').toString(),
      checkedById: (map['checkedById'] ?? '').toString(),
      checkedByName: (map['checkedByName'] ?? '').toString(),
      checkedAt: map['checkedAt'] is Timestamp
          ? map['checkedAt'] as Timestamp
          : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batchId': batchId,
      'batchCode': batchCode,
      'productId': productId,
      'productName': productName,
      'packagingCondition': packagingCondition,
      'odorCondition': odorCondition,
      'pestCondition': pestCondition,
      'physicalCondition': physicalCondition,
      'storageCondition': storageCondition,
      'resultStatus': resultStatus,
      'findings': findings,
      'notes': notes,
      'checkedById': checkedById,
      'checkedByName': checkedByName,
      'checkedAt': checkedAt,
    };
  }
}
