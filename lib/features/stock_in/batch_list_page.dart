import 'package:flutter/material.dart';

import '../../data/models/batch_model.dart';
import '../../data/repositories/batch_repository.dart';
import 'batch_detail_page.dart';

class BatchListPage extends StatelessWidget {
  BatchListPage({super.key});

  final BatchRepository _batchRepository = BatchRepository();

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  Color _getStatusColor(String status) {
    final normalizedStatus = status.toLowerCase().trim();

    if (normalizedStatus == 'empty') {
      return Colors.red;
    }

    return Colors.green;
  }

  String _getStatusText(String status) {
    final normalizedStatus = status.toLowerCase().trim();

    if (normalizedStatus == 'empty') {
      return 'Habis';
    }

    return 'Aktif';
  }

  int _getActiveBatchCount(List<BatchModel> batches) {
    return batches.where((batch) {
      return batch.status.toLowerCase().trim() != 'empty';
    }).length;
  }

  int _getEmptyBatchCount(List<BatchModel> batches) {
    return batches.where((batch) {
      return batch.status.toLowerCase().trim() == 'empty';
    }).length;
  }

  int _getTotalRemainingStock(List<BatchModel> batches) {
    return batches.fold<int>(
      0,
      (total, batch) => total + batch.remainingQty,
    );
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
                Icons.inventory_2_outlined,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daftar Batch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Pantau stok per-batch, lokasi penyimpanan, status batch, dan QR Code.',
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

  Widget _buildSummaryCard(List<BatchModel> batches) {
    final activeBatch = _getActiveBatchCount(batches);
    final emptyBatch = _getEmptyBatchCount(batches);
    final totalRemainingStock = _getTotalRemainingStock(batches);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Batch',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              icon: Icons.inventory_2_outlined,
              label: 'Total Batch',
              value: '${batches.length}',
              color: Colors.blue,
            ),
            _buildSummaryRow(
              icon: Icons.check_circle_outline,
              label: 'Batch Aktif',
              value: '$activeBatch',
              color: Colors.green,
            ),
            _buildSummaryRow(
              icon: Icons.cancel_outlined,
              label: 'Batch Habis',
              value: '$emptyBatch',
              color: Colors.red,
            ),
            _buildSummaryRow(
              icon: Icons.scale_outlined,
              label: 'Total Sisa Stok',
              value: '$totalRemainingStock karung',
              color: Colors.orange,
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

  Widget _buildStatusChip(String status) {
    final statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withOpacity(0.35),
        ),
      ),
      child: Text(
        _getStatusText(status),
        style: TextStyle(
          color: statusColor,
          fontSize: 12,
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
      padding: const EdgeInsets.only(top: 6),
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

  Widget _buildBatchCard({
    required BuildContext context,
    required BatchModel batch,
  }) {
    final receivedDate = batch.receivedAt.toDate();
    final location = batch.storageLocation.trim().isEmpty
        ? '-'
        : batch.storageLocation.trim();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BatchDetailPage(batch: batch),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor:
                    _getStatusColor(batch.status).withOpacity(0.12),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: _getStatusColor(batch.status),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            batch.batchCode,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(batch.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      icon: Icons.calendar_month_outlined,
                      text: 'Tanggal masuk: ${_formatDate(receivedDate)}',
                    ),
                    _buildInfoRow(
                      icon: Icons.inventory_outlined,
                      text:
                          'Sisa stok: ${batch.remainingQty} ${batch.unit} dari ${batch.initialQty} ${batch.unit}',
                    ),
                    _buildInfoRow(
                      icon: Icons.location_on_outlined,
                      text: 'Lokasi: $location',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Belum ada data batch.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Gagal memuat data batch: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.red,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Batch'),
      ),
      body: StreamBuilder<List<BatchModel>>(
        stream: _batchRepository.getBatchesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          final batches = snapshot.data ?? [];

          if (batches.isEmpty) {
            return _buildEmptyState();
          }

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 12),
                _buildSummaryCard(batches),
                const SizedBox(height: 12),
                const Text(
                  'Data Batch',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pilih batch untuk melihat detail dan QR Code.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                ...batches.map(
                  (batch) => _buildBatchCard(
                    context: context,
                    batch: batch,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
