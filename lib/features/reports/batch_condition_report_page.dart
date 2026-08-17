import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/batch_condition_check_model.dart';
import '../../data/models/batch_model.dart';
import '../../data/repositories/batch_condition_repository.dart';
import '../../data/repositories/batch_repository.dart';

class BatchConditionReportPage extends StatelessWidget {
  BatchConditionReportPage({super.key});

  final BatchRepository _batchRepository = BatchRepository();
  final BatchConditionRepository _conditionRepository =
      BatchConditionRepository();

  static const int oldBatchThresholdDays = 30;

  final BoxShadow _softShadow = BoxShadow(
    color: Colors.black.withOpacity(0.07),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  bool _isActiveBatch(BatchModel batch) {
    final status = batch.status.toLowerCase().trim();

    return status == 'active' && batch.remainingQty > 0;
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  int _calculateStoredDays(DateTime receivedAt) {
    final receivedDate = DateTime(
      receivedAt.year,
      receivedAt.month,
      receivedAt.day,
    );

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final result = today.difference(receivedDate).inDays;

    return result < 0 ? 0 : result;
  }

  String _getUnit(String value) {
    final cleanValue = value.trim();

    return cleanValue.isEmpty ? 'karung' : cleanValue;
  }

  int _extractBatchSequence(String batchCode) {
    final parts = batchCode.trim().split('-');

    if (parts.isEmpty) {
      return 0;
    }

    return int.tryParse(parts.last.trim()) ?? 0;
  }

  String _getBatchCodeForSort(BatchModel batch) {
    final batchCode = batch.batchCode.trim().toUpperCase();

    if (batchCode.isNotEmpty) {
      return batchCode;
    }

    return batch.id.trim().toUpperCase();
  }

  int _compareBatchesForFifo(
    BatchModel first,
    BatchModel second,
  ) {
    final receivedAtComparison = first.receivedAt.compareTo(
      second.receivedAt,
    );

    if (receivedAtComparison != 0) {
      return receivedAtComparison;
    }

    final createdAtComparison = first.createdAt.compareTo(
      second.createdAt,
    );

    if (createdAtComparison != 0) {
      return createdAtComparison;
    }

    final firstBatchCode = _getBatchCodeForSort(first);
    final secondBatchCode = _getBatchCodeForSort(second);

    final firstSequence = _extractBatchSequence(
      firstBatchCode,
    );

    final secondSequence = _extractBatchSequence(
      secondBatchCode,
    );

    if (firstSequence > 0 &&
        secondSequence > 0 &&
        firstSequence != secondSequence) {
      return firstSequence.compareTo(secondSequence);
    }

    final batchCodeComparison = firstBatchCode.compareTo(
      secondBatchCode,
    );

    if (batchCodeComparison != 0) {
      return batchCodeComparison;
    }

    return first.id.trim().toUpperCase().compareTo(
          second.id.trim().toUpperCase(),
        );
  }

  List<_BatchConditionReportItem> _buildReportItems({
    required List<BatchModel> batches,
    required List<BatchConditionCheckModel> conditions,
  }) {
    final currentConditionByBatchId = <String, BatchConditionCheckModel>{};

    for (final condition in conditions) {
      currentConditionByBatchId[condition.batchId] = condition;
    }

    final items = batches
        .where(_isActiveBatch)
        .map(
          (batch) => _BatchConditionReportItem(
            batch: batch,
            condition: currentConditionByBatchId[batch.id],
          ),
        )
        .toList();

    items.sort((first, second) {
      final firstPriority = _conditionPriority(first);
      final secondPriority = _conditionPriority(second);

      final priorityComparison = firstPriority.compareTo(secondPriority);

      if (priorityComparison != 0) {
        return priorityComparison;
      }

      return _compareBatchesForFifo(
        first.batch,
        second.batch,
      );
    });

    return items;
  }

  int _conditionPriority(
    _BatchConditionReportItem item,
  ) {
    if (item.condition?.needsAttention == true) {
      return 0;
    }

    if (item.condition == null) {
      return 1;
    }

    return 2;
  }

  String _getConditionLabel(
    _BatchConditionReportItem item,
  ) {
    final condition = item.condition;

    if (condition == null) {
      return 'Belum Diperiksa';
    }

    if (condition.needsAttention) {
      return 'Perlu Perhatian';
    }

    return 'Normal';
  }

  Color _getConditionColor(
    _BatchConditionReportItem item,
  ) {
    final condition = item.condition;

    if (condition == null) {
      return Colors.blueGrey.shade600;
    }

    if (condition.needsAttention) {
      return Colors.orange.shade800;
    }

    return Colors.green.shade700;
  }

  IconData _getConditionIcon(
    _BatchConditionReportItem item,
  ) {
    final condition = item.condition;

    if (condition == null) {
      return Icons.help_outline_rounded;
    }

    if (condition.needsAttention) {
      return Icons.warning_amber_rounded;
    }

    return Icons.check_circle_outline;
  }

  String _getFindingsText(
    _BatchConditionReportItem item,
  ) {
    final condition = item.condition;

    if (condition == null) {
      return '-';
    }

    if (condition.findings.isEmpty) {
      return 'Tidak ada temuan';
    }

    return condition.findings.join('; ');
  }

  int _getNormalCount(
    List<_BatchConditionReportItem> items,
  ) {
    return items.where((item) {
      final condition = item.condition;

      return condition != null && !condition.needsAttention;
    }).length;
  }

  int _getNeedsAttentionCount(
    List<_BatchConditionReportItem> items,
  ) {
    return items.where((item) {
      return item.condition?.needsAttention == true;
    }).length;
  }

  int _getUninspectedCount(
    List<_BatchConditionReportItem> items,
  ) {
    return items.where((item) {
      return item.condition == null;
    }).length;
  }

  int _getOldBatchCount(
    List<_BatchConditionReportItem> items,
  ) {
    return items.where((item) {
      final days = _calculateStoredDays(
        item.batch.receivedAt.toDate(),
      );

      return days >= oldBatchThresholdDays;
    }).length;
  }

  Future<Uint8List> _buildConditionReportPdf(
    List<_BatchConditionReportItem> items,
  ) async {
    final pdf = pw.Document();

    final now = DateTime.now();

    final normalCount = _getNormalCount(items);
    final needsAttentionCount = _getNeedsAttentionCount(items);
    final uninspectedCount = _getUninspectedCount(items);
    final oldBatchCount = _getOldBatchCount(items);

    pw.Widget buildSummaryBox() {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(
            color: PdfColors.grey400,
          ),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Ringkasan',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(1),
                1: pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(
                        right: 8,
                        bottom: 3,
                      ),
                      child: pw.Text(
                        'Batch aktif: ${items.length}',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(
                        bottom: 3,
                      ),
                      child: pw.Text(
                        'Kondisi normal: $normalCount',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(
                        right: 8,
                        bottom: 3,
                      ),
                      child: pw.Text(
                        'Perlu perhatian: $needsAttentionCount',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(
                        bottom: 3,
                      ),
                      child: pw.Text(
                        'Belum diperiksa: $uninspectedCount',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(
                        right: 8,
                      ),
                      child: pw.Text(
                        'Usia >= $oldBatchThresholdDays hari: $oldBatchCount',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                    pw.SizedBox(),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 7),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(7),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'Catatan: status kondisi berasal dari hasil pemeriksaan '
                'fisik pengguna. Peringatan usia batch >= '
                '$oldBatchThresholdDays hari hanya menunjukkan lama '
                'penyimpanan dan tidak otomatis menyatakan kualitas '
                'beras menurun.',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  lineSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget buildMainTable() {
      if (items.isEmpty) {
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: PdfColors.grey400,
            ),
          ),
          child: pw.Text(
            'Tidak ada batch aktif untuk ditampilkan.',
            style: const pw.TextStyle(
              fontSize: 8.5,
            ),
          ),
        );
      }

      return pw.TableHelper.fromTextArray(
        border: pw.TableBorder.all(
          color: PdfColors.grey400,
          width: 0.5,
        ),
        headerDecoration: const pw.BoxDecoration(
          color: PdfColors.green700,
        ),
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 7.2,
        ),
        cellStyle: const pw.TextStyle(
          fontSize: 6.8,
          lineSpacing: 1.5,
        ),
        cellPadding: const pw.EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 4,
        ),
        cellAlignment: pw.Alignment.centerLeft,
        columnWidths: const {
          0: pw.FixedColumnWidth(24),
          1: pw.FlexColumnWidth(2.6),
          2: pw.FixedColumnWidth(48),
          3: pw.FixedColumnWidth(48),
          4: pw.FixedColumnWidth(68),
          5: pw.FixedColumnWidth(70),
        },
        headers: const [
          'No',
          'Batch / Produk / Lokasi',
          'Usia',
          'Stok',
          'Kondisi',
          'Pemeriksaan',
        ],
        data: List.generate(
          items.length,
          (index) {
            final item = items[index];
            final batch = item.batch;
            final condition = item.condition;

            final storedDays = _calculateStoredDays(
              batch.receivedAt.toDate(),
            );

            final location = batch.storageLocation.trim().isEmpty
                ? '-'
                : batch.storageLocation.trim();

            return [
              '${index + 1}',
              '${batch.batchCode}\n'
                  '${batch.productName}\n'
                  'Lokasi: $location',
              '$storedDays hari'
                  '${storedDays >= oldBatchThresholdDays ? '\n(Peringatan usia)' : ''}',
              '${batch.remainingQty}\n${_getUnit(batch.unit)}',
              _getConditionLabel(item),
              condition == null
                  ? '-'
                  : _formatDateTime(
                      condition.checkedAt.toDate(),
                    ),
            ];
          },
        ),
      );
    }

    pw.Widget buildDetailTable() {
      if (items.isEmpty) {
        return pw.SizedBox();
      }

      return pw.TableHelper.fromTextArray(
        border: pw.TableBorder.all(
          color: PdfColors.grey400,
          width: 0.5,
        ),
        headerDecoration: const pw.BoxDecoration(
          color: PdfColors.green700,
        ),
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 7.2,
        ),
        cellStyle: const pw.TextStyle(
          fontSize: 6.8,
          lineSpacing: 1.5,
        ),
        cellPadding: const pw.EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 4,
        ),
        cellAlignment: pw.Alignment.topLeft,
        columnWidths: const {
          0: pw.FixedColumnWidth(24),
          1: pw.FlexColumnWidth(1.25),
          2: pw.FlexColumnWidth(2.1),
          3: pw.FlexColumnWidth(1.15),
          4: pw.FlexColumnWidth(1.7),
        },
        headers: const [
          'No',
          'Batch',
          'Temuan',
          'Pemeriksa',
          'Catatan',
        ],
        data: List.generate(
          items.length,
          (index) {
            final item = items[index];
            final condition = item.condition;

            return [
              '${index + 1}',
              item.batch.batchCode,
              condition == null ? 'Belum diperiksa' : _getFindingsText(item),
              condition == null ? '-' : condition.checkedByName,
              condition == null || condition.notes.trim().isEmpty
                  ? '-'
                  : condition.notes.trim(),
            ];
          },
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          24,
          24,
          24,
          28,
        ),
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey600,
              ),
            ),
          );
        },
        build: (context) {
          return [
            pw.Text(
              'Laporan Kondisi Batch',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Toko Beras Abunawas',
              style: const pw.TextStyle(
                fontSize: 9,
              ),
            ),
            pw.Text(
              'Tanggal cetak: ${_formatDateTime(now)}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 12),
            buildSummaryBox(),
            pw.SizedBox(height: 14),
            pw.Text(
              'Daftar Kondisi Batch Aktif',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 7),
            buildMainTable(),
            pw.SizedBox(height: 14),
            pw.Text(
              'Detail Temuan Pemeriksaan',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 7),
            buildDetailTable(),
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Keterangan:',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Normal: seluruh komponen pemeriksaan berada pada '
                    'kondisi normal.',
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      lineSpacing: 1.5,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Perlu Perhatian: terdapat minimal satu komponen '
                    'pemeriksaan yang tidak berada pada kondisi normal '
                    'dan perlu diperiksa atau ditindaklanjuti oleh '
                    'karyawan/pemilik.',
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      lineSpacing: 1.5,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Belum Diperiksa: batch aktif belum memiliki hasil '
                    'pemeriksaan kondisi yang tersimpan.',
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      lineSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Laporan ini dihasilkan secara otomatis oleh '
              'Aplikasi Manajemen Stok Toko Beras Abunawas.',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey700,
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _generatePdf({
    required BuildContext context,
    required List<_BatchConditionReportItem> items,
  }) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak ada batch aktif untuk dibuat laporan.',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    await Printing.layoutPdf(
      name: 'laporan_kondisi_batch_abunawas.pdf',
      onLayout: (format) async {
        return _buildConditionReportPdf(items);
      },
    );
  }

  Widget _buildCleanCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color color = Colors.white,
  }) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E5E5),
          width: 1,
        ),
        boxShadow: [_softShadow],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
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
          padding: const EdgeInsets.symmetric(
            vertical: 5,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
            color: Colors.black12,
            thickness: 1,
            height: 10,
          ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required List<_BatchConditionReportItem> items,
  }) {
    final normalCount = _getNormalCount(items);
    final needsAttentionCount = _getNeedsAttentionCount(items);
    final uninspectedCount = _getUninspectedCount(items);
    final oldBatchCount = _getOldBatchCount(items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan Kondisi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _buildCleanCard(
          child: Column(
            children: [
              _buildSummaryRow(
                label: 'Batch Aktif',
                value: '${items.length}',
              ),
              _buildSummaryRow(
                label: 'Kondisi Normal',
                value: '$normalCount',
              ),
              _buildSummaryRow(
                label: 'Perlu Perhatian',
                value: '$needsAttentionCount',
              ),
              _buildSummaryRow(
                label: 'Belum Diperiksa',
                value: '$uninspectedCount',
              ),
              _buildSummaryRow(
                label: 'Usia Batch ≥ $oldBatchThresholdDays Hari',
                value: '$oldBatchCount',
                isLast: true,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8F1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFC8E6C9),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 19,
                      color: Color(0xFF038E1B),
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Peringatan usia dan kondisi batch merupakan '
                        'dua indikator yang berbeda. Usia ≥30 hari '
                        'tidak otomatis berarti kondisi beras bermasalah.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildPdfButton(
                context: context,
                items: items,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPdfButton({
    required BuildContext context,
    required List<_BatchConditionReportItem> items,
  }) {
    return Container(
      width: double.infinity,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF015816),
            Color(0xFF038E1B),
            Color(0xFF84E977),
          ],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.11),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: items.isEmpty
              ? null
              : () {
                  _generatePdf(
                    context: context,
                    items: items,
                  );
                },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.picture_as_pdf_rounded,
                size: 18,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Generate PDF Laporan Kondisi Batch',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daftar Kondisi Batch',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Batch diurutkan berdasarkan prioritas: Perlu Perhatian, '
          'Belum Diperiksa, lalu Normal.',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 11,
            height: 1.25,
          ),
        ),
      ],
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: color.withOpacity(0.35),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
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
      padding: const EdgeInsets.only(top: 4),
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
                fontSize: 10.5,
                color: Colors.black54,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionCard(
    _BatchConditionReportItem item,
  ) {
    final batch = item.batch;
    final condition = item.condition;

    final conditionLabel = _getConditionLabel(item);
    final conditionColor = _getConditionColor(item);
    final conditionIcon = _getConditionIcon(item);

    final storedDays = _calculateStoredDays(
      batch.receivedAt.toDate(),
    );

    final location = batch.storageLocation.trim().isEmpty
        ? '-'
        : batch.storageLocation.trim();

    final isOld = storedDays >= oldBatchThresholdDays;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: conditionColor.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: conditionColor.withOpacity(0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: conditionColor.withOpacity(0.14),
                child: Icon(
                  conditionIcon,
                  size: 18,
                  color: conditionColor,
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
              const SizedBox(width: 8),
              _buildStatusChip(
                text: conditionLabel,
                color: conditionColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(
              left: 44,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoText(
                  icon: Icons.access_time_rounded,
                  text: 'Usia penyimpanan: $storedDays hari'
                      '${isOld ? ' (peringatan usia)' : ''}',
                ),
                _buildInfoText(
                  icon: Icons.inventory_2_outlined,
                  text: 'Sisa stok: ${batch.remainingQty} '
                      '${_getUnit(batch.unit)}',
                ),
                _buildInfoText(
                  icon: Icons.location_on_outlined,
                  text: 'Lokasi: $location',
                ),
                if (condition == null)
                  _buildInfoText(
                    icon: Icons.fact_check_outlined,
                    text: 'Batch belum memiliki hasil pemeriksaan kondisi.',
                  )
                else ...[
                  _buildInfoText(
                    icon: Icons.fact_check_outlined,
                    text:
                        'Pemeriksaan: ${_formatDateTime(condition.checkedAt.toDate())}',
                  ),
                  _buildInfoText(
                    icon: Icons.person_outline_rounded,
                    text: 'Pemeriksa: ${condition.checkedByName}',
                  ),
                  _buildInfoText(
                    icon: condition.needsAttention
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    text: 'Temuan: ${_getFindingsText(item)}',
                  ),
                  if (condition.notes.trim().isNotEmpty)
                    _buildInfoText(
                      icon: Icons.notes_outlined,
                      text: 'Catatan: ${condition.notes.trim()}',
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: Colors.grey,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Belum ada batch aktif yang dapat ditampilkan.',
              style: TextStyle(
                fontSize: 12,
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
      child: CircularProgressIndicator(
        color: Color(0xFF038E1B),
      ),
    );
  }

  Widget _buildErrorState(
    Object? error,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.red.shade200,
            ),
          ),
          child: Text(
            'Gagal memuat laporan kondisi batch: $error',
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

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_double_arrow_left,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'LAPORAN KONDISI BATCH',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 1.0,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(context),
      body: StreamBuilder<List<BatchModel>>(
        stream: _batchRepository.getBatchesStream(),
        builder: (context, batchSnapshot) {
          if (batchSnapshot.connectionState == ConnectionState.waiting &&
              !batchSnapshot.hasData) {
            return _buildLoadingState();
          }

          if (batchSnapshot.hasError) {
            return _buildErrorState(
              batchSnapshot.error,
            );
          }

          final batches = batchSnapshot.data ?? [];

          return StreamBuilder<List<BatchConditionCheckModel>>(
            stream: _conditionRepository.getAllCurrentConditionsStream(),
            builder: (
              context,
              conditionSnapshot,
            ) {
              if (conditionSnapshot.connectionState ==
                      ConnectionState.waiting &&
                  !conditionSnapshot.hasData) {
                return _buildLoadingState();
              }

              if (conditionSnapshot.hasError) {
                return _buildErrorState(
                  conditionSnapshot.error,
                );
              }

              final conditions = conditionSnapshot.data ?? [];

              final items = _buildReportItems(
                batches: batches,
                conditions: conditions,
              );

              return SafeArea(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 620,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCard(
                            context: context,
                            items: items,
                          ),
                          const SizedBox(height: 24),
                          _buildSectionTitle(),
                          const SizedBox(height: 12),
                          if (items.isEmpty)
                            _buildEmptyState()
                          else
                            ...items.map(
                              _buildConditionCard,
                            ),
                          const SizedBox(height: 24),
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

class _BatchConditionReportItem {
  final BatchModel batch;
  final BatchConditionCheckModel? condition;

  const _BatchConditionReportItem({
    required this.batch,
    required this.condition,
  });
}
