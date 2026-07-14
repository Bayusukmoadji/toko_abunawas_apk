import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models/batch_model.dart';
import '../../data/repositories/batch_repository.dart';

class BatchDetailPage extends StatefulWidget {
  final BatchModel batch;

  const BatchDetailPage({
    super.key,
    required this.batch,
  });

  @override
  State<BatchDetailPage> createState() => _BatchDetailPageState();
}

class _BatchDetailPageState extends State<BatchDetailPage> {
  final BatchRepository _batchRepository = BatchRepository();

  late BatchModel _batch;

  bool _isMovingLocation = false;

  @override
  void initState() {
    super.initState();
    _batch = widget.batch;
  }

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

  String _normalizeLocation(String value) {
    return value.trim().toUpperCase();
  }

  Color _getStatusColor(String status) {
    final normalizedStatus = status.toLowerCase().trim();

    if (normalizedStatus == 'empty' || normalizedStatus == 'depleted') {
      return Colors.red.shade400;
    }

    return Colors.green.shade600;
  }

  String _getStatusLabel(String status) {
    final normalizedStatus = status.toLowerCase().trim();

    if (normalizedStatus == 'empty' || normalizedStatus == 'depleted') {
      return 'Habis';
    }

    return 'Aktif';
  }

  bool get _isBatchActive {
    final normalizedStatus = _batch.status.toLowerCase().trim();

    return normalizedStatus == 'active' && _batch.remainingQty > 0;
  }

  bool get _isBatchInBackupLocation {
    return _batchRepository.isBackupStorageLocation(
      _batch.storageLocation,
    );
  }

