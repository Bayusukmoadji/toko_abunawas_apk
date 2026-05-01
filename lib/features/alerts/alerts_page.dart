import 'package:flutter/material.dart';

import '../../data/models/batch_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/batch_repository.dart';
import '../../data/repositories/product_repository.dart';

class AlertsPage extends StatelessWidget {
  AlertsPage({super.key});

  final ProductRepository _productRepository = ProductRepository();
  final BatchRepository _batchRepository = BatchRepository();

  static const int oldBatchThresholdDays = 30;

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  int _calculateStoredDays(DateTime receivedAt) {
    final now = DateTime.now();
    return now.difference(receivedAt).inDays;
  }

  List<ProductModel> _getLowStockProducts(List<ProductModel> products) {
    return products.where((product) {
      return product.totalStock <= product.minimumStock;
    }).toList();
  }

  List<BatchModel> _getOldBatches(List<BatchModel> batches) {
    return batches.where((batch) {
      final status = batch.status.toLowerCase().trim();

      if (status != 'active') return false;
      if (batch.remainingQty <= 0) return false;

      final storedDays = _calculateStoredDays(batch.receivedAt.toDate());
      return storedDays >= oldBatchThresholdDays;
    }).toList();
  }

  String _getStockStatus(ProductModel product) {
    if (product.totalStock <= 0) {
      return 'Habis';
    }

    if (product.totalStock <= product.minimumStock) {
      return 'Menipis';
    }

    return 'Aman';
  }

  Color _getStockStatusColor(ProductModel product) {
    final status = _getStockStatus(product);

    if (status == 'Habis') {
      return Colors.red;
    }

    if (status == 'Menipis') {
      return Colors.orange;
    }

    return Colors.green;
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
                Icons.warning_amber_rounded,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monitoring & Peringatan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Pantau stok menipis dan batch yang terlalu lama tersimpan di gudang.',
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

  Widget _buildSummaryCard({
    required int lowStockCount,
    required int oldBatchCount,
  }) {
    final totalAlerts = lowStockCount + oldBatchCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Peringatan',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              icon: Icons.notifications_active_outlined,
              label: 'Total Peringatan',
              value: '$totalAlerts',
              color: totalAlerts > 0 ? Colors.red : Colors.green,
            ),
            _buildSummaryRow(
              icon: Icons.inventory_2_outlined,
              label: 'Produk Stok Menipis',
              value: '$lowStockCount',
              color: Colors.orange,
            ),
            _buildSummaryRow(
              icon: Icons.history_toggle_off,
              label: 'Batch Terlalu Lama',
              value: '$oldBatchCount',
              color: Colors.red,
            ),
            const SizedBox(height: 8),
            const Text(
              'Catatan: batch dianggap terlalu lama apabila tersimpan 30 hari atau lebih dan masih berstatus aktif.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.black54,
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
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: Colors.green,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.35,
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

  Widget _buildLowStockSection(List<ProductModel> lowStockProducts) {
    if (lowStockProducts.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.check_circle_outline,
        title: 'Stok Produk Aman',
        message: 'Tidak ada produk yang berada pada batas minimum stok.',
      );
    }

    return Column(
      children: lowStockProducts.map((product) {
        final status = _getStockStatus(product);
        final color = _getStockStatusColor(product);

        return Card(
          color: color.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.14),
                  child: Icon(
                    status == 'Habis'
                        ? Icons.cancel_outlined
                        : Icons.warning_amber_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildStatusChip(
                        text: status,
                        color: color,
                      ),
                      const SizedBox(height: 9),
                      _buildInfoText(
                        icon: Icons.inventory_2_outlined,
                        text:
                            'Stok saat ini: ${product.totalStock} ${product.unit}',
                      ),
                      _buildInfoText(
                        icon: Icons.low_priority_outlined,
                        text:
                            'Minimum stok: ${product.minimumStock} ${product.unit}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOldBatchSection(List<BatchModel> oldBatches) {
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
        final storedDays = _calculateStoredDays(receivedDate);
        final location = batch.storageLocation.trim().isEmpty
            ? '-'
            : batch.storageLocation.trim();

        return Card(
          color: Colors.red.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red.withOpacity(0.14),
                  child: const Icon(
                    Icons.history_toggle_off,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batch.productName,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        batch.batchCode,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusChip(
                        text: '$storedDays hari tersimpan',
                        color: Colors.red,
                      ),
                      const SizedBox(height: 9),
                      _buildInfoText(
                        icon: Icons.calendar_month_outlined,
                        text: 'Tanggal masuk: ${_formatDate(receivedDate)}',
                      ),
                      _buildInfoText(
                        icon: Icons.inventory_2_outlined,
                        text: 'Sisa stok: ${batch.remainingQty} ${batch.unit}',
                      ),
                      _buildInfoText(
                        icon: Icons.location_on_outlined,
                        text: 'Lokasi: $location',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusChip({
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

  Widget _buildInfoText({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color: Colors.black45,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              message,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring & Peringatan'),
      ),
      body: StreamBuilder<List<ProductModel>>(
        stream: _productRepository.getActiveProductsStream(),
        builder: (context, productSnapshot) {
          if (productSnapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (productSnapshot.hasError) {
            return _buildErrorState(
              'Gagal memuat data produk: ${productSnapshot.error}',
            );
          }

          final products = productSnapshot.data ?? [];
          final lowStockProducts = _getLowStockProducts(products);

          return StreamBuilder<List<BatchModel>>(
            stream: _batchRepository.getBatchesStream(),
            builder: (context, batchSnapshot) {
              if (batchSnapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }

              if (batchSnapshot.hasError) {
                return _buildErrorState(
                  'Gagal memuat data batch: ${batchSnapshot.error}',
                );
              }

              final batches = batchSnapshot.data ?? [];
              final oldBatches = _getOldBatches(batches);

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
                          _buildSummaryCard(
                            lowStockCount: lowStockProducts.length,
                            oldBatchCount: oldBatches.length,
                          ),
                          const SizedBox(height: 16),
                          _buildSectionTitle(
                            title: 'Peringatan Stok Menipis',
                            subtitle:
                                'Produk yang stoknya berada pada atau di bawah batas minimum.',
                          ),
                          _buildLowStockSection(lowStockProducts),
                          const SizedBox(height: 18),
                          _buildSectionTitle(
                            title: 'Peringatan Batch Terlalu Lama',
                            subtitle:
                                'Batch aktif yang tersimpan selama $oldBatchThresholdDays hari atau lebih.',
                          ),
                          _buildOldBatchSection(oldBatches),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
