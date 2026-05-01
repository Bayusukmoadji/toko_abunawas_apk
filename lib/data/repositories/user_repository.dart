import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AppUserModel?> getUserByUid(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return AppUserModel.fromMap(doc.data()!);
    } catch (e) {
      throw Exception('Gagal mengambil data user: $e');
    }
  }

  Stream<List<AppUserModel>> getUsersStream() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final users = snapshot.docs.map((doc) {
        final data = doc.data();

        return AppUserModel.fromMap({
          ...data,
          'uid': data['uid'] ?? doc.id,
        });
      }).toList();

      users.sort((a, b) => a.name.compareTo(b.name));

      return users;
    });
  }

  Future<void> updateUserRole({
    required String uid,
    required String role,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'role': role,
    });
  }

  Future<void> updateUserActiveStatus({
    required String uid,
    required bool isActive,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'isActive': isActive,
    });
  }
}
