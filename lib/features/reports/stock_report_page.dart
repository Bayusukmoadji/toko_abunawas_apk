import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/batch_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/batch_repository.dart';
import '../../data/repositories/product_repository.dart';

class StockReportPage extends StatelessWidget {
  StockReportPage({super.key});

  final ProductRepository _productRepository = ProductRepository();
  final BatchRepository _batchRepository = BatchRepository();

  static const int sackWeightKg = 50;

  final BoxShadow _softShadow = BoxShadow(
    color: Colors.black.withOpacity(0.07),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  Map<String, int> _getActualStockByProductId(List<BatchModel> batches) {
    final Map<String, int> stockMap = {};

    for (final batch in batches) {
      final status = batch.status.toLowerCase().trim();

      if (status != 'active') continue;
      if (batch.remainingQty <= 0) continue;

      stockMap[batch.productId] =
          (stockMap[batch.productId] ?? 0) + batch.remainingQty;
    }

    return stockMap;
  }

  List<_StockReportItem> _buildReportItems({
    required List<ProductModel> products,
    required List<BatchModel> batches,
  }) {
    final actualStockByProductId = _getActualStockByProductId(batches);

    final items = products.map((product) {
      return _StockReportItem(
        product: product,
        actualStock: actualStockByProductId[product.id] ?? 0,
      );
    }).toList();

    return _sortItems(items);
  }

  String _getStockStatus(_StockReportItem item) {
    if (item.actualStock <= 0) {
      return 'Habis';
    }

    if (item.actualStock <= item.product.minimumStock) {
      return 'Menipis';
    }

    return 'Aman';
  }

  Color _getStockStatusColor(_StockReportItem item) {
    final status = _getStockStatus(item);

    if (status == 'Habis') {
      return Colors.red.shade400;
    }

    if (status == 'Menipis') {
      return Colors.orange.shade500;
    }

    return Colors.green.shade600;
  }

  IconData _getStockStatusIcon(_StockReportItem item) {
    final status = _getStockStatus(item);

    if (status == 'Habis') {
      return Icons.cancel_outlined;
    }

    if (status == 'Menipis') {
      return Icons.warning_amber_rounded;
    }

    return Icons.check_circle_outline;
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  List<_StockReportItem> _sortItems(List<_StockReportItem> items) {
    final sortedItems = [...items];

    sortedItems.sort((a, b) {
      final statusA = _getStockStatus(a);
      final statusB = _getStockStatus(b);

      int priority(String status) {
        if (status == 'Habis') return 0;
        if (status == 'Menipis') return 1;
        return 2;
      }

      final statusCompare = priority(statusA).compareTo(priority(statusB));

      if (statusCompare != 0) {
        return statusCompare;
      }

      return a.product.name.compareTo(b.product.name);
    });

    return sortedItems;
  }

  int _getTotalSacks(List<_StockReportItem> items) {
    return items.fold<int>(
      0,
      (total, item) => total + item.actualStock,
    );
  }

  int _getLowStockCount(List<_StockReportItem> items) {
    return items.where((item) {
      return item.actualStock > 0 &&
          item.actualStock <= item.product.minimumStock;
    }).length;
  }

  int _getEmptyStockCount(List<_StockReportItem> items) {
    return items.where((item) {
      return item.actualStock <= 0;
    }).length;
  }

  Future<Uint8List> _buildStockReportPdf(
    List<_StockReportItem> items,
  ) async {
    final pdf = pw.Document();
    final sortedItems = _sortItems(items);

    final now = DateTime.now();

    final totalProducts = sortedItems.length;
    final totalSacks = _getTotalSacks(sortedItems);
    final totalKg = totalSacks * sackWeightKg;
    final lowStockCount = _getLowStockCount(sortedItems);
    final emptyStockCount = _getEmptyStockCount(sortedItems);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Text(
              'Laporan Stok Tersisa',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Toko Beras Abunawas'),
            pw.Text('Tanggal cetak: ${_formatDateTime(now)}'),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Ringkasan',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text('Jumlah produk aktif: $totalProducts'),
                  pw.Text('Total stok aktual: $totalSacks karung'),
                  pw.Text('Estimasi total berat: ${_formatNumber(totalKg)} kg'),
                  pw.Text('Produk stok menipis: $lowStockCount'),
                  pw.Text('Produk stok habis: $emptyStockCount'),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Catatan: stok aktual dihitung dari total sisa batch aktif. Setiap karung diasumsikan berisi 50 kg beras.',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Daftar Stok Produk',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: [
                'No',
                'Kode',
                'Produk',
                'Stok',
                'Minimum',
                'Berat',
                'Status',
              ],
              data: List.generate(sortedItems.length, (index) {
                final item = sortedItems[index];
                final product = item.product;
                final status = _getStockStatus(item);
                final productTotalKg = item.actualStock * sackWeightKg;

                return [
                  '${index + 1}',
                  product.code,
                  product.name,
                  '${item.actualStock} ${product.unit}',
                  '${product.minimumStock} ${product.unit}',
                  '${_formatNumber(productTotalKg)} kg',
                  status,
                ];
              }),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.green,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FixedColumnWidth(28),
                1: const pw.FixedColumnWidth(70),
                2: const pw.FlexColumnWidth(),
                3: const pw.FixedColumnWidth(60),
                4: const pw.FixedColumnWidth(60),
                5: const pw.FixedColumnWidth(60),
                6: const pw.FixedColumnWidth(55),
              },
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Keterangan Status:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Aman: stok aktual lebih besar dari minimum stok.'),
            pw.Text(
              'Menipis: stok aktual lebih kecil atau sama dengan minimum stok.',
            ),
            pw.Text('Habis: stok aktual sama dengan atau kurang dari 0.'),
            pw.SizedBox(height: 20),
            pw.Text(
              'Laporan ini dihasilkan secara otomatis oleh Aplikasi Manajemen Stok Toko Beras Abunawas.',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _generatePdf({
    required BuildContext context,
    required List<_StockReportItem> items,
  }) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada data produk untuk dibuat laporan.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await Printing.layoutPdf(
      name: 'laporan_stok_tersisa_abunawas.pdf',
      onLayout: (format) async {
        return _buildStockReportPdf(items);
      },
    );
  }

  Widget _buildCleanCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color color = Colors.white,
  }) {
    return Container(
      width: double.infinity,
      margin: margin,
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

  Widget _buildSummaryCard(
    BuildContext context,
    List<_StockReportItem> items,
  ) {
    final totalProducts = items.length;
    final totalSacks = _getTotalSacks(items);
    final totalKg = totalSacks * sackWeightKg;
    final lowStockCount = _getLowStockCount(items);
    final emptyStockCount = _getEmptyStockCount(items);
    final safeStockCount = totalProducts - lowStockCount - emptyStockCount;

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
        _buildCleanCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow(
                label: 'Jumlah Produk Aktif',
                value: '$totalProducts',
              ),
              _buildSummaryRow(
                label: 'Total Stok Aktual',
                value: '$totalSacks karung',
              ),
              _buildSummaryRow(
                label: 'Total Berat',
                value: '${_formatNumber(totalKg)} kg',
              ),
              _buildSummaryRow(
                label: 'Produk Aman',
                value: '$safeStockCount',
              ),
              _buildSummaryRow(
                label: 'Produk Menipis',
                value: '$lowStockCount',
              ),
              _buildSummaryRow(
                label: 'Produk Habis',
                value: '$emptyStockCount',
                isLast: true,
              ),
              const SizedBox(height: 10),
              const Text(
                'Catatan: stok aktual dihitung dari total sisa batch aktif. Setiap karung berisi 50kg beras.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 9.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: items.isEmpty ? 0.6 : 1.0,
                child: _buildPdfButton(
                  context: context,
                  items: items,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPdfButton({
    required BuildContext context,
    required List<_StockReportItem> items,
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
                  'Generate PDF Laporan Stok',
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

  Widget _buildSummaryRow({
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
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
                textAlign: TextAlign.right,
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

  Widget _buildProductStockCard(_StockReportItem item) {
    final product = item.product;
    final status = _getStockStatus(item);
    final statusColor = _getStockStatusColor(item);
    final totalKg = item.actualStock * sackWeightKg;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.18),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: statusColor.withOpacity(0.15),
                  child: Icon(
                    _getStockStatusIcon(item),
                    size: 17,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _buildStatusChip(
                    text: status,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoText(
                    icon: Icons.qr_code_2,
                    text: 'Kode produk: ${product.code}',
                  ),
                  _buildInfoText(
                    icon: Icons.category_outlined,
                    text: 'Kategori: ${product.category}',
                  ),
                  _buildInfoText(
                    icon: Icons.inventory_2_outlined,
                    text: 'Stok aktual: ${item.actualStock} ${product.unit}',
                  ),
                  _buildInfoText(
                    icon: Icons.low_priority_outlined,
                    text:
                        'Minimum stok: ${product.minimumStock} ${product.unit}',
                  ),
                  _buildInfoText(
                    icon: Icons.scale_outlined,
                    text: 'Berat: ${_formatNumber(totalKg)} kg',
                  ),
                ],
              ),
            ),
          ],
        ),
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
          fontSize: 10.5,
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
                height: 1.25,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daftar Stok Produk',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Produk diurutkan berdasarkan prioritas status: habis, menipis, lalu aman.',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 11,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
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
              'Belum ada data produk aktif.',
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

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Text(
            'Gagal memuat data stok: $error',
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

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.green),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60.0),
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
          'LAPORAN STOK',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(context),
      body: StreamBuilder<List<ProductModel>>(
        stream: _productRepository.getActiveProductsStream(),
        builder: (context, productSnapshot) {
          return StreamBuilder<List<BatchModel>>(
            stream: _batchRepository.getBatchesStream(),
            builder: (context, batchSnapshot) {
              final isLoading =
                  productSnapshot.connectionState == ConnectionState.waiting ||
                      batchSnapshot.connectionState == ConnectionState.waiting;

              if (isLoading) {
                return _buildLoadingState();
              }

              if (productSnapshot.hasError) {
                return _buildErrorState(productSnapshot.error);
              }

              if (batchSnapshot.hasError) {
                return _buildErrorState(batchSnapshot.error);
              }

              final products = productSnapshot.data ?? [];
              final batches = batchSnapshot.data ?? [];

              final reportItems = _buildReportItems(
                products: products,
                batches: batches,
              );

              return SafeArea(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  physics: const ClampingScrollPhysics(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
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
                          horizontal: 16,
                          vertical: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryCard(context, reportItems),
                            const SizedBox(height: 24),
                            _buildSectionTitle(),
                            const SizedBox(height: 12),
                            if (reportItems.isEmpty)
                              _buildEmptyState()
                            else
                              ...reportItems.map(_buildProductStockCard),
                            const SizedBox(height: 12),
                          ],
                        ),
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

class _StockReportItem {
  final ProductModel product;
  final int actualStock;

  const _StockReportItem({
    required this.product,
    required this.actualStock,
  });
}
