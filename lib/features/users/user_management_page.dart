import 'package:flutter/material.dart';
import '../../data/models/app_user_model.dart';
import '../../data/repositories/user_repository.dart';

class UserManagementPage extends StatelessWidget {
  final AppUserModel currentUser;

  UserManagementPage({
    super.key,
    required this.currentUser,
  });

  final UserRepository _userRepository = UserRepository();

  bool _isCurrentUser(AppUserModel user) {
    return user.uid == currentUser.uid;
  }

  String _getRoleLabel(String role) {
    final normalizedRole = role.toLowerCase().trim();

    if (normalizedRole == 'owner' || normalizedRole == 'pemilik') {
      return 'Pemilik Toko';
    }

    return 'Karyawan';
  }

  Color _getStatusColor(bool isActive) {
    return isActive ? Colors.green : Colors.red;
  }

  Future<void> _updateRole({
    required BuildContext context,
    required AppUserModel user,
    required String newRole,
  }) async {
    try {
      await _userRepository.updateUserRole(
        uid: user.uid,
        role: newRole,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Role pengguna berhasil diperbarui.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui role: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateActiveStatus({
    required BuildContext context,
    required AppUserModel user,
    required bool isActive,
  }) async {
    try {
      await _userRepository.updateUserActiveStatus(
        uid: user.uid,
        isActive: isActive,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive
                ? 'Pengguna berhasil diaktifkan.'
                : 'Pengguna berhasil dinonaktifkan.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui status pengguna: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildUserCard({
    required BuildContext context,
    required AppUserModel user,
  }) {
    final isSelf = _isCurrentUser(user);
    final normalizedRole = user.role.toLowerCase().trim();
    final selectedRole =
        normalizedRole == 'owner' || normalizedRole == 'pemilik'
            ? 'owner'
            : 'karyawan';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.name.isEmpty ? '(Nama belum diisi)' : user.name,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(user.email),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Status: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  user.isActive ? 'Aktif' : 'Tidak Aktif',
                  style: TextStyle(
                    color: _getStatusColor(user.isActive),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role Pengguna',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'owner',
                  child: Text('Pemilik Toko'),
                ),
                DropdownMenuItem(
                  value: 'karyawan',
                  child: Text('Karyawan'),
                ),
              ],
              onChanged: isSelf
                  ? null
                  : (value) {
                      if (value == null) return;

                      _updateRole(
                        context: context,
                        user: user,
                        newRole: value,
                      );
                    },
            ),
            const SizedBox(height: 8),
            Text(
              'Role saat ini: ${_getRoleLabel(user.role)}',
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Akun Aktif'),
              subtitle: Text(
                isSelf
                    ? 'Akun yang sedang digunakan tidak dapat dinonaktifkan dari halaman ini.'
                    : 'Nonaktifkan akun untuk membatasi akses pengguna.',
              ),
              value: user.isActive,
              onChanged: isSelf
                  ? null
                  : (value) {
                      _updateActiveStatus(
                        context: context,
                        user: user,
                        isActive: value,
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Hak Akses'),
      ),
      body: StreamBuilder<List<AppUserModel>>(
        stream: _userRepository.getUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Gagal memuat data pengguna: ${snapshot.error}'),
            );
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return const Center(
              child: Text('Belum ada data pengguna.'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: Colors.blue.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Halaman ini digunakan oleh pemilik toko untuk mengatur role dan status aktif pengguna.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...users.map(
                      (user) => _buildUserCard(
                        context: context,
                        user: user,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
