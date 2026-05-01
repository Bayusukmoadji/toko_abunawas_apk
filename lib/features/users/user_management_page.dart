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

  String _getRoleLabel(String role) {
    if (_isOwnerRole(role)) {
      return 'Pemilik Toko';
    }

    return 'Karyawan';
  }

  Color _getRoleColor(String role) {
    if (_isOwnerRole(role)) {
      return Colors.deepPurple;
    }

    return Colors.blue;
  }

  Color _getStatusColor(bool isActive) {
    return isActive ? Colors.green : Colors.red;
  }

  String _getStatusLabel(bool isActive) {
    return isActive ? 'Aktif' : 'Tidak Aktif';
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

  Widget _buildHeaderCard() {
    return const Card(
      color: Color(0xFF2E7D32),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(
                Icons.manage_accounts,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manajemen Hak Akses',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Kelola role pengguna dan status aktif akun untuk membatasi akses fitur aplikasi.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(List<AppUserModel> users) {
    final ownerCount = _countOwner(users);
    final karyawanCount = _countKaryawan(users);
    final activeCount = _countActiveUsers(users);
    final inactiveCount = _countInactiveUsers(users);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Pengguna',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              icon: Icons.people_outline,
              label: 'Total Pengguna',
              value: '${users.length}',
              color: Colors.blue,
            ),
            _buildSummaryRow(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Pemilik Toko',
              value: '$ownerCount',
              color: Colors.deepPurple,
            ),
            _buildSummaryRow(
              icon: Icons.badge_outlined,
              label: 'Karyawan',
              value: '$karyawanCount',
              color: Colors.teal,
            ),
            _buildSummaryRow(
              icon: Icons.check_circle_outline,
              label: 'Akun Aktif',
              value: '$activeCount',
              color: Colors.green,
            ),
            _buildSummaryRow(
              icon: Icons.cancel_outlined,
              label: 'Akun Tidak Aktif',
              value: '$inactiveCount',
              color: Colors.red,
            ),
            const SizedBox(height: 8),
            const Text(
              'Catatan: akun yang sedang digunakan tidak dapat dinonaktifkan dari halaman ini.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12.5,
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
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.35),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUserCard({
    required BuildContext context,
    required AppUserModel user,
  }) {
    final isSelf = _isCurrentUser(user);
    final selectedRole = _isOwnerRole(user.role) ? 'owner' : 'karyawan';
    final roleColor = _getRoleColor(user.role);
    final statusColor = _getStatusColor(user.isActive);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: roleColor.withOpacity(0.12),
                  child: Icon(
                    _isOwnerRole(user.role)
                        ? Icons.admin_panel_settings_outlined
                        : Icons.person_outline,
                    color: roleColor,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isEmpty ? '(Nama belum diisi)' : user.name,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChip(
                            text: _getRoleLabel(user.role),
                            color: roleColor,
                          ),
                          _buildChip(
                            text: _getStatusLabel(user.isActive),
                            color: statusColor,
                          ),
                          if (isSelf)
                            _buildChip(
                              text: 'Akun Saat Ini',
                              color: Colors.orange,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: selectedRole,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Role Pengguna',
                prefixIcon: Icon(Icons.security_outlined),
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Status Akun Aktif',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  isSelf
                      ? 'Akun yang sedang digunakan tidak dapat dinonaktifkan dari halaman ini.'
                      : 'Nonaktifkan akun untuk membatasi akses pengguna ke aplikasi.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                value: user.isActive,
                activeColor: Colors.green,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daftar Pengguna',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Owner dapat mengubah role dan status aktif pengguna lain.',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.people_outline,
                  color: Colors.grey,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Belum ada data pengguna.',
                    style: TextStyle(
                      color: Colors.black87,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Gagal memuat data pengguna: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 12),
                      _buildSummaryCard(users),
                      const SizedBox(height: 20),
                      _buildSectionTitle(),
                      const SizedBox(height: 12),
                      ...users.map(
                        (user) => _buildUserCard(
                          context: context,
                          user: user,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
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
