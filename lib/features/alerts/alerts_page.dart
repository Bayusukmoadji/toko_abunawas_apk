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
      return Colors.red.shade500;
    }

    if (status == 'Menipis') {
      return Colors.orange.shade500;
    }

    return Colors.green.shade600;
  }

  Widget _buildSummaryCard({
    required int lowStockCount,
    required int oldBatchCount,
  }) {
    final totalAlerts = lowStockCount + oldBatchCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan Batch',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/batch/cardsum.png'),
              fit: BoxFit.fill,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSummaryRow(
                  label: 'Total Peringatan', value: '$totalAlerts'),
              _buildSummaryRow(
                  label: 'Produk Stok Menipis', value: '$lowStockCount'),
              _buildSummaryRow(
                label: 'Batch Terlalu Lama',
                value: '$oldBatchCount',
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
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                value,
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
            color: Colors.black38,
            thickness: 0.5,
            height: 8,
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
              height: 1.2,
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
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
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.4),
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
      padding: const EdgeInsets.only(top: 3),
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
                fontSize: 10.0,
                color: Colors.black54,
                height: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: const BoxConstraints(minHeight: 100),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/batch/cardbatch.png'),
              fit: BoxFit.fill,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: color.withOpacity(0.15),
                      child: Icon(
                        status == 'Habis'
                            ? Icons.cancel_outlined
                            : Icons.warning_amber_rounded,
                        size: 16,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 42), // Align content under the text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            icon: Icons.inventory_2_outlined,
                            text:
                                'Stok saat ini: ${product.totalStock} ${product.unit}',
                          ),
                          _buildInfoRow(
                            icon: Icons.low_priority_outlined,
                            text:
                                'Minimum stok: ${product.minimumStock} ${product.unit}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(text: status, color: color),
                  ],
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

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: const BoxConstraints(minHeight: 118),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/batch/cardbatch.png'),
              fit: BoxFit.fill,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.red.withOpacity(0.15),
                      child: const Icon(
                        Icons.history_toggle_off,
                        size: 16,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            batch.productName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
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
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 42),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            icon: Icons.calendar_today_outlined,
                            text: 'Tanggal masuk: ${_formatDate(receivedDate)}',
                          ),
                          _buildInfoRow(
                            icon: Icons.inventory_outlined,
                            text:
                                'Sisa stok: ${batch.remainingQty} ${batch.unit}',
                          ),
                          _buildInfoRow(
                            icon: Icons.location_on_outlined,
                            text: 'Lokasi: $location',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(
                      text: '$storedDays hari tersimpan',
                      color: Colors.red.shade500,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.green),
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_double_arrow_left,
                color: Colors.white),
            onPressed: () {
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
                stops: [0.0, 0.5, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
          ),
        ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard(
                          lowStockCount: lowStockProducts.length,
                          oldBatchCount: oldBatches.length,
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          title: 'Peringatan Stok Menipis',
                          subtitle:
                              'Produk yang stoknya berada pada atau di bawah batas minimum.',
                        ),
                        _buildLowStockSection(lowStockProducts),
                        const SizedBox(height: 12),
                        _buildSectionTitle(
                          title: 'Peringatan Batch Terlalu Lama',
                          subtitle:
                              'Batch aktif yang tersimpan $oldBatchThresholdDays hari atau lebih.',
                        ),
                        _buildOldBatchSection(oldBatches),
                      ],
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
