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
                Icons.qr_code_2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detail Batch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Lihat identitas batch, QR Code, lokasi penyimpanan, dan status stok per-batch.',
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

  Widget _buildStatusChip() {
    final statusColor = _getStatusColor(batch.status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withOpacity(0.35),
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

  Widget _buildSelectableInfoRow({
    required String label,
    required String value,
  }) {
    final displayValue = value.trim().isEmpty ? '-' : value.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              displayValue,
              style: const TextStyle(
                fontSize: 13.5,
                color: Colors.black87,
                height: 1.3,
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 118,
            child: Text(
              'QR Value',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              displayValue,
              style: const TextStyle(
                fontSize: 13.5,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _copyQrValue(context),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
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

  Widget _buildQrCodeCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'QR Code Batch',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'QR Code digunakan untuk identifikasi batch saat proses scan stok keluar.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.grey.shade200,
                  ),
                ),
                child: QrImageView(
                  data: batch.qrCodeValue,
                  version: QrVersions.auto,
                  size: 230,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
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
          ],
        ),
      ),
    );
  }

  Widget _buildStockSummaryCard() {
    final statusColor = _getStatusColor(batch.status);
    final location = batch.storageLocation.trim().isEmpty
        ? '-'
        : batch.storageLocation.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: statusColor.withOpacity(0.12),
              child: Icon(
                Icons.inventory_2_outlined,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ringkasan Stok Batch',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Sisa stok: ${batch.remainingQty} ${batch.unit} dari ${batch.initialQty} ${batch.unit}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Lokasi: $location',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
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

  Widget _buildBatchInfoCard() {
    final receivedAt = batch.receivedAt.toDate();
    final createdAt = batch.createdAt.toDate();
    final updatedAt = batch.updatedAt.toDate();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informasi Batch',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Seluruh informasi di bawah ini dapat diseleksi dan disalin secara manual.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.3,
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.blue,
              size: 22,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Data batch tetap disimpan meskipun stok telah habis. Jika sisa stok menjadi 0, status batch berubah menjadi Habis/empty agar riwayat transaksi tetap dapat dilacak.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.35,
                ),
              ),
            ),
          ],
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
      body: SafeArea(
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
                  _buildQrCodeCard(context),
                  const SizedBox(height: 12),
                  _buildStockSummaryCard(),
                  const SizedBox(height: 12),
                  _buildBatchInfoCard(),
                  const SizedBox(height: 12),
                  _buildExplanationCard(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
