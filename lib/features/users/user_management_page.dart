import 'package:flutter/material.dart';

import '../../data/models/app_user_model.dart';
import '../../data/repositories/user_repository.dart';

class UserManagementPage extends StatefulWidget {
  final AppUserModel currentUser;

  const UserManagementPage({
    super.key,
    required this.currentUser,
  });

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final UserRepository _userRepository = UserRepository();

  bool _isCurrentUser(AppUserModel user) {
    return user.uid == widget.currentUser.uid;
  }

  bool _isOwnerRole(String role) {
    final normalizedRole = role.toLowerCase().trim();
    return normalizedRole == 'owner' || normalizedRole == 'pemilik';
  }

  void _showSnackBar({
    required String message,
    required Color color,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      ),
    );
  }

  Future<void> _updateRole({
    required AppUserModel user,
    required String newRole,
  }) async {
    try {
      await _userRepository.updateUserRole(
        uid: user.uid,
        role: newRole,
      );

      _showSnackBar(
        message: 'Role pengguna berhasil diperbarui.',
        color: Colors.green,
      );
    } catch (e) {
      _showSnackBar(
        message: 'Gagal memperbarui role: $e',
        color: Colors.red,
      );
    }
  }

  Future<void> _updateActiveStatus({
    required AppUserModel user,
    required bool isActive,
  }) async {
    try {
      await _userRepository.updateUserActiveStatus(
        uid: user.uid,
        isActive: isActive,
      );

      _showSnackBar(
        message: isActive
            ? 'Pengguna berhasil diaktifkan.'
            : 'Pengguna berhasil dinonaktifkan.',
        color: Colors.green,
      );
    } catch (e) {
      _showSnackBar(
        message: 'Gagal memperbarui status pengguna: $e',
        color: Colors.red,
      );
    }
  }

  Future<bool> _confirmAndDeleteUser(AppUserModel user) async {
    if (_isCurrentUser(user)) {
      _showSnackBar(
        message: 'Akun yang sedang digunakan tidak dapat dihapus.',
        color: Colors.red,
      );
      return false;
    }

    final displayName = user.name.trim().isEmpty ? user.email : user.name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Hapus Pengguna?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Pengguna "$displayName" akan dihapus dari manajemen hak akses.\n\n'
            'Data pengguna akan dihapus dari Firestore collection users. '
            'Akun Firebase Authentication masih ada, tetapi user tidak bisa masuk aplikasi karena profilnya tidak ditemukan.',
            style: const TextStyle(
              height: 1.4,
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return false;
    }

    try {
      await _userRepository.deleteUserAccess(uid: user.uid);

      _showSnackBar(
        message: 'Pengguna berhasil dihapus dari hak akses.',
        color: Colors.green,
      );

      return false;
    } catch (e) {
      _showSnackBar(
        message: 'Gagal menghapus pengguna: $e',
        color: Colors.red,
      );

      return false;
    }
  }

  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    String selectedRole = 'karyawan';
    bool isActive = true;
    bool isSubmitting = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0F6022),
                      Color(0xFF38B24C),
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.person_add_alt_1, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tambah Pengguna',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Nama Pengguna',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama wajib diisi';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';

                          if (email.isEmpty) {
                            return 'Email wajib diisi';
                          }

                          if (!email.contains('@') || !email.contains('.')) {
                            return 'Format email tidak valid';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Password Awal',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          final password = value?.trim() ?? '';

                          if (password.isEmpty) {
                            return 'Password wajib diisi';
                          }

                          if (password.length < 6) {
                            return 'Password minimal 6 karakter';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          prefixIcon: const Icon(Icons.admin_panel_settings),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                        onChanged: isSubmitting
                            ? null
                            : (value) {
                                if (value == null) return;

                                setDialogState(() {
                                  selectedRole = value;
                                });
                              },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isActive,
                        activeColor: const Color(0xFF1AD426),
                        title: const Text(
                          'Status Akun Aktif',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          isActive
                              ? 'User dapat login ke aplikasi.'
                              : 'User dibuat tetapi belum bisa login.',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onChanged: isSubmitting
                            ? null
                            : (value) {
                                setDialogState(() {
                                  isActive = value;
                                });
                              },
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Akun akan dibuat di Firebase Authentication dan profilnya disimpan ke Firestore collection users.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Batal'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F6022),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() {
                            isSubmitting = true;
                          });

                          try {
                            await _userRepository.createUserWithRole(
                              name: nameController.text.trim(),
                              email: emailController.text.trim(),
                              password: passwordController.text.trim(),
                              role: selectedRole,
                              isActive: isActive,
                            );

                            if (!dialogContext.mounted) return;

                            Navigator.of(dialogContext).pop();

                            _showSnackBar(
                              message: 'Pengguna baru berhasil ditambahkan.',
                              color: Colors.green,
                            );
                          } catch (e) {
                            if (!dialogContext.mounted) return;

                            setDialogState(() {
                              isSubmitting = false;
                            });

                            _showSnackBar(
                              message: '$e',
                              color: Colors.red,
                            );
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(isSubmitting ? 'Menyimpan...' : 'Simpan'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      emailController.dispose();
      passwordController.dispose();
    });
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
            Color(0xFFE8F5E9),
            Color(0xFFC8E6C9),
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
              label: 'Karyawan',
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
              'Catatan: akun yang sedang digunakan tidak dapat dinonaktifkan atau dihapus. Geser kartu pengguna ke kiri untuk menghapus hak akses.',
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

  Widget _buildDismissBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Hapus',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          Icon(
            Icons.delete_outline,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard({
    required AppUserModel user,
  }) {
    final isSelf = _isCurrentUser(user);
    final selectedRole = _isOwnerRole(user.role) ? 'owner' : 'karyawan';

    final card = Container(
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            user.isActive
                                ? Icons.check_circle_outline
                                : Icons.block,
                            size: 14,
                            color: user.isActive
                                ? const Color(0xFF1B802E)
                                : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user.isActive ? 'Aktif' : 'Tidak Aktif',
                            style: TextStyle(
                              color: user.isActive
                                  ? const Color(0xFF1B802E)
                                  : Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
                        user: user,
                        newRole: value,
                      );
                    },
            ),
            const SizedBox(height: 8),
            Text(
              isSelf
                  ? 'Akun sedang digunakan tidak dapat dinonaktifkan, diubah role-nya, atau dihapus.'
                  : 'Role dapat diubah melalui dropdown. Geser kartu ke kiri untuk menghapus hak akses pengguna.',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF6B8E70),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );

    if (isSelf) {
      return card;
    }

    return Dismissible(
      key: ValueKey('user-${user.uid}'),
      direction: DismissDirection.endToStart,
      background: _buildDismissBackground(),
      confirmDismiss: (_) => _confirmAndDeleteUser(user),
      child: card,
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Belum ada data pengguna. Tekan tombol tambah di kanan bawah untuk menambahkan pengguna baru.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black54,
            fontSize: 14,
            height: 1.4,
          ),
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
      backgroundColor: const Color(0xFFF5F5F5),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F6022),
        foregroundColor: Colors.white,
        onPressed: _showAddUserDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text(
          'Tambah',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_double_arrow_left,
            color: Colors.white,
            size: 28,
          ),
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
                Color(0xFF0F6022),
                Color(0xFF38B24C),
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
                          (user) => _buildUserCard(user: user),
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
