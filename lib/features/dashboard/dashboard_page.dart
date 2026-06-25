import 'dart:ui'; // WAJIB untuk BackdropFilter & ImageFilter

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_user_model.dart';
import '../../data/models/batch_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/batch_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../alerts/alerts_page.dart';
import '../analysis/stock_trend_page.dart';
import '../auth/login_page.dart';
import '../history/transaction_history_page.dart';
import '../products/product_management_page.dart';
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
  final ProductRepository _productRepository = ProductRepository();
  final BatchRepository _batchRepository = BatchRepository();

  static const int oldBatchThresholdDays = 30;
  static const int almostEmptyBatchThreshold = 3;

  final BoxShadow _figmaShadow = BoxShadow(
    color: Colors.black.withOpacity(0.32),
    offset: const Offset(1, 2),
    blurRadius: 4,
    spreadRadius: 0,
  );

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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  int _calculateStoredDays(DateTime receivedAt) {
    return DateTime.now().difference(receivedAt).inDays;
  }

  void _showSimpleSnackBar({
    required BuildContext context,
    required String message,
    required Color color,
  }) {
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

  Map<String, int> _getActualStockByProductId(List<BatchModel> batches) {
    final Map<String, int> stockMap = {};

    for (final batch in batches) {
      final status = batch.status.toLowerCase().trim();

      if (status != 'active') continue;
      if (batch.remainingQty <= 0) continue;

      stockMap[batch.productId] =
          (stockMap[batch.productId] ?? 0) + batch.remainingQty;
    }

    return stockMap;
  }

  List<_DashboardAlert> _buildDashboardAlerts({
    required List<ProductModel> products,
    required List<BatchModel> batches,
  }) {
    final alerts = <_DashboardAlert>[];
    final actualStockByProductId = _getActualStockByProductId(batches);

    for (final product in products) {
      final actualStock = actualStockByProductId[product.id] ?? 0;
      final unit = product.unit.trim().isEmpty ? 'karung' : product.unit;

      if (actualStock <= 0) {
        alerts.add(
          _DashboardAlert(
            title: 'Stok Habis',
            message: product.name,
            detail: 'Stok saat ini 0 $unit. Segera lakukan restock.',
            icon: Icons.cancel_outlined,
            color: Colors.red.shade500,
            priority: 4,
          ),
        );
      } else if (product.minimumStock > 0 &&
          actualStock <= product.minimumStock) {
        alerts.add(
          _DashboardAlert(
            title: 'Stok Menipis',
            message: product.name,
            detail:
                'Stok saat ini $actualStock $unit, minimum stok ${product.minimumStock} $unit.',
            icon: Icons.warning_amber_rounded,
            color: Colors.orange.shade600,
            priority: 3,
          ),
        );
      }
    }

    for (final batch in batches) {
      final status = batch.status.toLowerCase().trim();
      final unit = batch.unit.trim().isEmpty ? 'karung' : batch.unit;

      if (status != 'active') continue;
      if (batch.remainingQty <= 0) continue;

      final receivedDate = batch.receivedAt.toDate();
      final storedDays = _calculateStoredDays(receivedDate);
      final location = batch.storageLocation.trim().isEmpty
          ? '-'
          : batch.storageLocation.trim();

      if (storedDays >= oldBatchThresholdDays) {
        alerts.add(
          _DashboardAlert(
            title: 'Batch Terlalu Lama',
            message: '${batch.productName} - ${batch.batchCode}',
            detail:
                'Tersimpan $storedDays hari sejak ${_formatDate(receivedDate)}. Lokasi: $location.',
            icon: Icons.history_toggle_off,
            color: Colors.red.shade500,
            priority: 3,
          ),
        );
      }

      if (batch.remainingQty <= almostEmptyBatchThreshold) {
        alerts.add(
          _DashboardAlert(
            title: 'Batch Hampir Habis',
            message: '${batch.productName} - ${batch.batchCode}',
            detail:
                'Sisa batch ${batch.remainingQty} $unit. Lokasi: $location.',
            icon: Icons.inventory_outlined,
            color: Colors.orange.shade600,
            priority: 2,
          ),
        );
      }
    }

    alerts.sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;
      return a.title.compareTo(b.title);
    });

    return alerts;
  }

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage('assets/stockout/bgpop.png'),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Konfirmasi Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Apakah Anda yakin ingin keluar dari aplikasi?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 98,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Batal',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 32),
                        Container(
                          width: 98,
                          height: 35,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/stockout/botpop.png'),
                              fit: BoxFit.fill,
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding:
                                  const EdgeInsets.only(bottom: 6, right: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.exit_to_app,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Logout',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    height: 1.1,
                                  ),
                                ),
                              ],
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

  Widget _buildIconWithGlassBg(
    String iconPath,
    double iconSize,
    IconData fallback,
  ) {
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
              color: Colors.white.withOpacity(0.65),
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

  Widget _buildNotificationBell(BuildContext context) {
    return StreamBuilder<List<ProductModel>>(
      stream: _productRepository.getActiveProductsStream(),
      builder: (context, productSnapshot) {
        return StreamBuilder<List<BatchModel>>(
          stream: _batchRepository.getBatchesStream(),
          builder: (context, batchSnapshot) {
            final hasError = productSnapshot.hasError || batchSnapshot.hasError;

            final products = productSnapshot.data ?? [];
            final batches = batchSnapshot.data ?? [];

            final alerts = _buildDashboardAlerts(
              products: products,
              batches: batches,
            );

            final alertCount = alerts.length;
            final badgeText = alertCount > 99 ? '99+' : '$alertCount';

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (hasError) {
                    _showSimpleSnackBar(
                      context: context,
                      message: 'Gagal memuat data peringatan.',
                      color: Colors.red,
                    );
                    return;
                  }

                  _showAlertsBottomSheet(
                    context: context,
                    alerts: alerts,
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        offset: const Offset(1, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                      if (alertCount > 0)
                        Positioned(
                          top: 4,
                          right: 3,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAlertsBottomSheet({
    required BuildContext context,
    required List<_DashboardAlert> alerts,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(bottomSheetContext).size.height * 0.78,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF015816),
                              Color(0xFF038E1B),
                              Color(0xFF84E977),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Peringatan Stok',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              alerts.isEmpty
                                  ? 'Tidak ada peringatan saat ini.'
                                  : '${alerts.length} peringatan perlu diperhatikan.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: alerts.isEmpty
                      ? _buildEmptyAlertContent()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: alerts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildAlertItem(alerts[index]);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyAlertContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 52,
              color: Colors.green.shade600,
            ),
            const SizedBox(height: 14),
            const Text(
              'Semua Aman',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Belum ada stok menipis, stok habis, batch terlalu lama, atau batch hampir habis.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(_DashboardAlert alert) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: alert.color.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: alert.color.withOpacity(0.14),
            child: Icon(
              alert.icon,
              color: alert.color,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(
                    color: alert.color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  alert.message,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.detail,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
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
                              Positioned(
                                top: 18,
                                right: 0,
                                child: _buildNotificationBell(context),
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
                              _buildIconWithGlassBg(
                                'assets/images/qr.svg',
                                23.5,
                                Icons.qr_code_scanner,
                              ),
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
                      onTap: () => _openPage(context, const BatchListPage()),
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
                      _buildSvgMenuItem(
                        title: 'Kelola\nProduk',
                        svgPath: 'assets/images/batch.svg',
                        fallbackIcon: Icons.inventory_2_outlined,
                        iconSize: 23.0,
                        onTap: () => _openPage(
                          context,
                          const ProductManagementPage(),
                        ),
                      ),
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

class _DashboardAlert {
  final String title;
  final String message;
  final String detail;
  final IconData icon;
  final Color color;
  final int priority;

  _DashboardAlert({
    required this.title,
    required this.message,
    required this.detail,
    required this.icon,
    required this.color,
    required this.priority,
  });
}
