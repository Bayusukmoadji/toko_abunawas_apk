import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/product_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/transaction_repository.dart';

enum _TransactionTypeFilter {
  all,
  stockIn,
  stockOut,
}

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final TransactionRepository _transactionRepository = TransactionRepository();
  final ProductRepository _productRepository = ProductRepository();

  static const String _allProductsValue = 'all';

  final ValueNotifier<String> _selectedProductIdNotifier =
      ValueNotifier<String>(_allProductsValue);
  final ValueNotifier<DateTimeRange?> _selectedDateRangeNotifier =
      ValueNotifier<DateTimeRange?>(null);
  final ValueNotifier<_TransactionTypeFilter> _selectedTypeFilterNotifier =
      ValueNotifier<_TransactionTypeFilter>(_TransactionTypeFilter.all);

  List<ProductModel> _products = [];
  bool _isLoadingProducts = true;

  final BoxShadow _softShadow = BoxShadow(
    color: Colors.black.withOpacity(0.07),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _selectedProductIdNotifier.dispose();
    _selectedDateRangeNotifier.dispose();
    _selectedTypeFilterNotifier.dispose();
    super.dispose();
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

  bool _isStockIn(TransactionModel transaction) {
    return transaction.type.toLowerCase().trim() == 'stock_in';
  }

  bool _isStockOut(TransactionModel transaction) {
    return transaction.type.toLowerCase().trim() == 'stock_out';
  }

  String _getTransactionTypeText(String type) {
    final normalizedType = type.toLowerCase().trim();

    if (normalizedType == 'stock_in') {
      return 'Stok Masuk';
    }

    if (normalizedType == 'stock_out') {
      return 'Stok Keluar';
    }

    return type;
  }

  Color _getTransactionColor(String type) {
    final normalizedType = type.toLowerCase().trim();

    if (normalizedType == 'stock_in') {
      return Colors.green.shade600;
    }

    if (normalizedType == 'stock_out') {
      return Colors.red.shade400;
    }

    return Colors.grey;
  }

  IconData _getTransactionIcon(String type) {
    final normalizedType = type.toLowerCase().trim();

    if (normalizedType == 'stock_in') {
      return Icons.call_received_rounded;
    }

    if (normalizedType == 'stock_out') {
      return Icons.call_made_rounded;
    }

    return Icons.receipt_long;
  }

  String _getSelectedProductName({String? selectedProductId}) {
    final currentProductId =
        selectedProductId ?? _selectedProductIdNotifier.value;

    if (currentProductId == _allProductsValue) {
      return 'Semua Produk';
    }

    final matchedProducts = _products.where(
      (product) => product.id == currentProductId,
    );

    if (matchedProducts.isEmpty) {
      return 'Produk tidak ditemukan';
    }

    return matchedProducts.first.name;
  }

  String _getSelectedPeriodText({DateTimeRange? selectedDateRange}) {
    final currentDateRange =
        selectedDateRange ?? _selectedDateRangeNotifier.value;

    if (currentDateRange == null) {
      return 'Semua Periode';
    }

    return '${_formatDate(currentDateRange.start)} - ${_formatDate(currentDateRange.end)}';
  }

  String _getSelectedTypeText({
    _TransactionTypeFilter? selectedTypeFilter,
  }) {
    final currentTypeFilter =
        selectedTypeFilter ?? _selectedTypeFilterNotifier.value;

    switch (currentTypeFilter) {
      case _TransactionTypeFilter.all:
        return 'Semua Transaksi';
      case _TransactionTypeFilter.stockIn:
        return 'Stok Masuk';
      case _TransactionTypeFilter.stockOut:
        return 'Stok Keluar';
    }
  }

  List<TransactionModel> _filterTransactions({
    required List<TransactionModel> transactions,
    required String selectedProductId,
    required DateTimeRange? selectedDateRange,
    required _TransactionTypeFilter selectedTypeFilter,
  }) {
    final filteredTransactions = transactions.where((transaction) {
      final transactionDate = transaction.createdAt.toDate();

      final matchProduct = selectedProductId == _allProductsValue ||
          transaction.productId == selectedProductId;

      bool matchDate = true;

      if (selectedDateRange != null) {
        final start = DateTime(
          selectedDateRange.start.year,
          selectedDateRange.start.month,
          selectedDateRange.start.day,
        );

        final end = DateTime(
          selectedDateRange.end.year,
          selectedDateRange.end.month,
          selectedDateRange.end.day,
          23,
          59,
          59,
        );

        matchDate = transactionDate
                .isAfter(start.subtract(const Duration(seconds: 1))) &&
            transactionDate.isBefore(end.add(const Duration(seconds: 1)));
      }

      bool matchType = true;

      if (selectedTypeFilter == _TransactionTypeFilter.stockIn) {
        matchType = _isStockIn(transaction);
      } else if (selectedTypeFilter == _TransactionTypeFilter.stockOut) {
        matchType = _isStockOut(transaction);
      }

      return matchProduct && matchDate && matchType;
    }).toList();

    filteredTransactions.sort(
      (a, b) => b.createdAt.toDate().compareTo(a.createdAt.toDate()),
    );

    return filteredTransactions;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final currentDateRange = _selectedDateRangeNotifier.value;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      initialDateRange: currentDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF038E1B),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _selectedDateRangeNotifier.value = picked;
    }
  }

  void _resetFilter() {
    _selectedProductIdNotifier.value = _allProductsValue;
    _selectedDateRangeNotifier.value = null;
    _selectedTypeFilterNotifier.value = _TransactionTypeFilter.all;
  }

  int _calculateTotalStockIn(List<TransactionModel> transactions) {
    return transactions
        .where(_isStockIn)
        .fold<int>(0, (total, transaction) => total + transaction.qty);
  }

  int _calculateTotalStockOut(List<TransactionModel> transactions) {
    return transactions
        .where(_isStockOut)
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

    final selectedProductId = _selectedProductIdNotifier.value;
    final selectedDateRange = _selectedDateRangeNotifier.value;
    final selectedTypeFilter = _selectedTypeFilterNotifier.value;

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
                  pw.Text(
                    'Produk/Merk: ${_getSelectedProductName(selectedProductId: selectedProductId)}',
                  ),
                  pw.Text(
                    'Jenis Transaksi: ${_getSelectedTypeText(selectedTypeFilter: selectedTypeFilter)}',
                  ),
                  pw.Text(
                    'Periode: ${_getSelectedPeriodText(selectedDateRange: selectedDateRange)}',
                  ),
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
                    'Catatan: ringkasan ini mengikuti filter produk, jenis transaksi, dan periode yang dipilih.',
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

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChip({
    required String label,
    required IconData icon,
    required _TransactionTypeFilter filter,
    required _TransactionTypeFilter selectedTypeFilter,
  }) {
    final isSelected = selectedTypeFilter == filter;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (_selectedTypeFilterNotifier.value == filter) return;
          _selectedTypeFilterNotifier.value = filter;
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [
                      Color(0xFF015816),
                      Color(0xFF038E1B),
                      Color(0xFF84E977),
                    ],
                    stops: [0.0, 0.55, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF038E1B)
                  : const Color(0xFFDADADA),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.black54,
                size: 15,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection({
    required String selectedProductId,
    required DateTimeRange? selectedDateRange,
    required _TransactionTypeFilter selectedTypeFilter,
  }) {
    final selectedPeriodText =
        _getSelectedPeriodText(selectedDateRange: selectedDateRange);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Filter Transaksi',
          subtitle:
              'Gunakan filter untuk melihat transaksi berdasarkan produk, jenis transaksi, dan periode tertentu.',
        ),
        _buildCleanCard(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: selectedProductId,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                decoration: InputDecoration(
                  labelText: 'Produk / Merk Beras',
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F8F8),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF038E1B)),
                  ),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: _allProductsValue,
                    child: Text(
                      'Semua Produk',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  ..._products.map((product) {
                    return DropdownMenuItem<String>(
                      value: product.id,
                      child: Text(
                        product.name,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: _isLoadingProducts
                    ? null
                    : (value) {
                        if (value == null) return;
                        _selectedProductIdNotifier.value = value;
                      },
              ),
              const SizedBox(height: 14),
              const Text(
                'Jenis Transaksi',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  _buildTypeFilterChip(
                    label: 'Semua',
                    icon: Icons.all_inclusive,
                    filter: _TransactionTypeFilter.all,
                    selectedTypeFilter: selectedTypeFilter,
                  ),
                  const SizedBox(width: 8),
                  _buildTypeFilterChip(
                    label: 'Masuk',
                    icon: Icons.call_received_rounded,
                    filter: _TransactionTypeFilter.stockIn,
                    selectedTypeFilter: selectedTypeFilter,
                  ),
                  const SizedBox(width: 8),
                  _buildTypeFilterChip(
                    label: 'Keluar',
                    icon: Icons.call_made_rounded,
                    filter: _TransactionTypeFilter.stockOut,
                    selectedTypeFilter: selectedTypeFilter,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: selectedPeriodText == 'Semua Periode'
                          ? selectedPeriodText
                          : 'Ubah Periode',
                      icon: Icons.calendar_month,
                      onTap: _pickDateRange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      label: 'Reset Filter',
                      icon: Icons.refresh,
                      onTap: _resetFilter,
                    ),
                  ),
                ],
              ),
              if (selectedDateRange != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Periode aktif: $selectedPeriodText',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 42,
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  Widget _buildSummary(List<TransactionModel> transactions) {
    final totalStockIn = _calculateTotalStockIn(transactions);
    final totalStockOut = _calculateTotalStockOut(transactions);
    final netStock = totalStockIn - totalStockOut;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Ringkasan Transaksi',
          subtitle:
              'Ringkasan ini mengikuti filter produk, jenis transaksi, dan periode yang dipilih.',
        ),
        _buildCleanCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow(
                label: 'Jumlah Transaksi',
                value: '${transactions.length}',
              ),
              _buildSummaryRow(
                label: 'Total Stok Masuk',
                value: '$totalStockIn Karung',
              ),
              _buildSummaryRow(
                label: 'Total Stok Keluar',
                value: '$totalStockOut Karung',
              ),
              _buildSummaryRow(
                label: 'Selisih Periode',
                value: '$netStock Karung',
                isLast: true,
              ),
              const SizedBox(height: 8),
              const Text(
                'Catatan: ringkasan ini mengikuti filter produk, jenis transaksi, dan periode yang dipilih.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 9.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: transactions.isEmpty ? 0.6 : 1.0,
                child: _buildPdfButton(transactions),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPdfButton(List<TransactionModel> transactions) {
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
          onTap: transactions.isEmpty
              ? null
              : () {
                  _generateTransactionPdf(
                    context: context,
                    transactions: transactions,
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
                  'Generate PDF Laporan Transaksi',
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

  Widget _buildTransactionInfo({
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

  Widget _buildTransactionCard(TransactionModel transaction) {
    final transactionDate = transaction.createdAt.toDate();
    final color = _getTransactionColor(transaction.type);
    final typeText = _getTransactionTypeText(transaction.type);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.18),
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
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(
                    _getTransactionIcon(transaction.type),
                    size: 17,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      transaction.productName,
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
                  child: _buildStatusChip(text: typeText, color: color),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTransactionInfo(
                    icon: Icons.calendar_today_outlined,
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
                  if (transaction.notes.trim().isNotEmpty)
                    _buildTransactionInfo(
                      icon: Icons.notes_outlined,
                      text: 'Catatan: ${transaction.notes}',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFilteredResult() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.search_off,
            color: Colors.orange.shade600,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tidak ada transaksi yang sesuai dengan filter yang dipilih.',
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

  Widget _buildEmptyTransactionResult() {
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
            Icons.receipt_long,
            color: Colors.grey,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Belum ada riwayat transaksi.',
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
      child: CircularProgressIndicator(color: Colors.green),
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
            'Gagal memuat riwayat transaksi: $error',
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

  Widget _buildTransactionList({
    required List<TransactionModel> allTransactions,
    required List<TransactionModel> filteredTransactions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Daftar Transaksi',
          subtitle:
              'Transaksi yang tampil mengikuti filter produk, jenis transaksi, dan periode yang dipilih.',
        ),
        if (allTransactions.isEmpty)
          _buildEmptyTransactionResult()
        else if (filteredTransactions.isEmpty)
          _buildEmptyFilteredResult()
        else
          ...filteredTransactions.map(_buildTransactionCard),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
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
          'RIWAYAT TRANSAKSI',
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

  Widget _buildPageContent({
    required List<TransactionModel> allTransactions,
    required String selectedProductId,
    required DateTimeRange? selectedDateRange,
    required _TransactionTypeFilter selectedTypeFilter,
  }) {
    final filteredTransactions = _filterTransactions(
      transactions: allTransactions,
      selectedProductId: selectedProductId,
      selectedDateRange: selectedDateRange,
      selectedTypeFilter: selectedTypeFilter,
    );

    return SafeArea(
      child: SingleChildScrollView(
        key: const PageStorageKey<String>('transaction_history_scroll'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                  _buildFilterSection(
                    selectedProductId: selectedProductId,
                    selectedDateRange: selectedDateRange,
                    selectedTypeFilter: selectedTypeFilter,
                  ),
                  const SizedBox(height: 24),
                  _buildSummary(filteredTransactions),
                  const SizedBox(height: 24),
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
      ),
    );
  }

  Widget _buildFilteredContent(List<TransactionModel> allTransactions) {
    return ValueListenableBuilder<String>(
      valueListenable: _selectedProductIdNotifier,
      builder: (context, selectedProductId, _) {
        return ValueListenableBuilder<DateTimeRange?>(
          valueListenable: _selectedDateRangeNotifier,
          builder: (context, selectedDateRange, _) {
            return ValueListenableBuilder<_TransactionTypeFilter>(
              valueListenable: _selectedTypeFilterNotifier,
              builder: (context, selectedTypeFilter, _) {
                return _buildPageContent(
                  allTransactions: allTransactions,
                  selectedProductId: selectedProductId,
                  selectedDateRange: selectedDateRange,
                  selectedTypeFilter: selectedTypeFilter,
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _transactionRepository.getTransactionsStream(),
        builder: (context, snapshot) {
          if ((snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) ||
              _isLoadingProducts) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          final allTransactions = snapshot.data ?? [];

          return _buildFilteredContent(allTransactions);
        },
      ),
    );
  }
}
