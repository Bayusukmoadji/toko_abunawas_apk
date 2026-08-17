import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user_model.dart';
import '../models/batch_condition_check_model.dart';
import '../models/batch_model.dart';

class BatchConditionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String statusNormal = 'normal';
  static const String statusNeedsAttention = 'needs_attention';

  static const String packagingGood = 'good';
  static const String packagingProblem = 'problem';

  static const String odorNormal = 'normal';
  static const String odorAbnormal = 'abnormal';

  static const String pestNone = 'none';
  static const String pestPresent = 'present';

  static const String physicalNormal = 'normal';
  static const String physicalChanged = 'changed';

  static const String storageDry = 'dry';
  static const String storageHumid = 'humid';

  CollectionReference<Map<String, dynamic>> get _historyCollection {
    return _firestore.collection('batch_condition_checks');
  }

  CollectionReference<Map<String, dynamic>> get _currentCollection {
    return _firestore.collection('batch_condition_current');
  }

  CollectionReference<Map<String, dynamic>> get _batchesCollection {
    return _firestore.collection('batches');
  }

  static String evaluateStatus({
    required String packagingCondition,
    required String odorCondition,
    required String pestCondition,
    required String physicalCondition,
    required String storageCondition,
  }) {
    final allNormal = packagingCondition == packagingGood &&
        odorCondition == odorNormal &&
        pestCondition == pestNone &&
        physicalCondition == physicalNormal &&
        storageCondition == storageDry;

    return allNormal ? statusNormal : statusNeedsAttention;
  }

  static List<String> buildFindings({
    required String packagingCondition,
    required String odorCondition,
    required String pestCondition,
    required String physicalCondition,
    required String storageCondition,
  }) {
    final findings = <String>[];

    if (packagingCondition == packagingProblem) {
      findings.add('Kondisi kemasan bermasalah');
    }

    if (odorCondition == odorAbnormal) {
      findings.add('Bau beras tidak normal');
    }

    if (pestCondition == pestPresent) {
      findings.add('Ditemukan hama atau kutu');
    }

    if (physicalCondition == physicalChanged) {
      findings.add('Terdapat perubahan kondisi fisik beras');
    }

    if (storageCondition == storageHumid) {
      findings.add('Kondisi tempat penyimpanan lembap');
    }

    return findings;
  }

  Future<void> saveConditionCheck({
    required BatchModel batch,
    required AppUserModel user,
    required String packagingCondition,
    required String odorCondition,
    required String pestCondition,
    required String physicalCondition,
    required String storageCondition,
    String notes = '',
  }) async {
    if (batch.id.trim().isEmpty) {
      throw Exception('Batch tidak valid.');
    }

    if (user.uid.trim().isEmpty) {
      throw Exception('Pengguna tidak valid.');
    }

    final resultStatus = evaluateStatus(
      packagingCondition: packagingCondition,
      odorCondition: odorCondition,
      pestCondition: pestCondition,
      physicalCondition: physicalCondition,
      storageCondition: storageCondition,
    );

    final findings = buildFindings(
      packagingCondition: packagingCondition,
      odorCondition: odorCondition,
      pestCondition: pestCondition,
      physicalCondition: physicalCondition,
      storageCondition: storageCondition,
    );

    final historyRef = _historyCollection.doc();
    final currentRef = _currentCollection.doc(batch.id);
    final batchRef = _batchesCollection.doc(batch.id);

    await _firestore.runTransaction<void>((transaction) async {
      final batchSnapshot = await transaction.get(batchRef);

      if (!batchSnapshot.exists || batchSnapshot.data() == null) {
        throw Exception('Batch tidak ditemukan.');
      }

      final batchData = batchSnapshot.data()!;

      final currentStatus =
          (batchData['status'] ?? '').toString().toLowerCase().trim();

      final remainingQty = (batchData['remainingQty'] as num?)?.toInt() ?? 0;

      if (currentStatus != 'active' || remainingQty <= 0) {
        throw Exception(
          'Pemeriksaan hanya dapat dilakukan pada batch aktif '
          'yang masih memiliki stok.',
        );
      }

      final batchCode = (batchData['batchCode'] ?? batch.id).toString().trim();

      final productId = (batchData['productId'] ?? '').toString().trim();

      final productName = (batchData['productName'] ?? '').toString().trim();

      final now = Timestamp.now();

      final historyData = <String, dynamic>{
        'id': historyRef.id,
        'batchId': batch.id,
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
        'notes': notes.trim(),
        'checkedById': user.uid,
        'checkedByName': user.name.trim(),
        'checkedAt': now,
      };

      final currentData = <String, dynamic>{
        'id': batch.id,
        'batchId': batch.id,
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
        'notes': notes.trim(),
        'checkedById': user.uid,
        'checkedByName': user.name.trim(),
        'checkedAt': now,
      };

      transaction.set(
        historyRef,
        historyData,
      );

      transaction.set(
        currentRef,
        currentData,
      );
    });
  }

  Stream<BatchConditionCheckModel?> getCurrentConditionStream(
    String batchId,
  ) {
    return _currentCollection.doc(batchId).snapshots().map(
      (snapshot) {
        final data = snapshot.data();

        if (!snapshot.exists || data == null) {
          return null;
        }

        return BatchConditionCheckModel.fromMap(
          snapshot.id,
          data,
        );
      },
    );
  }

  Stream<List<BatchConditionCheckModel>> getHistoryStream(
    String batchId,
  ) {
    return _historyCollection
        .where(
          'batchId',
          isEqualTo: batchId,
        )
        .snapshots()
        .map(
      (snapshot) {
        final items = snapshot.docs
            .map(
              (document) => BatchConditionCheckModel.fromMap(
                document.id,
                document.data(),
              ),
            )
            .toList();

        items.sort(
          (first, second) => second.checkedAt.compareTo(first.checkedAt),
        );

        return items;
      },
    );
  }

  Stream<List<BatchConditionCheckModel>> getAllCurrentConditionsStream() {
    return _currentCollection.snapshots().map(
      (snapshot) {
        final items = snapshot.docs
            .map(
              (document) => BatchConditionCheckModel.fromMap(
                document.id,
                document.data(),
              ),
            )
            .toList();

        items.sort(
          (first, second) => second.checkedAt.compareTo(first.checkedAt),
        );

        return items;
      },
    );
  }

  Stream<List<BatchConditionCheckModel>> getNeedsAttentionStream() {
    return getAllCurrentConditionsStream().map(
      (items) => items
          .where(
            (item) => item.resultStatus == statusNeedsAttention,
          )
          .toList(),
    );
  }
}
