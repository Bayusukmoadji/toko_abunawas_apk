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
    return '${date.day}/${date.month}/${date.year}';
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
      if (batch.status != 'active') return false;
      if (batch.remainingQty <= 0) return false;

      final storedDays = _calculateStoredDays(batch.receivedAt.toDate());
      return storedDays >= oldBatchThresholdDays;
    }).toList();
  }

  Widget _buildLowStockSection(List<ProductModel> lowStockProducts) {
    if (lowStockProducts.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Tidak ada produk dengan stok menipis.'),
        ),
      );
    }

    return Column(
      children: lowStockProducts.map((product) {
        return Card(
          color: Colors.orange.shade50,
          child: ListTile(
            leading: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
            ),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Stok saat ini: ${product.totalStock} ${product.unit}\n'
              'Minimum stok: ${product.minimumStock} ${product.unit}',
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOldBatchSection(List<BatchModel> oldBatches) {
    if (oldBatches.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Tidak ada batch yang terlalu lama tersimpan.'),
        ),
      );
    }

    return Column(
      children: oldBatches.map((batch) {
        final receivedDate = batch.receivedAt.toDate();
        final storedDays = _calculateStoredDays(receivedDate);

        return Card(
          color: Colors.red.shade50,
          child: ListTile(
            leading: const Icon(
              Icons.inventory_2_outlined,
              color: Colors.red,
            ),
            title: Text(
              '${batch.batchCode} - ${batch.productName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Tanggal masuk: ${_formatDate(receivedDate)}\n'
              'Lama tersimpan: $storedDays hari\n'
              'Sisa stok: ${batch.remainingQty} ${batch.unit}\n'
              'Lokasi: ${batch.storageLocation.isEmpty ? '-' : batch.storageLocation}',
            ),
          ),
        );
      }).toList(),
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
            return const Center(child: CircularProgressIndicator());
          }

          if (productSnapshot.hasError) {
            return Center(
              child: Text('Gagal memuat data produk: ${productSnapshot.error}'),
            );
          }

          final products = productSnapshot.data ?? [];
          final lowStockProducts = _getLowStockProducts(products);

          return StreamBuilder<List<BatchModel>>(
            stream: _batchRepository.getBatchesStream(),
            builder: (context, batchSnapshot) {
              if (batchSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (batchSnapshot.hasError) {
                return Center(
                  child:
                      Text('Gagal memuat data batch: ${batchSnapshot.error}'),
                );
              }

              final batches = batchSnapshot.data ?? [];
              final oldBatches = _getOldBatches(batches);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ringkasan Peringatan',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Produk stok menipis: ${lowStockProducts.length}',
                                ),
                                Text(
                                  'Batch terlalu lama: ${oldBatches.length}',
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Catatan: batch dianggap terlalu lama apabila tersimpan 30 hari atau lebih.',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Peringatan Stok Menipis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildLowStockSection(lowStockProducts),
                        const SizedBox(height: 24),
                        const Text(
                          'Peringatan Batch Terlalu Lama',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
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
