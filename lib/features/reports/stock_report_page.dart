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
      return Colors.red.shade400;
    }

    if (status == 'Menipis') {
      return Colors.orange.shade500;
    }

    return Colors.green.shade600;
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

  // Fungsi untuk memformat angka dengan pemisah ribuan (misal: 4250 -> 4.250)
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
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
                  pw.Text('Estimasi total berat: ${_formatNumber(totalKg)} kg'),
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

  Widget _buildSummaryCard(BuildContext context, List<ProductModel> products) {
    final totalProducts = products.length;
    final totalSacks = _getTotalSacks(products);
    final totalKg = totalSacks * sackWeightKg;
    final lowStockCount = _getLowStockCount(products);
    final emptyStockCount = _getEmptyStockCount(products);
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/batch/cardsum.png'),
              fit: BoxFit.fill,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow(
                  label: 'Jumlah Produk Aktif', value: '$totalProducts'),
              _buildSummaryRow(
                  label: 'Total Stok', value: '$totalSacks karung'),
              _buildSummaryRow(
                  label: 'Total Berat', value: '${_formatNumber(totalKg)} kg'),
              _buildSummaryRow(label: 'Produk Aman', value: '$safeStockCount'),
              _buildSummaryRow(
                  label: 'Produk Menipis', value: '$lowStockCount'),
              _buildSummaryRow(
                  label: 'Produk Habis',
                  value: '$emptyStockCount',
                  isLast: true),

              const SizedBox(height: 10),
              const Text(
                'Catatan: Setiap karung berisi 50kg beras. Laporan ini menampilkan kondisi stok terbaru saat halaman dibuka.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 9.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),

              // Tombol PDF (Menggunakan botpdf.png)
              Center(
                child: Opacity(
                  opacity: products.isEmpty ? 0.6 : 1.0,
                  child: Container(
                    width: double.infinity,
                    height: 42,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/transaction/botpdf.png'),
                        fit: BoxFit.fill,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: products.isEmpty
                            ? null
                            : () {
                                _generatePdf(
                                  context: context,
                                  products: products,
                                );
                              },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.picture_as_pdf_rounded,
                                size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Generate PDF Laporan Stok',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
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
            color: Colors.black38,
            thickness: 0.5,
            height: 8,
          ),
      ],
    );
  }

  Widget _buildProductStockCard(ProductModel product) {
    final status = _getStockStatus(product);
    final statusColor = _getStockStatusColor(product);
    final totalKg = product.totalStock * sackWeightKg;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(minHeight: 110),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/batch/cardbatch.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: statusColor.withOpacity(0.15),
                  child: Icon(
                    _getStockStatusIcon(product),
                    size: 16,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 42),
                Expanded(
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
                        text: 'Berat: ${_formatNumber(totalKg)} kg',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(text: status, color: statusColor),
              ],
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
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.4),
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
      padding: const EdgeInsets.only(top: 3),
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
                fontSize: 10.0,
                color: Colors.black54,
                height: 1.2,
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
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
            borderRadius: BorderRadius.circular(12),
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

          final sortedProducts =
              products.isNotEmpty ? _sortProducts(products) : <ProductModel>[];

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCard(context, sortedProducts),
                    const SizedBox(height: 24),
                    _buildSectionTitle(),
                    const SizedBox(height: 12),
                    if (sortedProducts.isEmpty)
                      _buildEmptyState()
                    else
                      ...sortedProducts.map(_buildProductStockCard),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
