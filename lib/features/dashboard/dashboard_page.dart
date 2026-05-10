import 'dart:ui'; // WAJIB untuk BackdropFilter & ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
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

  final BoxShadow _figmaShadow = BoxShadow(
    color: Colors.black.withOpacity(0.32),
    offset: const Offset(1, 2),
    blurRadius: 4,
    spreadRadius: 0,
  );

  // --- SHADOW IKON TETAP LEMBUT ---
  final BoxShadow _iconGlassShadow = BoxShadow(
    color: Colors.black.withOpacity(0.12),
    offset: const Offset(1, 2),
    blurRadius: 3,
    spreadRadius: 0,
  );

  bool get _isOwner {
    final role = user.role.toLowerCase().trim();
    return role == 'owner' || role == 'pemilik';
  }

  String get _roleLabel {
    return _isOwner ? 'Pemilik Toko' : 'Karyawan';
  }

  // --- REVISI TOTAL: DIALOG LOGOUT GLASSY & GRADASI ---
  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.4), // Overlay gelap di belakang
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              // Efek potong agar blur tidak keluar dari sudut melengkung
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                      sigmaX: 16, sigmaY: 16), // Efek Frosted Glass
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                    decoration: BoxDecoration(
                      // Latar belakang semitransparan (putih dengan sentuhan hijau super tipis)
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.85),
                          const Color(0xFF84E977).withOpacity(0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      // Border putih tipis bercahaya khas efek kaca
                      border: Border.all(
                        color: Colors.white.withOpacity(0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Konfirmasi Logout',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Apakah Anda yakin ingin keluar dari aplikasi?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Baris Tombol
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Tombol Batal (Lembut, warna hijau gelap)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(
                                'Batal',
                                style: TextStyle(
                                  color: Color(0xFF015816), // Hijau utama
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Tombol Logout (Pekat dengan Gradasi Utama)
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF015816),
                                    Color(0xFF038E1B),
                                    Color(0xFF84E977),
                                  ],
                                  stops: [0.0, 0.5, 1.0],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF038E1B)
                                        .withOpacity(0.3),
                                    offset: const Offset(0, 4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Logout',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        // Animasi muncul skala membesar lembut (scale up)
        return Transform.scale(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutCubic,
          ).value,
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );

    if (shouldLogout != true) return;

    try {
      await _authService.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal logout: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  // --- PONDASI IKON RAPI FAVORIT ANDA (Opasitas Putih 65%) ---
  Widget _buildIconWithGlassBg(
      String iconPath, double iconSize, IconData fallback) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  Colors.white.withOpacity(0.65), // Tetap di 65% sesuai kuncian
              borderRadius: BorderRadius.circular(10),
              boxShadow: [_iconGlassShadow],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SvgPicture.asset(
              'assets/images/glass_bg.svg',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: SvgPicture.asset(
              iconPath,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              colorFilter: const ColorFilter.mode(
                AppTheme.primaryGreen,
                BlendMode.srcIn,
              ),
              placeholderBuilder: (context) => Icon(
                fallback,
                color: AppTheme.primaryGreen,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSvgMenuItem({
    required String title,
    required String svgPath,
    required IconData fallbackIcon,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconWithGlassBg(svgPath, iconSize, fallbackIcon),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuContainer({
    required String title,
    required String subtitle,
    required List<Widget> menuRows,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [_figmaShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10.5,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          ...menuRows,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Header Hijau
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 2,
                    left: 20,
                    right: 20,
                    bottom: 26,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF015816),
                        Color(0xFF038E1B),
                        Color(0xFF84E977),
                      ],
                      stops: [0.0, 0.5, 1.0],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    boxShadow: [_figmaShadow],
                  ),
                  child: Transform.translate(
                    offset: const Offset(0, -18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 70,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                top: -15,
                                left: -12,
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: 115,
                                  width: 240,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.centerLeft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Aplikasi Manajemen Stok | Toko Beras',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 1,
                                width: 275,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor:
                                        Colors.white.withOpacity(0.18),
                                    child: SvgPicture.asset(
                                      'assets/images/profile.svg',
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.contain,
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _roleLabel,
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.9),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Card Informasi Akun
                Positioned(
                  bottom: -27,
                  left: 26,
                  right: 26,
                  child: Container(
                    height: 59,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [_figmaShadow],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/images/shield.svg',
                          width: 30,
                          height: 30,
                          fit: BoxFit.contain,
                          colorFilter: const ColorFilter.mode(
                            AppTheme.primaryGreen,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Informasi Akun',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.email,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 11,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGreenBg,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [_figmaShadow],
                          ),
                          child: Text(
                            user.isActive ? 'Aktif' : 'Nonaktif',
                            style: const TextStyle(
                              color: AppTheme.primaryGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 33),
            // MENU OPERASIONAL
            _buildMenuContainer(
              title: 'Menu Operasional',
              subtitle: 'Fitur utama untuk pencatatan stok harian',
              menuRows: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSvgMenuItem(
                      title: 'Stok Masuk',
                      svgPath: 'assets/images/addstock.svg',
                      fallbackIcon: Icons.playlist_add,
                      iconSize: 23.0,
                      onTap: () => _openPage(context, StockInPage(user: user)),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            _openPage(context, StockOutScanPage(user: user)),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildIconWithGlassBg('assets/images/qr.svg',
                                  23.5, Icons.qr_code_scanner),
                              const SizedBox(height: 6),
                              const Text(
                                'Scan Stok\nKeluar',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildSvgMenuItem(
                      title: 'Daftar Batch',
                      svgPath: 'assets/images/batch.svg',
                      fallbackIcon: Icons.inventory_2_outlined,
                      iconSize: 19.5,
                      onTap: () => _openPage(context, BatchListPage()),
                    ),
                  ],
                ),
              ],
            ),
            if (_isOwner)
              _buildMenuContainer(
                title: 'Menu Pemilik Toko',
                subtitle: 'Fitur monitoring, laporan, analisis, dan pengaturan',
                menuRows: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSvgMenuItem(
                        title: 'Monitoring',
                        svgPath: 'assets/images/monitoring.svg',
                        fallbackIcon: Icons.grid_view,
                        iconSize: 22.5,
                        onTap: () => _openPage(context, AlertsPage()),
                      ),
                      _buildSvgMenuItem(
                        title: 'Riwayat\nTransaksi',
                        svgPath: 'assets/images/transaction.svg',
                        fallbackIcon: Icons.receipt_long_outlined,
                        iconSize: 25.0,
                        onTap: () => _openPage(
                          context,
                          const TransactionHistoryPage(),
                        ),
                      ),
                      _buildSvgMenuItem(
                        title: 'Laporan Stok',
                        svgPath: 'assets/images/report.svg',
                        fallbackIcon: Icons.assessment_outlined,
                        iconSize: 25.0,
                        onTap: () => _openPage(context, StockReportPage()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSvgMenuItem(
                        title: 'Analisis Tren',
                        svgPath: 'assets/images/analysis.svg',
                        fallbackIcon: Icons.trending_up,
                        iconSize: 25.0,
                        onTap: () => _openPage(context, const StockTrendPage()),
                      ),
                      _buildSvgMenuItem(
                        title: 'Hak Akses',
                        svgPath: 'assets/images/acces.svg',
                        fallbackIcon: Icons.manage_accounts_outlined,
                        iconSize: 26.0,
                        onTap: () => _openPage(
                          context,
                          UserManagementPage(currentUser: user),
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF015816),
                        Color(0xFF038E1B),
                        Color(0xFF84E977),
                      ],
                      stops: [0.0, 0.5, 1.0],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [_figmaShadow],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _logout(context),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.logout,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Logout',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
