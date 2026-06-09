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

  bool _isOwnerRole(String role) {
    final normalizedRole = role.toLowerCase().trim();
    return normalizedRole == 'owner' || normalizedRole == 'pemilik';
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

  int _countOwner(List<AppUserModel> users) {
    return users.where((user) => _isOwnerRole(user.role)).length;
  }

  int _countKaryawan(List<AppUserModel> users) {
    return users.where((user) => !_isOwnerRole(user.role)).length;
  }

  int _countActiveUsers(List<AppUserModel> users) {
    return users.where((user) => user.isActive).length;
  }

  int _countInactiveUsers(List<AppUserModel> users) {
    return users.where((user) => !user.isActive).length;
  }

  Widget _buildSummaryCard(List<AppUserModel> users) {
    final ownerCount = _countOwner(users);
    final karyawanCount = _countKaryawan(users);
    final activeCount = _countActiveUsers(users);
    final inactiveCount = _countInactiveUsers(users);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F5E9), // Hijau sangat pudar
            Color(0xFFC8E6C9), // Hijau sedikit lebih pekat
          ],
        ),
        border: Border.all(color: const Color(0xFFB9DFBD), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow(
              icon: Icons.people_outline,
              label: 'Total Pengguna',
              value: '${users.length}',
            ),
            _buildSummaryRow(
              icon: Icons.person_outline,
              label: 'Pemilik Toko',
              value: '$ownerCount',
            ),
            _buildSummaryRow(
              icon: Icons.person_outline,
              label: 'karyawan',
              value: '$karyawanCount',
            ),
            _buildSummaryRow(
              icon: Icons.check_circle_outline,
              label: 'Akun Aktif',
              value: '$activeCount',
            ),
            _buildSummaryRow(
              icon: Icons.block,
              label: 'Akun Tidak Aktif',
              value: '$inactiveCount',
            ),
            const SizedBox(height: 8),
            const Text(
              'Catatan: akun yang sedang digunakan tidak dapat dinonaktifkan dari halaman ini.',
              style: TextStyle(
                color: Color(0xFF6B8E70),
                fontSize: 10,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: const Color(0xFF1B802E),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard({
    required BuildContext context,
    required AppUserModel user,
  }) {
    final isSelf = _isCurrentUser(user);
    final selectedRole = _isOwnerRole(user.role) ? 'owner' : 'karyawan';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F5E9),
            Color(0xFFC8E6C9),
          ],
        ),
        border: Border.all(color: const Color(0xFFB9DFBD), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  radius: 20,
                  child: const Icon(
                    Icons.person_outline,
                    color: Colors.blue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isEmpty ? '(Nama belum diisi)' : user.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: user.isActive,
                  activeColor: Colors.white,
                  activeTrackColor: const Color(0xFF1AD426),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade400,
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
            const SizedBox(height: 12),
            const Text(
              'Role',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            DropdownButton<String>(
              value: selectedRole,
              isExpanded: true,
              isDense: true,
              underline: Container(
                height: 1,
                color: Colors.grey.shade500,
              ),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'karyawan',
                  child: Text('Karyawan'),
                ),
                DropdownMenuItem(
                  value: 'owner',
                  child: Text('Pemilik Toko'),
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
              isSelf
                  ? 'Akun sedang digunakan tidak dapat dinonaktifkan.'
                  : 'Nonaktifkan akun untuk membatasi akses pengguna ke aplikasi.',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF6B8E70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Belum ada data pengguna.',
          style: TextStyle(color: Colors.black54, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Gagal memuat data pengguna: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // BACKGROUND DIUBAH MENJADI PUTIH F5F5F5
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_double_arrow_left,
              color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'MANAJEMEN HAK AKSES',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF0F6022), // Hijau tua kiri
                Color(0xFF38B24C), // Hijau terang kanan
              ],
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<AppUserModel>>(
        stream: _userRepository.getUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return _buildEmptyState();
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Ringkasan Pengguna',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryCard(users),
                        const SizedBox(height: 24),
                        const Text(
                          'Daftar Pengguna',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),
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
              ),
            ),
          );
        },
      ),
    );
  }
}
