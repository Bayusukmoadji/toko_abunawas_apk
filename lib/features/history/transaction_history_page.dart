import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/product_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final TransactionRepository _transactionRepository = TransactionRepository();
  final ProductRepository _productRepository = ProductRepository();

  static const String _allProductsValue = 'all';

  List<ProductModel> _products = [];
  String _selectedProductId = _allProductsValue;
  DateTimeRange? _selectedDateRange;

  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _productRepository.getActiveProducts();

      if (!mounted) return;

      setState(() {
        _products = products;
        _isLoadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingProducts = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat produk: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();

    return '$day/$month/$year';
  }

  String _getTransactionTypeText(String type) {
    if (type == 'stock_in') {
      return 'Stok Masuk';
    }

    if (type == 'stock_out') {
      return 'Stok Keluar';
    }

    return type;
  }

  Color _getTransactionColor(String type) {
    if (type == 'stock_in') {
      return Colors.green;
    }

    if (type == 'stock_out') {
      return Colors.red;
    }

    return Colors.grey;
  }

  IconData _getTransactionIcon(String type) {
    if (type == 'stock_in') {
      return Icons.arrow_downward;
    }

    if (type == 'stock_out') {
      return Icons.arrow_upward;
    }

    return Icons.receipt_long;
  }

  String _getSelectedProductName() {
    if (_selectedProductId == _allProductsValue) {
      return 'Semua Produk';
    }

    final matchedProducts = _products.where(
      (product) => product.id == _selectedProductId,
    );

    if (matchedProducts.isEmpty) {
      return 'Produk tidak ditemukan';
    }

    return matchedProducts.first.name;
  }

  String _getSelectedPeriodText() {
    if (_selectedDateRange == null) {
      return 'Semua Periode';
    }

    return '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}';
  }

  List<TransactionModel> _filterTransactions(
    List<TransactionModel> transactions,
  ) {
    return transactions.where((transaction) {
      final transactionDate = transaction.createdAt.toDate();

      final matchProduct = _selectedProductId == _allProductsValue ||
          transaction.productId == _selectedProductId;

      bool matchDate = true;

      if (_selectedDateRange != null) {
        final start = DateTime(
          _selectedDateRange!.start.year,
          _selectedDateRange!.start.month,
          _selectedDateRange!.start.day,
        );

        final end = DateTime(
          _selectedDateRange!.end.year,
          _selectedDateRange!.end.month,
          _selectedDateRange!.end.day,
          23,
          59,
          59,
        );

        matchDate = transactionDate
                .isAfter(start.subtract(const Duration(seconds: 1))) &&
            transactionDate.isBefore(end.add(const Duration(seconds: 1)));
      }

      return matchProduct && matchDate;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _resetFilter() {
    setState(() {
      _selectedProductId = _allProductsValue;
      _selectedDateRange = null;
    });
  }

  int _calculateTotalStockIn(List<TransactionModel> transactions) {
    return transactions
        .where((transaction) => transaction.type == 'stock_in')
        .fold<int>(0, (total, transaction) => total + transaction.qty);
  }

  int _calculateTotalStockOut(List<TransactionModel> transactions) {
    return transactions
        .where((transaction) => transaction.type == 'stock_out')
        .fold<int>(0, (total, transaction) => total + transaction.qty);
  }

  String _shortenText(String text, {int maxLength = 25}) {
    if (text.length <= maxLength) {
      return text;
    }

    return '${text.substring(0, maxLength)}...';
  }

  Future<Uint8List> _buildTransactionReportPdf(
    List<TransactionModel> transactions,
  ) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    final totalStockIn = _calculateTotalStockIn(transactions);
    final totalStockOut = _calculateTotalStockOut(transactions);
    final netStock = totalStockIn - totalStockOut;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Text(
              'Laporan Transaksi Stok',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Toko Beras Abunawas'),
            pw.Text('Tanggal cetak: ${_formatDateTime(now)}'),
            pw.SizedBox(height: 12),
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
                    'Filter Laporan',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text('Produk/Merk: ${_getSelectedProductName()}'),
                  pw.Text('Periode: ${_getSelectedPeriodText()}'),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
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
                    'Ringkasan Transaksi',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text('Jumlah transaksi: ${transactions.length}'),
                  pw.Text('Total stok masuk: $totalStockIn karung'),
                  pw.Text('Total stok keluar: $totalStockOut karung'),
                  pw.Text('Selisih stok periode ini: $netStock karung'),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Catatan: ringkasan ini mengikuti filter produk dan periode yang dipilih.',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Daftar Transaksi',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: [
                'No',
                'Tanggal',
                'Jenis',
                'Produk',
                'Batch',
                'Jumlah',
                'User',
              ],
              data: List.generate(transactions.length, (index) {
                final transaction = transactions[index];
                final transactionDate = transaction.createdAt.toDate();

                return [
                  '${index + 1}',
                  _formatDateTime(transactionDate),
                  _getTransactionTypeText(transaction.type),
                  _shortenText(transaction.productName, maxLength: 22),
                  transaction.batchCode,
                  '${transaction.qty} ${transaction.unit}',
                  _shortenText(transaction.performedByName, maxLength: 14),
                ];
              }),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 8,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.green,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 7,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              headerHeight: 24,
              cellHeight: 24,
              cellPadding: const pw.EdgeInsets.all(3),
              tableWidth: pw.TableWidth.max,
              columnWidths: {
                0: const pw.FixedColumnWidth(25),
                1: const pw.FixedColumnWidth(70),
                2: const pw.FixedColumnWidth(58),
                3: const pw.FixedColumnWidth(120),
                4: const pw.FixedColumnWidth(58),
                5: const pw.FixedColumnWidth(55),
                6: const pw.FixedColumnWidth(70),
              },
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.centerLeft,
                6: pw.Alignment.centerLeft,
              },
            ),
            if (transactions
                .any((transaction) => transaction.notes.trim().isNotEmpty)) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                'Catatan Transaksi:',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              ...transactions.asMap().entries.where((entry) {
                return entry.value.notes.trim().isNotEmpty;
              }).map((entry) {
                final index = entry.key;
                final transaction = entry.value;

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Text(
                    '${index + 1}. ${transaction.batchCode} - ${transaction.notes}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                );
              }),
            ],
            pw.SizedBox(height: 16),
            pw.Text(
              'Keterangan:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
                'Stok Masuk menunjukkan transaksi penambahan stok ke dalam sistem.'),
            pw.Text(
                'Stok Keluar menunjukkan transaksi pengurangan stok berdasarkan batch.'),
            pw.Text(
                'Selisih stok periode ini dihitung dari total stok masuk dikurangi total stok keluar.'),
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

  Future<void> _generateTransactionPdf({
    required BuildContext context,
    required List<TransactionModel> transactions,
  }) async {
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Tidak ada transaksi yang sesuai dengan filter laporan.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await Printing.layoutPdf(
      name: 'laporan_transaksi_stok_abunawas.pdf',
      onLayout: (format) async {
        return _buildTransactionReportPdf(transactions);
      },
    );
  }

  Widget _buildFilterSection() {
    final selectedProductName = _getSelectedProductName();
    final selectedPeriodText = _getSelectedPeriodText();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Filter Laporan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedProductId,
              decoration: const InputDecoration(
                labelText: 'Filter Produk / Merk Beras',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: _allProductsValue,
                  child: Text('Semua Produk'),
                ),
                ..._products.map(
                  (product) {
                    return DropdownMenuItem<String>(
                      value: product.id,
                      child: Text(product.name),
                    );
                  },
                ),
              ],
              onChanged: _isLoadingProducts
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _selectedProductId = value;
                      });
                    },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.date_range),
              label: Text(selectedPeriodText),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _resetFilter,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset Filter'),
            ),
            const SizedBox(height: 12),
            Text('Produk dipilih: $selectedProductName'),
            Text('Periode dipilih: $selectedPeriodText'),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction) {
    final transactionDate = transaction.createdAt.toDate();
    final color = _getTransactionColor(transaction.type);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(
            _getTransactionIcon(transaction.type),
            color: color,
          ),
        ),
        title: Text(
          '${_getTransactionTypeText(transaction.type)} - ${transaction.productName}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tanggal: ${_formatDateTime(transactionDate)}'),
              Text('Kode Batch: ${transaction.batchCode}'),
              Text('Jumlah: ${transaction.qty} ${transaction.unit}'),
              Text('Dilakukan oleh: ${transaction.performedByName}'),
              Text(
                'Catatan: ${transaction.notes.isEmpty ? '-' : transaction.notes}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(List<TransactionModel> transactions) {
    final totalStockIn = _calculateTotalStockIn(transactions);
    final totalStockOut = _calculateTotalStockOut(transactions);
    final netStock = totalStockIn - totalStockOut;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Transaksi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Jumlah transaksi: ${transactions.length}'),
            Text('Total stok masuk: $totalStockIn karung'),
            Text('Total stok keluar: $totalStockOut karung'),
            Text('Selisih stok periode ini: $netStock karung'),
            const SizedBox(height: 8),
            const Text(
              'Catatan: ringkasan ini mengikuti filter produk dan periode yang dipilih.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFilteredResult() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Tidak ada transaksi yang sesuai dengan filter yang dipilih.',
        ),
      ),
    );
  }

  Widget _buildGeneratePdfButton(List<TransactionModel> filteredTransactions) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: filteredTransactions.isEmpty
            ? null
            : () {
                _generateTransactionPdf(
                  context: context,
                  transactions: filteredTransactions,
                );
              },
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Generate PDF Laporan Transaksi'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _transactionRepository.getTransactionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              _isLoadingProducts) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Gagal memuat riwayat transaksi: ${snapshot.error}'),
            );
          }

          final allTransactions = snapshot.data ?? [];
          final filteredTransactions = _filterTransactions(allTransactions);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFilterSection(),
                    const SizedBox(height: 16),
                    _buildSummary(filteredTransactions),
                    const SizedBox(height: 12),
                    _buildGeneratePdfButton(filteredTransactions),
                    const SizedBox(height: 20),
                    const Text(
                      'Daftar Transaksi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (allTransactions.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Belum ada riwayat transaksi.'),
                        ),
                      )
                    else if (filteredTransactions.isEmpty)
                      _buildEmptyFilteredResult()
                    else
                      ...filteredTransactions.map(_buildTransactionCard),
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
