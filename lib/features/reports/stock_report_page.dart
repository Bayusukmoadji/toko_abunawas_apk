import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository.dart';

class StockReportPage extends StatelessWidget {
  StockReportPage({super.key});

  final ProductRepository _productRepository = ProductRepository();

  static const int sackWeightKg = 50;

  String _getStockStatus(ProductModel product) {
    if (product.totalStock <= 0) {
      return 'Habis';
    }

    if (product.totalStock <= product.minimumStock) {
      return 'Menipis';
    }

    return 'Aman';
  }

  Color _getStockStatusColor(ProductModel product) {
    final status = _getStockStatus(product);

    if (status == 'Habis') {
      return Colors.red;
    }

    if (status == 'Menipis') {
      return Colors.orange;
    }

    return Colors.green;
  }

  IconData _getStockStatusIcon(ProductModel product) {
    final status = _getStockStatus(product);

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

  List<ProductModel> _sortProducts(List<ProductModel> products) {
    final sortedProducts = [...products];

    sortedProducts.sort((a, b) {
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

      return a.name.compareTo(b.name);
    });

    return sortedProducts;
  }

  int _getTotalSacks(List<ProductModel> products) {
    return products.fold<int>(
      0,
      (total, product) => total + product.totalStock,
    );
  }

  int _getLowStockCount(List<ProductModel> products) {
    return products.where((product) {
      return product.totalStock > 0 &&
          product.totalStock <= product.minimumStock;
    }).length;
  }

  int _getEmptyStockCount(List<ProductModel> products) {
    return products.where((product) {
      return product.totalStock <= 0;
    }).length;
  }

  Future<Uint8List> _buildStockReportPdf(List<ProductModel> products) async {
    final pdf = pw.Document();
    final sortedProducts = _sortProducts(products);

    final now = DateTime.now();

    final totalProducts = sortedProducts.length;
    final totalSacks = _getTotalSacks(sortedProducts);
    final totalKg = totalSacks * sackWeightKg;
    final lowStockCount = _getLowStockCount(sortedProducts);
    final emptyStockCount = _getEmptyStockCount(sortedProducts);

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
                  pw.Text('Total stok: $totalSacks karung'),
                  pw.Text('Estimasi total berat: $totalKg kg'),
                  pw.Text('Produk stok menipis: $lowStockCount'),
                  pw.Text('Produk stok habis: $emptyStockCount'),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Catatan: setiap karung diasumsikan berisi 50 kg beras.',
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
              data: List.generate(sortedProducts.length, (index) {
                final product = sortedProducts[index];
                final status = _getStockStatus(product);
                final productTotalKg = product.totalStock * sackWeightKg;

                return [
                  '${index + 1}',
                  product.code,
                  product.name,
                  '${product.totalStock} ${product.unit}',
                  '${product.minimumStock} ${product.unit}',
                  '$productTotalKg kg',
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
            pw.Text('Aman: stok lebih besar dari minimum stok.'),
            pw.Text('Menipis: stok lebih kecil atau sama dengan minimum stok.'),
            pw.Text('Habis: stok sama dengan atau kurang dari 0.'),
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
    required List<ProductModel> products,
  }) async {
    if (products.isEmpty) {
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
        return _buildStockReportPdf(products);
      },
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
                Icons.assessment_outlined,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Laporan Stok Tersisa',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Pantau kondisi stok terbaru, status persediaan, dan estimasi berat beras dalam kilogram.',
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

  Widget _buildSummaryCard(List<ProductModel> products) {
    final totalProducts = products.length;
    final totalSacks = _getTotalSacks(products);
    final totalKg = totalSacks * sackWeightKg;
    final lowStockCount = _getLowStockCount(products);
    final emptyStockCount = _getEmptyStockCount(products);
    final safeStockCount = totalProducts - lowStockCount - emptyStockCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Stok',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              icon: Icons.inventory_2_outlined,
              label: 'Jumlah Produk Aktif',
              value: '$totalProducts',
              color: Colors.blue,
            ),
            _buildSummaryRow(
              icon: Icons.shopping_bag_outlined,
              label: 'Total Stok',
              value: '$totalSacks karung',
              color: Colors.green,
            ),
            _buildSummaryRow(
              icon: Icons.scale_outlined,
              label: 'Estimasi Total Berat',
              value: '$totalKg kg',
              color: Colors.teal,
            ),
            _buildSummaryRow(
              icon: Icons.check_circle_outline,
              label: 'Produk Aman',
              value: '$safeStockCount',
              color: Colors.green,
            ),
            _buildSummaryRow(
              icon: Icons.warning_amber_rounded,
              label: 'Produk Menipis',
              value: '$lowStockCount',
              color: Colors.orange,
            ),
            _buildSummaryRow(
              icon: Icons.cancel_outlined,
              label: 'Produk Habis',
              value: '$emptyStockCount',
              color: Colors.red,
            ),
            const SizedBox(height: 8),
            const Text(
              'Catatan: setiap karung diasumsikan berisi 50 kg beras. Laporan ini menampilkan kondisi stok terbaru saat halaman dibuka.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12.5,
                height: 1.35,
              ),
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

  Widget _buildGeneratePdfButton({
    required BuildContext context,
    required List<ProductModel> products,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () {
          _generatePdf(
            context: context,
            products: products,
          );
        },
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Generate PDF Laporan Stok'),
      ),
    );
  }

  Widget _buildProductStockCard(ProductModel product) {
    final status = _getStockStatus(product);
    final statusColor = _getStockStatusColor(product);
    final totalKg = product.totalStock * sackWeightKg;

    return Card(
      color: statusColor.withOpacity(0.07),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.14),
              child: Icon(
                _getStockStatusIcon(product),
                color: statusColor,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildStatusChip(
                    text: status,
                    color: statusColor,
                  ),
                  const SizedBox(height: 9),
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
                    text:
                        'Stok saat ini: ${product.totalStock} ${product.unit}',
                  ),
                  _buildInfoText(
                    icon: Icons.low_priority_outlined,
                    text:
                        'Minimum stok: ${product.minimumStock} ${product.unit}',
                  ),
                  _buildInfoText(
                    icon: Icons.scale_outlined,
                    text: 'Estimasi berat: $totalKg kg',
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
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.35),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
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
      padding: const EdgeInsets.only(top: 5),
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

  Widget _buildSectionTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daftar Stok Produk',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Produk diurutkan berdasarkan prioritas status: habis, menipis, lalu aman.',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.grey,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Belum ada data produk aktif.',
                    style: TextStyle(
                      color: Colors.black87,
                      height: 1.35,
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

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Gagal memuat data stok: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Stok Tersisa'),
      ),
      body: StreamBuilder<List<ProductModel>>(
        stream: _productRepository.getActiveProductsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          final products = snapshot.data ?? [];

          if (products.isEmpty) {
            return _buildEmptyState();
          }

          final sortedProducts = _sortProducts(products);

          return SafeArea(
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
                      _buildSummaryCard(sortedProducts),
                      const SizedBox(height: 12),
                      _buildGeneratePdfButton(
                        context: context,
                        products: sortedProducts,
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle(),
                      const SizedBox(height: 12),
                      ...sortedProducts.map(_buildProductStockCard),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
