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
              'Stok Masuk menunjukkan transaksi penambahan stok ke dalam sistem.',
            ),
            pw.Text(
              'Stok Keluar menunjukkan transaksi pengurangan stok berdasarkan batch.',
            ),
            pw.Text(
              'Selisih stok periode ini dihitung dari total stok masuk dikurangi total stok keluar.',
            ),
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
                Icons.receipt_long,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Riwayat Transaksi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Pantau transaksi stok masuk dan stok keluar berdasarkan produk serta periode tertentu.',
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

  Widget _buildFilterSection() {
    final selectedProductName = _getSelectedProductName();
    final selectedPeriodText = _getSelectedPeriodText();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Filter Transaksi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Gunakan filter untuk melihat transaksi berdasarkan produk/merk dan periode tertentu.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: _selectedProductId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Produk / Merk Beras',
                prefixIcon: Icon(Icons.rice_bowl_outlined),
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
                      child: Text(
                        product.name,
                        overflow: TextOverflow.ellipsis,
                      ),
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
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSmallInfoRow(
                    icon: Icons.inventory_2_outlined,
                    text: 'Produk dipilih: $selectedProductName',
                  ),
                  const SizedBox(height: 6),
                  _buildSmallInfoRow(
                    icon: Icons.calendar_month_outlined,
                    text: 'Periode dipilih: $selectedPeriodText',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallInfoRow({
    required IconData icon,
    required String text,
  }) {
    return Row(
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
              fontSize: 12.8,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(List<TransactionModel> transactions) {
    final totalStockIn = _calculateTotalStockIn(transactions);
    final totalStockOut = _calculateTotalStockOut(transactions);
    final netStock = totalStockIn - totalStockOut;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
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
            const SizedBox(height: 12),
            _buildSummaryRow(
              icon: Icons.receipt_long,
              label: 'Jumlah Transaksi',
              value: '${transactions.length}',
              color: Colors.blue,
            ),
            _buildSummaryRow(
              icon: Icons.arrow_downward,
              label: 'Total Stok Masuk',
              value: '$totalStockIn karung',
              color: Colors.green,
            ),
            _buildSummaryRow(
              icon: Icons.arrow_upward,
              label: 'Total Stok Keluar',
              value: '$totalStockOut karung',
              color: Colors.red,
            ),
            _buildSummaryRow(
              icon: Icons.compare_arrows,
              label: 'Selisih Periode',
              value: '$netStock karung',
              color: netStock >= 0 ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 8),
            const Text(
              'Catatan: ringkasan ini mengikuti filter produk dan periode yang dipilih.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12.5,
                height: 1.3,
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

  Widget _buildTransactionCard(TransactionModel transaction) {
    final transactionDate = transaction.createdAt.toDate();
    final color = _getTransactionColor(transaction.type);
    final typeText = _getTransactionTypeText(transaction.type);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.14),
              child: Icon(
                _getTransactionIcon(transaction.type),
                color: color,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildTypeChip(
                        text: typeText,
                        color: color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    transaction.productName,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTransactionInfo(
                    icon: Icons.calendar_month_outlined,
                    text: 'Tanggal: ${_formatDateTime(transactionDate)}',
                  ),
                  _buildTransactionInfo(
                    icon: Icons.qr_code_2,
                    text: 'Kode Batch: ${transaction.batchCode}',
                  ),
                  _buildTransactionInfo(
                    icon: Icons.inventory_2_outlined,
                    text: 'Jumlah: ${transaction.qty} ${transaction.unit}',
                  ),
                  _buildTransactionInfo(
                    icon: Icons.person_outline,
                    text: 'Dilakukan oleh: ${transaction.performedByName}',
                  ),
                  _buildTransactionInfo(
                    icon: Icons.notes_outlined,
                    text:
                        'Catatan: ${transaction.notes.isEmpty ? '-' : transaction.notes}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip({
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

  Widget _buildTransactionInfo({
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

  Widget _buildEmptyFilteredResult() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.search_off,
              color: Colors.orange,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tidak ada transaksi yang sesuai dengan filter yang dipilih.',
                style: TextStyle(
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

  Widget _buildEmptyTransactionResult() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.receipt_long,
              color: Colors.grey,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Belum ada riwayat transaksi.',
                style: TextStyle(
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

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
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
              'Gagal memuat riwayat transaksi: $error',
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

  Widget _buildTransactionList({
    required List<TransactionModel> allTransactions,
    required List<TransactionModel> filteredTransactions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Daftar Transaksi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Transaksi yang tampil mengikuti filter produk dan periode yang dipilih.',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 13,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        if (allTransactions.isEmpty)
          _buildEmptyTransactionResult()
        else if (filteredTransactions.isEmpty)
          _buildEmptyFilteredResult()
        else
          ...filteredTransactions.map(_buildTransactionCard),
      ],
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
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          final allTransactions = snapshot.data ?? [];
          final filteredTransactions = _filterTransactions(allTransactions);

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
                      _buildFilterSection(),
                      const SizedBox(height: 12),
                      _buildSummary(filteredTransactions),
                      const SizedBox(height: 12),
                      _buildGeneratePdfButton(filteredTransactions),
                      const SizedBox(height: 20),
                      _buildTransactionList(
                        allTransactions: allTransactions,
                        filteredTransactions: filteredTransactions,
                      ),
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
