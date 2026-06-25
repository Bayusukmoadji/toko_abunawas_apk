import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/app_user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AppUserModel?> getUserByUid(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return AppUserModel.fromMap({
        ...doc.data()!,
        'uid': doc.data()!['uid'] ?? doc.id,
      });
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

  Future<void> createUserWithRole({
    required String name,
    required String email,
    required String password,
    required String role,
    required bool isActive,
  }) async {
    final cleanedName = name.trim();
    final cleanedEmail = email.trim().toLowerCase();
    final cleanedRole = role.trim().toLowerCase();

    if (cleanedName.isEmpty) {
      throw Exception('Nama pengguna tidak boleh kosong.');
    }

    if (cleanedEmail.isEmpty) {
      throw Exception('Email tidak boleh kosong.');
    }

    if (password.trim().length < 6) {
      throw Exception('Password minimal 6 karakter.');
    }

    if (cleanedRole != 'owner' && cleanedRole != 'karyawan') {
      throw Exception('Role tidak valid.');
    }

    User? createdUser;

    try {
      final secondaryApp = await _getOrCreateSecondaryFirebaseApp();
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      await secondaryAuth.signOut();

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: cleanedEmail,
        password: password.trim(),
      );

      createdUser = credential.user;

      if (createdUser == null) {
        throw Exception('UID pengguna baru tidak ditemukan.');
      }

      await createdUser.updateDisplayName(cleanedName);

      final now = Timestamp.now();

      await _firestore.collection('users').doc(createdUser.uid).set({
        'uid': createdUser.uid,
        'name': cleanedName,
        'email': cleanedEmail,
        'role': cleanedRole,
        'isActive': isActive,
        'createdAt': now,
        'updatedAt': now,
      });

      await secondaryAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthError(e));
    } catch (e) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {
          // Jika rollback gagal, error utama tetap ditampilkan.
        }
      }

      throw Exception('Gagal membuat pengguna: $e');
    }
  }

  Future<FirebaseApp> _getOrCreateSecondaryFirebaseApp() async {
    const secondaryAppName = 'secondary_user_creation_app';

    try {
      return Firebase.app(secondaryAppName);
    } catch (_) {
      return Firebase.initializeApp(
        name: secondaryAppName,
        options: Firebase.app().options,
      );
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email sudah digunakan oleh akun lain.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      case 'operation-not-allowed':
        return 'Metode login email/password belum diaktifkan di Firebase Authentication.';
      case 'network-request-failed':
        return 'Koneksi internet bermasalah.';
      default:
        return e.message ?? 'Terjadi kesalahan saat membuat akun.';
    }
  }

  Future<void> updateUserRole({
    required String uid,
    required String role,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'role': role,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> updateUserActiveStatus({
    required String uid,
    required bool isActive,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'isActive': isActive,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteUserAccess({
    required String uid,
  }) async {
    await _firestore.collection('users').doc(uid).delete();
  }
}
