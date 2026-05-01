import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../data/models/app_user_model.dart';
import '../stock_in/stock_in_page.dart';
import '../stock_in/batch_list_page.dart';
import '../stock_out/stock_out_scan_page.dart';
import '../alerts/alerts_page.dart';
import '../history/transaction_history_page.dart';
import '../reports/stock_report_page.dart';
import '../analysis/stock_trend_page.dart';
import '../users/user_management_page.dart';
import '../auth/login_page.dart';

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
    if (_isOwner) {
      return 'Pemilik Toko';
    }

    return 'Karyawan';
  }

  Widget _buildMenuButton({
    required String text,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final ownerMenus = <Widget>[
      const SizedBox(height: 24),
      _buildSectionTitle('Menu Pemilik Toko'),
      _buildMenuButton(
        text: 'Monitoring & Peringatan',
        icon: Icons.warning_amber_rounded,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AlertsPage(),
            ),
          );
        },
      ),
      const SizedBox(height: 12),
      _buildMenuButton(
        text: 'Riwayat Transaksi',
        icon: Icons.receipt_long,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TransactionHistoryPage(),
            ),
          );
        },
      ),
      const SizedBox(height: 12),
      _buildMenuButton(
        text: 'Laporan Stok Tersisa',
        icon: Icons.assessment_outlined,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StockReportPage(),
            ),
          );
        },
      ),
      const SizedBox(height: 12),
      _buildMenuButton(
        text: 'Analisis Tren Stok',
        icon: Icons.trending_up,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StockTrendPage(),
            ),
          );
        },
      ),
      const SizedBox(height: 12),
      _buildMenuButton(
        text: 'Manajemen Hak Akses',
        icon: Icons.manage_accounts,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserManagementPage(
                currentUser: user,
              ),
            ),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Selamat datang, ${user.name}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Email: ${user.email}'),
                Text('Role: $_roleLabel'),
                Text(
                    'Status aktif: ${user.isActive ? 'Aktif' : 'Tidak Aktif'}'),
                const SizedBox(height: 24),
                _buildSectionTitle('Menu Operasional'),
                _buildMenuButton(
                  text: 'Masuk ke Menu Stok Masuk',
                  icon: Icons.add_box_outlined,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StockInPage(user: user),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildMenuButton(
                  text: 'Lihat Daftar Batch',
                  icon: Icons.inventory_2_outlined,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BatchListPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildMenuButton(
                  text: 'Scan Stok Keluar',
                  icon: Icons.qr_code_scanner,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StockOutScanPage(user: user),
                      ),
                    );
                  },
                ),
                if (_isOwner) ...ownerMenus,
                const SizedBox(height: 24),
                _buildMenuButton(
                  text: 'Logout',
                  icon: Icons.logout,
                  onPressed: () => _logout(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