  bool get _canMoveLocation {
    return _isBatchActive && _isBatchInBackupLocation;
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

  void _copyQrValue(BuildContext context) {
    final qrValue = _batch.qrCodeValue.trim();

    if (qrValue.isEmpty) {
      _showSnackBar(
        message: 'QR Value tidak memiliki data untuk disalin.',
        color: Colors.orange,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    Clipboard.setData(
      ClipboardData(text: qrValue),
    );

    _showSnackBar(
      message: 'QR Value berhasil disalin.',
      color: Colors.green,
      icon: Icons.check_circle_outline,
    );
  }

  Future<void> _printQrCode(
    BuildContext context,
  ) async {
    try {
      final document = pw.Document();

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'LABEL BATCH',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: _batch.qrCodeValue,
                    width: 250,
                    height: 250,
                  ),
                  pw.SizedBox(height: 30),
                  pw.Text(
                    _batch.productName,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Kode Batch: ${_batch.batchCode}',
                    style: const pw.TextStyle(
                      fontSize: 18,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Lokasi: '
                    '${_batch.storageLocation.trim().isEmpty ? "-" : _batch.storageLocation}',
                    style: const pw.TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return document.save();
        },
        name: 'Label_Batch_${_batch.batchCode}',
      );
    } catch (e) {
      _showSnackBar(
        message: 'Gagal mencetak QR Code: $e',
        color: Colors.redAccent,
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _openMoveLocation() async {
    if (!_canMoveLocation) {
      _showSnackBar(
        message: 'Batch ini tidak dapat dipindahkan dari lokasi saat ini.',
        color: Colors.orange,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() {
      _isMovingLocation = true;
    });

    try {
      final availableLocations =
          await _batchRepository.getAvailableMainStorageLocations();

      if (!mounted) {
        return;
      }

      setState(() {
        _isMovingLocation = false;
      });

      if (availableLocations.isEmpty) {
        _showSnackBar(
          message: 'Belum ada lokasi kosong di dalam gudang. '
              'Batch tetap disimpan di ${_batch.storageLocation}.',
          color: Colors.orange,
          icon: Icons.warehouse_outlined,
        );
        return;
      }

      await _showMoveLocationBottomSheet(
        availableLocations,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isMovingLocation = false;
      });

      final message = e.toString().replaceFirst(
            'Exception: ',
            '',
          );

      _showSnackBar(
        message: 'Gagal memuat lokasi kosong: $message',
        color: Colors.redAccent,
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _showMoveLocationBottomSheet(
    List<String> availableLocations,
  ) async {
    String? selectedTargetLocation;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (
            context,
            setModalState,
          ) {
            return SafeArea(
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20,
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 46,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Pindahkan Lokasi Batch',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Navigator.pop(
                                bottomSheetContext,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pilih salah satu lokasi kosong '
                        'di dalam gudang.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.orange.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informasi Pemindahan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB85C00),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildMoveInfoRow(
                              label: 'Batch',
                              value: _batch.batchCode,
                            ),
                            _buildMoveInfoRow(
                              label: 'Produk',
                              value: _batch.productName,
                            ),
                            _buildMoveInfoRow(
                              label: 'Sisa Stok',
                              value: '${_batch.remainingQty} ${_batch.unit}',
                            ),
                            _buildMoveInfoRow(
                              label: 'Lokasi Asal',
                              value: _batch.storageLocation,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Lokasi Tujuan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableLocations.map(
                          (location) {
                            final isSelected =
                                selectedTargetLocation == location;

                            return InkWell(
                              onTap: () {
                                setModalState(() {
                                  selectedTargetLocation = location;
                                });
                              },
                              borderRadius: BorderRadius.circular(
                                12,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(
                                  milliseconds: 160,
                                ),
                                width: 54,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? const LinearGradient(
                                          colors: [
                                            Color(
                                              0xFF84E977,
                                            ),
                                            Color(
                                              0xFF038E1B,
                                            ),
                                            Color(
                                              0xFF015816,
                                            ),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: isSelected ? null : Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    12,
                                  ),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(
                                            0xFF038E1B,
                                          )
                                        : const Color(
                                            0xFFDADADA,
                                          ),
                                  ),
                                ),
                                child: Text(
                                  location,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(
                                            0xFF015816,
                                          ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ).toList(),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFFBEF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFB7E8B4),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF038E1B),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pindahkan batch secara fisik '
                                'dari belakang gudang ke lokasi '
                                'tujuan sebelum mengonfirmasi.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: selectedTargetLocation == null
                              ? null
                              : () async {
                                  final target = selectedTargetLocation!;

                                  final confirmed =
                                      await _showMoveConfirmationDialog(
                                    sourceLocation: _batch.storageLocation,
                                    targetLocation: target,
                                  );

                                  if (confirmed != true) {
                                    return;
                                  }

                                  if (bottomSheetContext.mounted) {
                                    Navigator.pop(
                                      bottomSheetContext,
                                    );
                                  }

                                  await Future<void>.delayed(
                                    Duration.zero,
                                  );

                                  if (!mounted) {
                                    return;
                                  }

                                  await _performMoveLocation(
                                    target,
                                  );
                                },
                          icon: const Icon(
                            Icons.move_down_outlined,
                          ),
                          label: const Text(
                            'Konfirmasi Pemindahan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF038E1B),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMoveInfoRow({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showMoveConfirmationDialog({
    required String sourceLocation,
    required String targetLocation,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.move_down_outlined,
                color: Color(0xFF038E1B),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Konfirmasi Pemindahan',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConfirmationRow(
                label: 'Kode Batch',
                value: _batch.batchCode,
              ),
              _buildConfirmationRow(
                label: 'Produk',
                value: _batch.productName,
              ),
              _buildConfirmationRow(
                label: 'Sisa Stok',
                value: '${_batch.remainingQty} ${_batch.unit}',
              ),
              _buildConfirmationRow(
                label: 'Lokasi Asal',
                value: sourceLocation,
              ),
              _buildConfirmationRow(
                label: 'Lokasi Tujuan',
                value: targetLocation,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orange.shade200,
                  ),
                ),
                child: const Text(
                  'Pastikan batch sudah dipindahkan '
                  'secara fisik sebelum menekan tombol '
                  'Konfirmasi.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF038E1B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Konfirmasi'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfirmationRow({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performMoveLocation(
    String targetLocation,
  ) async {
    final sourceLocation = _normalizeLocation(_batch.storageLocation);
    final cleanTargetLocation = _normalizeLocation(targetLocation);

    setState(() {
      _isMovingLocation = true;
    });

    try {
      await _batchRepository.moveBatchFromBackupToMain(
        batchId: _batch.id,
        targetLocation: cleanTargetLocation,
      );

      final updatedBatch = await _batchRepository.getBatchById(
        _batch.id,
      );

      if (!mounted) {
        return;
      }

      if (updatedBatch != null) {
        setState(() {
          _batch = updatedBatch;
        });
      }

      _showSnackBar(
        message: 'Batch berhasil dipindahkan dari '
            '$sourceLocation ke $cleanTargetLocation.',
        color: const Color(0xFF038E1B),
        icon: Icons.check_circle_outline,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      final message = e.toString().replaceFirst(
            'Exception: ',
            '',
          );

      _showSnackBar(
        message: 'Gagal memindahkan batch: $message',
        color: Colors.redAccent,
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMovingLocation = false;
        });
      }
    }
  }

  Widget _buildTopInfoBanner() {
    return Image.asset(
      'assets/batch/info.png',
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

  Widget _buildBackupLocationNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warehouse_outlined,
            size: 22,
            color: Colors.orange.shade800,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Batch ini masih berada di belakang '
              'gudang (${_batch.storageLocation}). '
              'Pindahkan ke lokasi utama apabila '
              'sudah tersedia slot kosong.',
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveLocationButton() {
    return SizedBox(
      width: double.infinity,
      height: 43,
      child: ElevatedButton.icon(
        onPressed: _isMovingLocation ? null : _openMoveLocation,
        icon: _isMovingLocation
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.move_down_outlined,
              ),
        label: Text(
          _isMovingLocation ? 'Memuat Lokasi...' : 'Pindahkan ke Dalam Gudang',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF038E1B),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receivedAt = _batch.receivedAt.toDate();
    final createdAt = _batch.createdAt.toDate();
    final updatedAt = _batch.updatedAt.toDate();

    final statusColor = _getStatusColor(_batch.status);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(115),
        child: Builder(
          builder: (context) {
            final topPadding = MediaQuery.of(context).padding.top;

            return SizedBox(
              height: 115 + topPadding,
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
                        stops: [0, 0.5, 1],
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
                          icon: const Icon(
                            Icons.keyboard_double_arrow_left,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            Navigator.pop(
                              context,
                              _batch,
                            );
                          },
                        ),
                        const Expanded(
                          child: Center(
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
                        IconButton(
                          icon: const Icon(
                            Icons.print_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () {
                            _printQrCode(context);
                          },
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
          },
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            16,
            4,
            16,
            24,
          ),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  'assets/batch/outcard.png',
                ),
                fit: BoxFit.fill,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  'QR Code digunakan untuk '
                  'identifikasi batch saat proses '
                  'scan stok keluar.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: QrImageView(
                          data: _batch.qrCodeValue,
                          version: QrVersions.auto,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: SelectableText(
                              _batch.qrCodeValue.trim().isEmpty
                                  ? '-'
                                  : _batch.qrCodeValue,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              _copyQrValue(context);
                            },
                            borderRadius: BorderRadius.circular(
                              20,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(
                                4,
                              ),
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
                        _batch.productName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        _batch.batchCode,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                        'assets/batch/cardinfo.png',
                      ),
                      fit: BoxFit.fill,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                        'Seluruh informasi di bawah '
                        'ini dapat diseleksi dan disalin '
                        'secara manual.',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildSelectableInfoRow(
                        label: 'Produk',
                        value: _batch.productName,
                      ),
                      _buildSelectableInfoRow(
                        label: 'Kode Batch',
                        value: _batch.batchCode,
                      ),
                      _buildSelectableInfoRow(
                        label: 'Lokasi',
                        value: _batch.storageLocation,
                      ),
                      _buildSelectableInfoRow(
                        label: 'QR Value',
                        value: _batch.qrCodeValue,
                      ),
                      _buildSelectableInfoRow(
                        label: 'Tanggal Masuk',
                        value: _formatDate(receivedAt),
                      ),
                      _buildSelectableInfoRow(
                        label: 'Jumlah Awal',
                        value: '${_batch.initialQty} ${_batch.unit}',
                      ),
                      _buildSelectableInfoRow(
                        label: 'Sisa Stok',
                        value: '${_batch.remainingQty} ${_batch.unit}',
                      ),
                      _buildSelectableInfoRow(
                        label: 'Satuan',
                        value: _batch.unit,
                      ),
                      _buildSelectableInfoRow(
                        label: 'Status',
                        value: _getStatusLabel(
                          _batch.status,
                        ),
                        valueColor: statusColor,
                      ),
                      _buildSelectableInfoRow(
                        label: 'Dibuat Oleh',
                        value: _batch.createdByName,
                      ),
                      _buildSelectableInfoRow(
                        label: 'Catatan',
                        value: _batch.notes,
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
                if (_canMoveLocation) ...[
                  const SizedBox(height: 14),
                  _buildBackupLocationNotice(),
                  const SizedBox(height: 10),
                  _buildMoveLocationButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
