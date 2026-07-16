import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/app_user_model.dart';
import '../../data/models/batch_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/batch_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../stock_in/batch_detail_page.dart';
import '../stock_in/stock_in_page.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final ProductRepository _productRepository = ProductRepository();
  final BatchRepository _batchRepository = BatchRepository();
  final UserRepository _userRepository = UserRepository();

  static const int oldBatchThresholdDays = 30;
  static const int almostEmptyBatchThreshold = 3;

  bool _isOpeningPage = false;

  final BoxShadow _softShadow = BoxShadow(
    color: Colors.black.withOpacity(0.07),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  int _calculateStoredDays(DateTime receivedAt) {
    final receivedDate = DateTime(
      receivedAt.year,
      receivedAt.month,
      receivedAt.day,
    );

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    return today.difference(receivedDate).inDays;
  }

  String _getUnit(String unit) {
    final cleanUnit = unit.trim();

    return cleanUnit.isEmpty ? 'karung' : cleanUnit;
  }

  bool _isActiveBatch(BatchModel batch) {
    final status = batch.status.toLowerCase().trim();

    return status == 'active' && batch.remainingQty > 0;
  }

  int _extractBatchSequence(String batchCode) {
    final parts = batchCode.trim().split('-');

    if (parts.isEmpty) {
      return 0;
    }

    return int.tryParse(parts.last.trim()) ?? 0;
  }

  String _getBatchCodeForSort(BatchModel batch) {
    final batchCode = batch.batchCode.trim().toUpperCase();

    if (batchCode.isNotEmpty) {
      return batchCode;
    }

    return batch.id.trim().toUpperCase();
  }

  int _compareBatchesForFifo(
    BatchModel first,
    BatchModel second,
  ) {
    final receivedAtComparison = first.receivedAt.compareTo(
      second.receivedAt,
    );

    if (receivedAtComparison != 0) {
      return receivedAtComparison;
    }

    final createdAtComparison = first.createdAt.compareTo(
      second.createdAt,
    );

    if (createdAtComparison != 0) {
      return createdAtComparison;
    }

    final firstBatchCode = _getBatchCodeForSort(first);
    final secondBatchCode = _getBatchCodeForSort(second);

    final firstSequence = _extractBatchSequence(
      firstBatchCode,
    );

    final secondSequence = _extractBatchSequence(
      secondBatchCode,
    );

    if (firstSequence > 0 &&
        secondSequence > 0 &&
        firstSequence != secondSequence) {
      return firstSequence.compareTo(secondSequence);
    }

    final batchCodeComparison = firstBatchCode.compareTo(
      secondBatchCode,
    );

    if (batchCodeComparison != 0) {
      return batchCodeComparison;
    }

    return first.id.trim().toUpperCase().compareTo(
          second.id.trim().toUpperCase(),
        );
  }

  Map<String, int> _getActualStockByProductId(
    List<BatchModel> batches,
  ) {
    final stockMap = <String, int>{};

    for (final batch in batches) {
      if (!_isActiveBatch(batch)) {
        continue;
      }

      stockMap[batch.productId] =
          (stockMap[batch.productId] ?? 0) + batch.remainingQty;
    }

    return stockMap;
  }

  List<ProductModel> _getOutOfStockProducts(
    List<ProductModel> products,
    Map<String, int> actualStockByProductId,
  ) {
    final result = products.where((product) {
      final actualStock = actualStockByProductId[product.id] ?? 0;

      return actualStock <= 0;
    }).toList();

    result.sort(
      (first, second) =>
          first.name.toLowerCase().compareTo(second.name.toLowerCase()),
    );

    return result;
  }

  List<ProductModel> _getLowStockProducts(
    List<ProductModel> products,
    Map<String, int> actualStockByProductId,
  ) {
    final result = products.where((product) {
      final actualStock = actualStockByProductId[product.id] ?? 0;

      return actualStock > 0 &&
          product.minimumStock > 0 &&
          actualStock <= product.minimumStock;
    }).toList();

    result.sort(
      (first, second) =>
          first.name.toLowerCase().compareTo(second.name.toLowerCase()),
    );

    return result;
  }

  List<BatchModel> _getOldBatches(
    List<BatchModel> batches,
  ) {
    final result = batches.where((batch) {
      if (!_isActiveBatch(batch)) {
        return false;
      }

      final storedDays = _calculateStoredDays(
        batch.receivedAt.toDate(),
      );

      return storedDays >= oldBatchThresholdDays;
    }).toList();

    result.sort(_compareBatchesForFifo);

    return result;
  }

  List<BatchModel> _getAlmostEmptyBatches(
    List<BatchModel> batches,
  ) {
    final result = batches.where((batch) {
      if (!_isActiveBatch(batch)) {
        return false;
      }

      return batch.remainingQty <= almostEmptyBatchThreshold;
    }).toList();

    result.sort((first, second) {
      final qtyComparison = first.remainingQty.compareTo(
        second.remainingQty,
      );

      if (qtyComparison != 0) {
        return qtyComparison;
      }

      return _compareBatchesForFifo(first, second);
    });

    return result;
  }

  List<BatchModel> _getBackupBatches(
    List<BatchModel> batches,
  ) {
    final result = batches.where((batch) {
      if (!_isActiveBatch(batch)) {
        return false;
      }

      return _batchRepository.isBackupStorageLocation(
        batch.storageLocation,
      );
    }).toList();

    result.sort(_compareBatchesForFifo);

    return result;
  }

  void _showSnackBar({
    required String message,
    required Color color,
    required IconData icon,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<AppUserModel?> _getCurrentAppUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      _showSnackBar(
        message: 'Sesi pengguna tidak ditemukan. Silakan login kembali.',
        color: Colors.redAccent,
        icon: Icons.error_outline,
      );

      return null;
    }

    try {
      final result = await _userRepository.getUserByUid(
        firebaseUser.uid,
      );

      if (result is AppUserModel) {
        return result;
      }

      _showSnackBar(
        message: 'Data pengguna tidak ditemukan pada database.',
        color: Colors.redAccent,
        icon: Icons.error_outline,
      );

      return null;
    } catch (e) {
      final message = e.toString().replaceFirst(
            'Exception: ',
            '',
          );

      _showSnackBar(
        message: 'Gagal mengambil data pengguna: $message',
        color: Colors.redAccent,
        icon: Icons.error_outline,
      );

      return null;
    }
  }

  Future<void> _openStockIn(
    ProductModel product,
  ) async {
    if (_isOpeningPage) {
      return;
    }

    setState(() {
      _isOpeningPage = true;
    });

    try {
      final currentUser = await _getCurrentAppUser();

      if (!mounted || currentUser == null) {
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StockInPage(
            user: currentUser,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningPage = false;
        });
      }
    }
  }

  Future<void> _openBatchDetail(
    BatchModel batch,
  ) async {
    if (_isOpeningPage) {
      return;
    }

    setState(() {
      _isOpeningPage = true;
    });

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BatchDetailPage(
            batch: batch,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningPage = false;
        });
      }
    }
  }

  Widget _buildCleanCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color color = Colors.white,
    Color borderColor = const Color(0xFFE5E5E5),
  }) {
    return Container(
      width: double.infinity,
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: [_softShadow],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _buildSummaryCard({
    required int outOfStockCount,
    required int lowStockCount,
    required int oldBatchCount,
    required int almostEmptyBatchCount,
    required int locationTransferCount,
  }) {
    final totalAlerts = outOfStockCount +
        lowStockCount +
        oldBatchCount +
        almostEmptyBatchCount +
        locationTransferCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan Peringatan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _buildCleanCard(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSummaryRow(
                label: 'Total Peringatan',
                value: '$totalAlerts',
              ),
              _buildSummaryRow(
                label: 'Produk Stok Habis',
                value: '$outOfStockCount',
              ),
              _buildSummaryRow(
                label: 'Produk Stok Menipis',
                value: '$lowStockCount',
              ),
              _buildSummaryRow(
                label: 'Batch Terlalu Lama',
                value: '$oldBatchCount',
              ),
              _buildSummaryRow(
                label: 'Batch Hampir Habis',
                value: '$almostEmptyBatchCount',
              ),
              _buildSummaryRow(
                label: 'Pemindahan Lokasi',
                value: '$locationTransferCount',
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 5,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            color: Colors.black12,
            thickness: 1,
            height: 10,
          ),
      ],
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
  }) {
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
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.green.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.green.shade600,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
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
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: color.withOpacity(0.35),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 13,
            color: Colors.black45,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10.5,
                color: Colors.black54,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTapInstruction({
    String text = 'Ketuk untuk menindaklanjuti',
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 11,
            color: Colors.black45,
          ),
        ],
      ),
    );
  }

  Widget _buildProductAlertCard({
    required ProductModel product,
    required int actualStock,
    required String status,
    required Color color,
    required IconData icon,
  }) {
    final unit = _getUnit(product.unit);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isOpeningPage
              ? null
              : () {
                  _openStockIn(product);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: color.withOpacity(0.15),
                      child: Icon(
                        icon,
                        size: 17,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _buildStatusChip(
                        text: status,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        icon: Icons.inventory_2_outlined,
                        text: 'Stok aktual: $actualStock $unit',
                      ),
                      _buildInfoRow(
                        icon: Icons.low_priority_outlined,
                        text: 'Minimum stok: ${product.minimumStock} $unit',
                      ),
                      _buildTapInstruction(
                        text: 'Ketuk untuk membuka Stok Masuk',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockAlertSection({
    required List<ProductModel> outOfStockProducts,
    required List<ProductModel> lowStockProducts,
    required Map<String, int> actualStockByProductId,
  }) {
    if (outOfStockProducts.isEmpty && lowStockProducts.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.check_circle_outline,
        title: 'Stok Produk Aman',
        message:
            'Tidak ada produk yang kehabisan stok atau berada pada batas minimum.',
      );
    }

    return Column(
      children: [
        ...outOfStockProducts.map((product) {
          final actualStock = actualStockByProductId[product.id] ?? 0;

          return _buildProductAlertCard(
            product: product,
            actualStock: actualStock,
            status: 'Habis',
            color: Colors.red.shade500,
            icon: Icons.cancel_outlined,
          );
        }),
        ...lowStockProducts.map((product) {
          final actualStock = actualStockByProductId[product.id] ?? 0;

          return _buildProductAlertCard(
            product: product,
            actualStock: actualStock,
            status: 'Menipis',
            color: Colors.orange.shade600,
            icon: Icons.warning_amber_rounded,
          );
        }),
      ],
    );
  }

  Widget _buildBatchAlertCard({
    required BatchModel batch,
    required String statusText,
    required Color color,
    required IconData icon,
    required List<Widget> information,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isOpeningPage
              ? null
              : () {
                  _openBatchDetail(batch);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: color.withOpacity(0.15),
                      child: Icon(
                        icon,
                        size: 17,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              batch.productName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              batch.batchCode,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _buildStatusChip(
                        text: statusText,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...information,
                      _buildTapInstruction(
                        text: 'Ketuk untuk membuka Detail Batch',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOldBatchSection(
    List<BatchModel> oldBatches,
  ) {
    if (oldBatches.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.check_circle_outline,
        title: 'Tidak Ada Batch Terlalu Lama',
        message:
            'Tidak ada batch aktif yang tersimpan melebihi batas $oldBatchThresholdDays hari.',
      );
    }

    return Column(
      children: oldBatches.map((batch) {
        final receivedDate = batch.receivedAt.toDate();

        final storedDays = _calculateStoredDays(
          receivedDate,
        );

        final location = batch.storageLocation.trim().isEmpty
            ? '-'
            : batch.storageLocation.trim();

        final unit = _getUnit(batch.unit);

        return _buildBatchAlertCard(
          batch: batch,
          statusText: '$storedDays hari',
          color: Colors.red.shade500,
          icon: Icons.history_toggle_off,
          information: [
            _buildInfoRow(
              icon: Icons.calendar_today_outlined,
              text: 'Tanggal masuk: ${_formatDate(receivedDate)}',
            ),
            _buildInfoRow(
              icon: Icons.inventory_outlined,
              text: 'Sisa stok: ${batch.remainingQty} $unit',
            ),
            _buildInfoRow(
              icon: Icons.location_on_outlined,
              text: 'Lokasi: $location',
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildAlmostEmptyBatchSection(
    List<BatchModel> almostEmptyBatches,
  ) {
    if (almostEmptyBatches.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.check_circle_outline,
        title: 'Tidak Ada Batch Hampir Habis',
        message:
            'Tidak ada batch aktif dengan sisa stok $almostEmptyBatchThreshold karung atau kurang.',
      );
    }

    return Column(
      children: almostEmptyBatches.map((batch) {
        final location = batch.storageLocation.trim().isEmpty
            ? '-'
            : batch.storageLocation.trim();

        final unit = _getUnit(batch.unit);

        return _buildBatchAlertCard(
          batch: batch,
          statusText: '${batch.remainingQty} $unit',
          color: Colors.orange.shade600,
          icon: Icons.inventory_outlined,
          information: [
            _buildInfoRow(
              icon: Icons.inventory_2_outlined,
              text: 'Sisa stok: ${batch.remainingQty} $unit',
            ),
            _buildInfoRow(
              icon: Icons.location_on_outlined,
              text: 'Lokasi: $location',
            ),
            _buildInfoRow(
              icon: Icons.qr_code_rounded,
              text: 'Kode batch: ${batch.batchCode}',
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildLocationTransferSection({
    required List<String> availableMainLocations,
    required List<BatchModel> backupBatches,
  }) {
    final hasTransferAlert =
        availableMainLocations.isNotEmpty && backupBatches.isNotEmpty;

    if (!hasTransferAlert) {
      return _buildEmptyCard(
        icon: Icons.check_circle_outline,
        title: 'Tidak Ada Pemindahan Lokasi',
        message:
            'Tidak ada batch belakang gudang yang perlu dipindahkan ke lokasi utama.',
      );
    }

    final recommendedBatch = backupBatches.first;

    final sourceLocation = recommendedBatch.storageLocation.trim().isEmpty
        ? '-'
        : recommendedBatch.storageLocation.trim();

    final targetPreview = availableMainLocations.take(5).join(', ');

    final remainingLocationCount = availableMainLocations.length - 5;

    final targetText = remainingLocationCount > 0
        ? '$targetPreview, dan $remainingLocationCount lokasi lainnya'
        : targetPreview;

    final unit = _getUnit(recommendedBatch.unit);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.22),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isOpeningPage
              ? null
              : () {
                  _openBatchDetail(recommendedBatch);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blue.withOpacity(0.14),
                      child: Icon(
                        Icons.move_down_outlined,
                        size: 19,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lokasi Utama Tersedia',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Batch belakang gudang dapat dipindahkan.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(
                      text: '${availableMainLocations.length} kosong',
                      color: Colors.blue.shade700,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 46),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        icon: Icons.warehouse_outlined,
                        text: 'Lokasi utama kosong: $targetText',
                      ),
                      _buildInfoRow(
                        icon: Icons.inventory_2_outlined,
                        text:
                            'Batch rekomendasi: ${recommendedBatch.productName} - ${recommendedBatch.batchCode}',
                      ),
                      _buildInfoRow(
                        icon: Icons.location_on_outlined,
                        text: 'Lokasi sekarang: $sourceLocation',
                      ),
                      _buildInfoRow(
                        icon: Icons.numbers_outlined,
                        text:
                            'Sisa stok: ${recommendedBatch.remainingQty} $unit',
                      ),
                      _buildInfoRow(
                        icon: Icons.layers_outlined,
                        text:
                            'Total batch di belakang gudang: ${backupBatches.length}',
                      ),
                      _buildTapInstruction(
                        text: 'Ketuk untuk memindahkan batch',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF038E1B),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.red.shade200,
            ),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_double_arrow_left,
            color: Colors.white,
          ),
          onPressed: _isOpeningPage
              ? null
              : () {
                  Navigator.pop(context);
                },
        ),
        title: const Text(
          'MONITORING',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF015816),
                Color(0xFF038E1B),
                Color(0xFF84E977),
              ],
              stops: [0, 0.5, 1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonitoringContent({
    required List<ProductModel> products,
    required List<BatchModel> batches,
    required List<String> availableMainLocations,
  }) {
    final actualStockByProductId = _getActualStockByProductId(batches);

    final outOfStockProducts = _getOutOfStockProducts(
      products,
      actualStockByProductId,
    );

    final lowStockProducts = _getLowStockProducts(
      products,
      actualStockByProductId,
    );

    final oldBatches = _getOldBatches(batches);

    final almostEmptyBatches = _getAlmostEmptyBatches(batches);

    final backupBatches = _getBackupBatches(batches);

    final locationTransferCount =
        availableMainLocations.isNotEmpty && backupBatches.isNotEmpty ? 1 : 0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 24,
        ),
        physics: const ClampingScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 620,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.black12,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(
                    outOfStockCount: outOfStockProducts.length,
                    lowStockCount: lowStockProducts.length,
                    oldBatchCount: oldBatches.length,
                    almostEmptyBatchCount: almostEmptyBatches.length,
                    locationTransferCount: locationTransferCount,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle(
                    title: 'Peringatan Stok Produk',
                    subtitle:
                        'Ketuk produk untuk membuka halaman Stok Masuk dan melakukan penambahan stok.',
                  ),
                  _buildStockAlertSection(
                    outOfStockProducts: outOfStockProducts,
                    lowStockProducts: lowStockProducts,
                    actualStockByProductId: actualStockByProductId,
                  ),
                  const SizedBox(height: 12),
                  _buildSectionTitle(
                    title: 'Peringatan Batch Terlalu Lama',
                    subtitle:
                        'Batch aktif yang tersimpan $oldBatchThresholdDays hari atau lebih.',
                  ),
                  _buildOldBatchSection(oldBatches),
                  const SizedBox(height: 12),
                  _buildSectionTitle(
                    title: 'Peringatan Batch Hampir Habis',
                    subtitle:
                        'Batch aktif dengan sisa stok $almostEmptyBatchThreshold karung atau kurang.',
                  ),
                  _buildAlmostEmptyBatchSection(
                    almostEmptyBatches,
                  ),
                  const SizedBox(height: 12),
                  _buildSectionTitle(
                    title: 'Pemindahan Lokasi Batch',
                    subtitle:
                        'Batch aktif di X1-X5 dapat dipindahkan apabila tersedia lokasi utama yang kosong.',
                  ),
                  _buildLocationTransferSection(
                    availableMainLocations: availableMainLocations,
                    backupBatches: backupBatches,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isOpeningPage,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: _buildAppBar(context),
        body: Stack(
          children: [
            StreamBuilder<List<ProductModel>>(
              stream: _productRepository.getActiveProductsStream(),
              builder: (context, productSnapshot) {
                if (productSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                if (productSnapshot.hasError) {
                  return _buildErrorState(
                    'Gagal memuat data produk: '
                    '${productSnapshot.error}',
                  );
                }

                final products = productSnapshot.data ?? [];

                return StreamBuilder<List<BatchModel>>(
                  stream: _batchRepository.getBatchesStream(),
                  builder: (context, batchSnapshot) {
                    if (batchSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return _buildLoadingState();
                    }

                    if (batchSnapshot.hasError) {
                      return _buildErrorState(
                        'Gagal memuat data batch: '
                        '${batchSnapshot.error}',
                      );
                    }

                    final batches = batchSnapshot.data ?? [];

                    return FutureBuilder<List<String>>(
                      future:
                          _batchRepository.getAvailableMainStorageLocations(),
                      builder: (context, locationSnapshot) {
                        if (locationSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildLoadingState();
                        }

                        if (locationSnapshot.hasError) {
                          return _buildErrorState(
                            'Gagal memuat lokasi gudang: '
                            '${locationSnapshot.error}',
                          );
                        }

                        final availableMainLocations =
                            locationSnapshot.data ?? [];

                        return _buildMonitoringContent(
                          products: products,
                          batches: batches,
                          availableMainLocations: availableMainLocations,
                        );
                      },
                    );
                  },
                );
              },
            ),
            if (_isOpeningPage)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.12),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [_softShadow],
                    ),
                    child: const CircularProgressIndicator(
                      color: Color(0xFF038E1B),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
