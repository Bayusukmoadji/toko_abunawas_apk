import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models/batch_model.dart';

class BatchDetailPage extends StatelessWidget {
  final BatchModel batch;

  const BatchDetailPage({
    super.key,
    required this.batch,
  });

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  Color _getStatusColor(String status) {
    final normalizedStatus = status.toLowerCase().trim();

    if (normalizedStatus == 'active') {
      return Colors.green;
    }

    if (normalizedStatus == 'empty') {
      return Colors.red;
    }

    return Colors.grey;
  }

  String _getStatusLabel(String status) {
    final normalizedStatus = status.toLowerCase().trim();

    if (normalizedStatus == 'active') {
      return 'Aktif';
    }

    if (normalizedStatus == 'empty') {
      return 'Habis';
    }

    return status;
  }

  void _copyQrValue(BuildContext context) {
    final qrValue = batch.qrCodeValue.trim();

    if (qrValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR Value tidak memiliki data untuk disalin.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Clipboard.setData(
      ClipboardData(text: qrValue),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR Value berhasil disalin.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSelectableInfoRow({
    required String label,
    required String value,
  }) {
    final displayValue = value.trim().isEmpty ? '-' : value.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              displayValue,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrValueRow(BuildContext context) {
    final displayValue =
        batch.qrCodeValue.trim().isEmpty ? '-' : batch.qrCodeValue.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 120,
            child: Text(
              'QR Value',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              displayValue,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _copyQrValue(context),
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.copy,
                size: 18,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    final statusColor = _getStatusColor(batch.status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.5),
        ),
      ),
      child: Text(
        _getStatusLabel(batch.status),
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildQrCodeCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'QR Code Batch',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                data: batch.qrCodeValue,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'QR Code digunakan sebagai identitas unik batch saat proses scan stok keluar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            _buildSelectableInfoRow(
              label: 'Produk',
              value: batch.productName,
            ),
            _buildSelectableInfoRow(
              label: 'Kode Batch',
              value: batch.batchCode,
            ),
            _buildQrValueRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchInfoCard(BuildContext context) {
    final receivedAt = batch.receivedAt.toDate();
    final createdAt = batch.createdAt.toDate();
    final updatedAt = batch.updatedAt.toDate();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Informasi Batch',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
            const SizedBox(height: 16),
            _buildSelectableInfoRow(
              label: 'Produk',
              value: batch.productName,
            ),
            _buildSelectableInfoRow(
              label: 'Kode Batch',
              value: batch.batchCode,
            ),
            _buildSelectableInfoRow(
              label: 'Lokasi',
              value: batch.storageLocation,
            ),
            _buildSelectableInfoRow(
              label: 'QR Value',
              value: batch.qrCodeValue,
            ),
            _buildSelectableInfoRow(
              label: 'Tanggal Masuk',
              value: _formatDate(receivedAt),
            ),
            _buildSelectableInfoRow(
              label: 'Jumlah Awal',
              value: '${batch.initialQty} ${batch.unit}',
            ),
            _buildSelectableInfoRow(
              label: 'Sisa Stok',
              value: '${batch.remainingQty} ${batch.unit}',
            ),
            _buildSelectableInfoRow(
              label: 'Satuan',
              value: batch.unit,
            ),
            _buildSelectableInfoRow(
              label: 'Status',
              value: _getStatusLabel(batch.status),
            ),
            _buildSelectableInfoRow(
              label: 'Dibuat Oleh',
              value: batch.createdByName,
            ),
            _buildSelectableInfoRow(
              label: 'Catatan',
              value: batch.notes,
            ),
            _buildSelectableInfoRow(
              label: 'Dibuat Pada',
              value: _formatDateTime(createdAt),
            ),
            _buildSelectableInfoRow(
              label: 'Diperbarui',
              value: _formatDateTime(updatedAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Card(
      color: Colors.blue.shade50,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Catatan: data batch tetap disimpan meskipun stok telah habis. '
          'Jika sisa stok menjadi 0, status batch akan berubah menjadi Habis/empty '
          'agar riwayat transaksi tetap dapat dilacak.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Batch'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildQrCodeCard(context),
                const SizedBox(height: 16),
                _buildBatchInfoCard(context),
                const SizedBox(height: 16),
                _buildExplanationCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
