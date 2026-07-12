import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  static const int _pageLimit = 50;

  final ValueNotifier<String> _selectedProductIdNotifier =
      ValueNotifier<String>(_allProductsValue);
  final ValueNotifier<DateTimeRange?> _selectedDateRangeNotifier =
      ValueNotifier<DateTimeRange?>(null);
  final ValueNotifier<_TransactionTypeFilter> _selectedTypeFilterNotifier =
      ValueNotifier<_TransactionTypeFilter>(_TransactionTypeFilter.all);

  List<ProductModel> _products = [];
  List<TransactionModel> _transactions = [];

  bool _isLoadingProducts = true;
  bool _isLoadingTransactions = true;
  bool _isLoadingMore = false;
  bool _hasMoreTransactions = true;
  bool _isGeneratingPdf = false;

  Object? _transactionError;
  DocumentSnapshot<Map<String, dynamic>>? _lastTransactionDocument;
  int _queryVersion = 0;

  final BoxShadow _softShadow = BoxShadow(
    color: Colors.black.withOpacity(0.07),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  @override
  void initState() {
    super.initState();

    _selectedProductIdNotifier.addListener(_refreshTransactions);
    _selectedDateRangeNotifier.addListener(_refreshTransactions);
    _selectedTypeFilterNotifier.addListener(_refreshTransactions);

    _loadProducts();
    _loadTransactions(reset: true);
  }

  @override
  void dispose() {
    _selectedProductIdNotifier.removeListener(_refreshTransactions);
    _selectedDateRangeNotifier.removeListener(_refreshTransactions);
    _selectedTypeFilterNotifier.removeListener(_refreshTransactions);

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

  void _refreshTransactions() {
    _loadTransactions(reset: true);
  }

  DateTime? _getFilterStartDate() {
    final range = _selectedDateRangeNotifier.value;

    if (range == null) return null;

    return DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
  }

  DateTime? _getFilterEndDate() {
    final range = _selectedDateRangeNotifier.value;

    if (range == null) return null;

    return DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
    );
  }

  String? _getFilterProductId() {
    final selectedProductId = _selectedProductIdNotifier.value;

    if (selectedProductId == _allProductsValue) {
      return null;
    }

    return selectedProductId;
  }

  String? _getFilterType() {
    final selectedType = _selectedTypeFilterNotifier.value;

    switch (selectedType) {
      case _TransactionTypeFilter.all:
        return null;
      case _TransactionTypeFilter.stockIn:
        return 'stock_in';
      case _TransactionTypeFilter.stockOut:
        return 'stock_out';
    }
  }

  Future<void> _loadTransactions({required bool reset}) async {
    final currentVersion = ++_queryVersion;

    if (reset) {
      setState(() {
        _transactions = [];
        _lastTransactionDocument = null;
        _hasMoreTransactions = true;
        _isLoadingTransactions = true;
        _isLoadingMore = false;
        _transactionError = null;
      });
    } else {
      if (_isLoadingMore || !_hasMoreTransactions) return;

      setState(() {
        _isLoadingMore = true;
        _transactionError = null;
      });
    }

    try {
      final result = await _transactionRepository.getTransactionsPage(
        productId: _getFilterProductId(),
        type: _getFilterType(),
        startDate: _getFilterStartDate(),
        endDate: _getFilterEndDate(),
        limit: _pageLimit,
        startAfterDocument: reset ? null : _lastTransactionDocument,
      );

      if (!mounted || currentVersion != _queryVersion) return;

      setState(() {
        if (reset) {
          _transactions = result.transactions;
        } else {
          _transactions = [
            ..._transactions,
            ...result.transactions,
          ];
        }

        _lastTransactionDocument = result.lastDocument;
        _hasMoreTransactions = result.hasMore;
        _isLoadingTransactions = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || currentVersion != _queryVersion) return;

      setState(() {
        _transactionError = e;
        _isLoadingTransactions = false;
        _isLoadingMore = false;
      });
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
            ),
            pw.SizedBox(height: 16),
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

  Future<void> _generateTransactionPdf() async {
    if (_isGeneratingPdf) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final reportTransactions =
          await _transactionRepository.getTransactionsForReport(
        productId: _getFilterProductId(),
        type: _getFilterType(),
        startDate: _getFilterStartDate(),
        endDate: _getFilterEndDate(),
      );

      if (!mounted) return;

      if (reportTransactions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak ada transaksi yang sesuai dengan filter laporan.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await Printing.layoutPdf(
        name: 'laporan_transaksi_stok_abunawas.pdf',
        onLayout: (format) async {
          return _buildTransactionReportPdf(reportTransactions);
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
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
          subtitle: 'Data transaksi dimuat bertahap agar halaman tetap ringan.',
        ),
        _buildCleanCard(
          padding: const EdgeInsets.all(16),
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

  Widget _buildSummary(List<TransactionModel> transactions) {
    final totalStockIn = _calculateTotalStockIn(transactions);
    final totalStockOut = _calculateTotalStockOut(transactions);
    final netStock = totalStockIn - totalStockOut;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Ringkasan Tampilan',
          subtitle:
              'Ringkasan ini dihitung dari data yang sedang dimuat di layar. PDF tetap mengambil seluruh data sesuai filter.',
        ),
        _buildCleanCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow(
                label: 'Data Dimuat',
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
                label: 'Selisih Data Dimuat',
                value: '$netStock Karung',
                isLast: true,
              ),
              const SizedBox(height: 16),
              _buildPdfButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPdfButton() {
    return Opacity(
      opacity: _isGeneratingPdf ? 0.7 : 1,
      child: Container(
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
            onTap: _isGeneratingPdf ? null : _generateTransactionPdf,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isGeneratingPdf) ...[
                  const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Membuat PDF...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Generate PDF Sesuai Filter',
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
              ],
            ),
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

  Widget _buildLoadMoreButton() {
    if (!_hasMoreTransactions) {
      return const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 8),
        child: Center(
          child: Text(
            'Semua data yang sesuai filter sudah dimuat.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: SizedBox(
        width: double.infinity,
        height: 42,
        child: OutlinedButton.icon(
          onPressed: _isLoadingMore
              ? null
              : () {
                  _loadTransactions(reset: false);
                },
          icon: _isLoadingMore
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF038E1B),
                  ),
                )
              : const Icon(Icons.expand_more),
          label: Text(_isLoadingMore ? 'Memuat...' : 'Muat Lagi'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF038E1B),
            side: const BorderSide(color: Color(0xFF038E1B)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionList(List<TransactionModel> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Daftar Transaksi',
          subtitle:
              'Data ditampilkan bertahap maksimal $_pageLimit transaksi setiap kali muat.',
        ),
        if (transactions.isEmpty)
          _buildEmptyFilteredResult()
        else ...[
          ...transactions.map(_buildTransactionCard),
          _buildLoadMoreButton(),
        ],
      ],
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
    required String selectedProductId,
    required DateTimeRange? selectedDateRange,
    required _TransactionTypeFilter selectedTypeFilter,
  }) {
    if (_isLoadingTransactions && _transactions.isEmpty) {
      return _buildLoadingState();
    }

    if (_transactionError != null && _transactions.isEmpty) {
      return _buildErrorState(_transactionError);
    }

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
                  _buildSummary(_transactions),
                  const SizedBox(height: 24),
                  _buildTransactionList(_transactions),
                  if (_transactionError != null && _transactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Sebagian data gagal dimuat: $_transactionError',
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 11,
                        ),
                      ),
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

  Widget _buildFilteredContent() {
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
    final isInitialLoading =
        _isLoadingProducts || (_isLoadingTransactions && _transactions.isEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(),
      body: isInitialLoading ? _buildLoadingState() : _buildFilteredContent(),
    );
  }
}
