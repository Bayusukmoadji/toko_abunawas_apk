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

    if (normalizedStatus == 'empty') {
      return Colors.red.shade400;
    }

    return Colors.green.shade600;
  }

  String _getStatusLabel(String status) {
    final normalizedStatus = status.toLowerCase().trim();

    if (normalizedStatus == 'empty') {
      return 'Habis';
    }

    return 'Aktif';
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

  Widget _buildTopInfoBanner() {
    return Image.asset(
      'assets/batch/info.png',
      // Menggunakan constraint tinggi tetap agar gambar tidak kebesaran/melar di HP
      height: 52,
      fit: BoxFit.contain,
    );
  }

  Widget _buildSelectableInfoRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final displayValue = value.trim().isEmpty ? '-' : value.trim();

    return Padding(
      // Padding dikurangi drastis agar lebih rapat dan hemat ruang
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              displayValue,
              style: TextStyle(
                fontSize: 10.5,
                color: valueColor ?? Colors.black87,
                fontWeight:
                    valueColor != null ? FontWeight.bold : FontWeight.normal,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receivedAt = batch.receivedAt.toDate();
    final createdAt = batch.createdAt.toDate();
    final updatedAt = batch.updatedAt.toDate();
    final statusColor = _getStatusColor(batch.status);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(115.0),
        child: Builder(builder: (context) {
          final topPadding = MediaQuery.of(context).padding.top;

          return SizedBox(
            height: 115.0 + topPadding,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  height: 85 + topPadding,
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
                Positioned(
                  top: topPadding,
                  left: 0,
                  right: 0,
                  height: 55,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_double_arrow_left,
                            color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(right: 48.0),
                            child: Text(
                              'DETAIL BATCH',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _buildTopInfoBanner(),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
      body: SafeArea(
        top: false,
        // Dihapus: SingleChildScrollView.
        // Diganti dengan Column yang akan mengambil tinggi layar secara mutlak.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/batch/outcard.png'),
                fit: BoxFit.fill,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Bagian QR Code ---
                const Text(
                  'QR Code Batch',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'QR Code digunakan untuk identifikasi batch saat proses scan stok keluar.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                    height: 1.2,
                  ),
                ),

                // --- QR Code Dinamis ---
                // Expanded akan menyerap seluruh sisa ruang tengah yang ada,
                // sehingga QR code akan mengecil dengan sendirinya menyesuaikan HP.
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: LayoutBuilder(builder: (context, constraints) {
                            // Menghitung ukuran dinamis agar tidak memakan ruang
                            double size = constraints.maxHeight;
                            if (size > 140) size = 140; // Max 140

                            return SizedBox(
                              width: size,
                              height: size,
                              child: QrImageView(
                                data: batch.qrCodeValue,
                                version: QrVersions.auto,
                                backgroundColor: Colors.transparent,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SelectableText(
                              batch.qrCodeValue.trim().isEmpty
                                  ? '-'
                                  : batch.qrCodeValue,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _copyQrValue(context),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.copy,
                                  size: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          batch.productName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          batch.batchCode,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // --- Bagian Informasi Batch ---
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/batch/cardinfo.png'),
                      fit: BoxFit.fill,
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize:
                        MainAxisSize.min, // Membuat Card sepadat mungkin
                    children: [
                      Text(
                        'Informasi Batch',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Seluruh informasi di bawah ini dapat diseleksi dan disalin secara manual.',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 10),
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
                        valueColor: statusColor,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
