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
      return Colors.red.shade400;
    }

    return Colors.green.shade600;
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

  Widget _buildSummaryCard(List<BatchModel> batches) {
    final activeBatch = _getActiveBatchCount(batches);
    final emptyBatch = _getEmptyBatchCount(batches);
    final totalRemainingStock = _getTotalRemainingStock(batches);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ringkasan Batch',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFC8E6C9).withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_alt_outlined,
                      size: 16, color: Colors.green.shade800),
                  const SizedBox(width: 4),
                  Text(
                    'Filter',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                  label: 'Total Batch', value: '${batches.length}'),
              _buildSummaryRow(label: 'Batch Aktif', value: '$activeBatch'),
              _buildSummaryRow(label: 'Batch Habis', value: '$emptyBatch'),
              _buildSummaryRow(
                label: 'Total Sisa Stok',
                value: '$totalRemainingStock karung',
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
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
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
            height: 12,
          ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    final statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
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
          fontSize: 11,
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
            size: 15,
            color: Colors.black45,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        _getStatusColor(batch.status).withOpacity(0.15),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                      color: _getStatusColor(batch.status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batch.productName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          batch.batchCode,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
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
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(
                        Icons.keyboard_double_arrow_right,
                        color: Colors.black87,
                        size: 20,
                      ),
                      _buildStatusChip(batch.status),
                    ],
                  ),
                ],
              ),
            ),
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
            'DAFTAR BATCH',
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
                  Color(0xFF1B5E20),
                  Color(0xFF4CAF50)
                ], // Gradien hijau mirip desain
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<BatchModel>>(
        stream: _batchRepository.getBatchesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                _buildSummaryCard(batches),
                const SizedBox(height: 24),
                const Text(
                  'Data Batch',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
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
