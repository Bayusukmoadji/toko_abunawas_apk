import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/models/batch_model.dart';

class BatchDetailPage extends StatelessWidget {
  final BatchModel batch;

  const BatchDetailPage({
    super.key,
    required this.batch,
  });

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getStatusText(String status) {
    if (status == 'empty') {
      return 'Habis';
    }

    return 'Aktif';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receivedDate = batch.receivedAt.toDate();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Batch'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          'QR Code Batch',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        QrImageView(
                          data: batch.qrCodeValue,
                          version: QrVersions.auto,
                          size: 220,
                          gapless: false,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          batch.batchCode,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          batch.productName,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Produk', batch.productName),
                        _buildInfoRow('Kode Batch', batch.batchCode),
                        _buildInfoRow(
                          'Lokasi',
                          batch.storageLocation.isEmpty
                              ? '-'
                              : batch.storageLocation,
                        ),
                        _buildInfoRow(
                          'Tanggal Masuk',
                          _formatDate(receivedDate),
                        ),
                        _buildInfoRow(
                          'Jumlah Awal',
                          '${batch.initialQty} ${batch.unit}',
                        ),
                        _buildInfoRow(
                          'Sisa Stok',
                          '${batch.remainingQty} ${batch.unit}',
                        ),
                        _buildInfoRow('Status', _getStatusText(batch.status)),
                        _buildInfoRow('Dibuat Oleh', batch.createdByName),
                        _buildInfoRow(
                          'Catatan',
                          batch.notes.isEmpty ? '-' : batch.notes,
                        ),
                        _buildInfoRow('QR Value', batch.qrCodeValue),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
