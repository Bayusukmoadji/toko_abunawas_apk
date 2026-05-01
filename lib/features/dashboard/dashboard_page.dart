import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../data/models/app_user_model.dart';
import '../alerts/alerts_page.dart';
import '../analysis/stock_trend_page.dart';
import '../auth/login_page.dart';
import '../history/transaction_history_page.dart';
import '../reports/stock_report_page.dart';
import '../stock_in/batch_list_page.dart';
import '../stock_in/stock_in_page.dart';
import '../stock_out/stock_out_scan_page.dart';
import '../users/user_management_page.dart';

class DashboardPage extends StatelessWidget {
  final AppUserModel user;

  DashboardPage({
    super.key,
    required this.user,
  });

  final AuthService _authService = AuthService();

  bool get _isOwner {
    final role = user.role.toLowerCase().trim();
    return role == 'owner' || role == 'pemilik';
  }

  String get _roleLabel {
    return _isOwner ? 'Pemilik Toko' : 'Karyawan';
  }

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    try {
      await _authService.signOut();

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal logout: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => page,
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2E7D32),
            Color(0xFF43A047),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aplikasi Manajemen Stok',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Toko Beras Abunawas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withOpacity(0.18),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _roleLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  user.isActive ? 'Aktif' : 'Tidak Aktif',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.verified_user_outlined,
              color: Color(0xFF2E7D32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informasi Akun',
                    style: TextStyle(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 1.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGrid({
    required BuildContext context,
    required List<Widget> children,
  }) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.92,
      children: children,
    );
  }

  List<Widget> _buildOperationalMenus(BuildContext context) {
    return [
      _buildMenuCard(
        context: context,
        title: 'Stok Masuk',
        subtitle: 'Input stok baru dan buat batch.',
        icon: Icons.add_box_outlined,
        color: const Color(0xFF2E7D32),
        onTap: () => _openPage(
          context,
          StockInPage(user: user),
        ),
      ),
      _buildMenuCard(
        context: context,
        title: 'Daftar Batch',
        subtitle: 'Lihat batch, lokasi, dan QR Code.',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF1565C0),
        onTap: () => _openPage(
          context,
          BatchListPage(),
        ),
      ),
      _buildMenuCard(
        context: context,
        title: 'Scan Stok Keluar',
        subtitle: 'Scan QR dan validasi FIFO.',
        icon: Icons.qr_code_scanner,
        color: const Color(0xFF6A1B9A),
        onTap: () => _openPage(
          context,
          StockOutScanPage(user: user),
        ),
      ),
      _buildMenuCard(
        context: context,
        title: 'Logout',
        subtitle: 'Keluar dari akun aplikasi.',
        icon: Icons.logout,
        color: const Color(0xFFD32F2F),
        onTap: () => _logout(context),
      ),
    ];
  }

  List<Widget> _buildOwnerMenus(BuildContext context) {
    return [
      _buildMenuCard(
        context: context,
        title: 'Monitoring',
        subtitle: 'Pantau stok menipis dan batch lama.',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFFF8F00),
        onTap: () => _openPage(
          context,
          AlertsPage(),
        ),
      ),
      _buildMenuCard(
        context: context,
        title: 'Riwayat Transaksi',
        subtitle: 'Lihat stok masuk dan keluar.',
        icon: Icons.receipt_long,
        color: const Color(0xFF00897B),
        onTap: () => _openPage(
          context,
          const TransactionHistoryPage(),
        ),
      ),
      _buildMenuCard(
        context: context,
        title: 'Laporan Stok',
        subtitle: 'Cek stok tersisa dan PDF.',
        icon: Icons.assessment_outlined,
        color: const Color(0xFF3949AB),
        onTap: () => _openPage(
          context,
          StockReportPage(),
        ),
      ),
      _buildMenuCard(
        context: context,
        title: 'Analisis Tren',
        subtitle: 'Analisis stok keluar per produk.',
        icon: Icons.trending_up,
        color: const Color(0xFF5D4037),
        onTap: () => _openPage(
          context,
          const StockTrendPage(),
        ),
      ),
      _buildMenuCard(
        context: context,
        title: 'Hak Akses',
        subtitle: 'Kelola role dan status user.',
        icon: Icons.manage_accounts,
        color: const Color(0xFF455A64),
        onTap: () => _openPage(
          context,
          UserManagementPage(currentUser: user),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final operationalMenus = _buildOperationalMenus(context);
    final ownerMenus = _buildOwnerMenus(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 14),
                  _buildUserInfoCard(),
                  const SizedBox(height: 16),
                  _buildSectionTitle(
                    'Menu Operasional',
                    'Fitur utama untuk pencatatan stok harian.',
                  ),
                  _buildMenuGrid(
                    context: context,
                    children: operationalMenus,
                  ),
                  if (_isOwner) ...[
                    const SizedBox(height: 22),
                    _buildSectionTitle(
                      'Menu Pemilik Toko',
                      'Fitur monitoring, laporan, analisis, dan pengaturan.',
                    ),
                    _buildMenuGrid(
                      context: context,
                      children: ownerMenus,
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
