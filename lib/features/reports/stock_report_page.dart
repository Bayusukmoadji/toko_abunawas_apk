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

  Widget _buildSummaryCard(List<ProductModel> products) {
    final totalProducts = products.length;

    final totalSacks = products.fold<int>(
      0,
      (total, product) => total + product.totalStock,
    );

    final totalKg = totalSacks * sackWeightKg;

    final lowStockCount = products.where((product) {
      return product.totalStock > 0 &&
          product.totalStock <= product.minimumStock;
    }).length;

    final emptyStockCount = products.where((product) {
      return product.totalStock <= 0;
    }).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Stok Tersisa',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Jumlah produk aktif: $totalProducts'),
            Text('Total stok: $totalSacks karung'),
            Text('Estimasi total berat: $totalKg kg'),
            Text('Produk stok menipis: $lowStockCount'),
            Text('Produk stok habis: $emptyStockCount'),
            const SizedBox(height: 8),
            const Text(
              'Catatan: setiap karung diasumsikan berisi 50 kg beras.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductStockCard(ProductModel product) {
    final status = _getStockStatus(product);
    final statusColor = _getStockStatusColor(product);
    final totalKg = product.totalStock * sackWeightKg;

    return Card(
      color: statusColor.withOpacity(0.08),
      child: ListTile(
        leading: Icon(
          _getStockStatusIcon(product),
          color: statusColor,
        ),
        title: Text(
          product.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kode produk: ${product.code}'),
              Text('Kategori: ${product.category}'),
              Text('Stok saat ini: ${product.totalStock} ${product.unit}'),
              Text('Minimum stok: ${product.minimumStock} ${product.unit}'),
              Text('Estimasi berat: $totalKg kg'),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _buildStockReportPdf(List<ProductModel> products) async {
    final pdf = pw.Document();
    final sortedProducts = _sortProducts(products);

    final now = DateTime.now();

    final totalProducts = sortedProducts.length;

    final totalSacks = sortedProducts.fold<int>(
      0,
      (total, product) => total + product.totalStock,
    );

    final totalKg = totalSacks * sackWeightKg;

    final lowStockCount = sortedProducts.where((product) {
      return product.totalStock > 0 &&
          product.totalStock <= product.minimumStock;
    }).length;

    final emptyStockCount = sortedProducts.where((product) {
      return product.totalStock <= 0;
    }).length;

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
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Gagal memuat data stok: ${snapshot.error}'),
            );
          }

          final products = snapshot.data ?? [];

          if (products.isEmpty) {
            return const Center(
              child: Text('Belum ada data produk.'),
            );
          }

          final sortedProducts = _sortProducts(products);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryCard(sortedProducts),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _generatePdf(
                            context: context,
                            products: sortedProducts,
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Generate PDF Laporan'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Daftar Stok Produk',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...sortedProducts.map(_buildProductStockCard),
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
