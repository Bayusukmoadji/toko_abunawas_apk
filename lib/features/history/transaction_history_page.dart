import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_file_saver/flutter_file_saver.dart';
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
  const TransactionHistoryPage({
    super.key,
  });

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final TransactionRepository _transactionRepository = TransactionRepository();

  final ProductRepository _productRepository = ProductRepository();

  static const String _allProductsValue = 'all';

  static const int _pageLimit = 50;

  final ValueNotifier<String> _selectedProductIdNotifier =
      ValueNotifier<String>(
    _allProductsValue,
  );

  final ValueNotifier<DateTimeRange?> _selectedDateRangeNotifier =
      ValueNotifier<DateTimeRange?>(
    null,
  );

  final ValueNotifier<_TransactionTypeFilter> _selectedTypeFilterNotifier =
      ValueNotifier<_TransactionTypeFilter>(
    _TransactionTypeFilter.all,
  );

  List<ProductModel> _products = <ProductModel>[];

  List<TransactionModel> _transactions = <TransactionModel>[];

  bool _isLoadingProducts = true;
  bool _isLoadingTransactions = true;
  bool _isLoadingMore = false;

  bool _hasMoreTransactions = true;

  bool _isGeneratingPdf = false;
  bool _isGeneratingExcel = false;

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

    _selectedProductIdNotifier.addListener(
      _refreshTransactions,
    );

    _selectedDateRangeNotifier.addListener(
      _refreshTransactions,
    );

    _selectedTypeFilterNotifier.addListener(
      _refreshTransactions,
    );

    _loadProducts();

    _loadTransactions(
      reset: true,
    );
  }

  @override
  void dispose() {
    _selectedProductIdNotifier.removeListener(
      _refreshTransactions,
    );

    _selectedDateRangeNotifier.removeListener(
      _refreshTransactions,
    );

    _selectedTypeFilterNotifier.removeListener(
      _refreshTransactions,
    );

    _selectedProductIdNotifier.dispose();
    _selectedDateRangeNotifier.dispose();
    _selectedTypeFilterNotifier.dispose();

    super.dispose();
  }

  // ============================================================
  // DATA
  // ============================================================

  Future<void> _loadProducts() async {
    try {
      final List<ProductModel> products =
          await _productRepository.getActiveProducts();

      if (!mounted) {
        return;
      }

      setState(() {
        _products = products;
        _isLoadingProducts = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingProducts = false;
      });

      _showSnackBar(
        'Gagal memuat produk: ${_errorText(error)}',
        Colors.red,
      );
    }
  }

  void _refreshTransactions() {
    _loadTransactions(
      reset: true,
    );
  }

  Future<void> _loadTransactions({
    required bool reset,
  }) async {
    final int currentVersion = ++_queryVersion;

    if (reset) {
      setState(() {
        _transactions = <TransactionModel>[];

        _lastTransactionDocument = null;

        _hasMoreTransactions = true;

        _isLoadingTransactions = true;

        _isLoadingMore = false;

        _transactionError = null;
      });
    } else {
      if (_isLoadingMore || !_hasMoreTransactions) {
        return;
      }

      setState(() {
        _isLoadingMore = true;
        _transactionError = null;
      });
    }

    try {
      final TransactionPageResult result =
          await _transactionRepository.getTransactionsPage(
        productId: _getFilterProductId(),
        type: _getFilterType(),
        startDate: _getFilterStartDate(),
        endDate: _getFilterEndDate(),
        limit: _pageLimit,
        startAfterDocument: reset ? null : _lastTransactionDocument,
      );

      /*
       * Dokumen stock_out lintas-batch mungkin terpotong
       * pada batas pagination.
       *
       * Karena itu, transaksi baru yang memiliki
       * transactionGroupId eksplisit akan diambil
       * seluruh detail kelompoknya.
       */
      final List<TransactionModel> expandedTransactions =
          await _expandTransactionGroups(
        result.transactions,
      );

      if (!mounted || currentVersion != _queryVersion) {
        return;
      }

      setState(() {
        if (reset) {
          _transactions = _sortTransactions(
            _deduplicateTransactions(
              expandedTransactions,
            ),
          );
        } else {
          _transactions = _sortTransactions(
            _deduplicateTransactions(
              <TransactionModel>[
                ..._transactions,
                ...expandedTransactions,
              ],
            ),
          );
        }

        _lastTransactionDocument = result.lastDocument;

        _hasMoreTransactions = result.hasMore;

        _isLoadingTransactions = false;

        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || currentVersion != _queryVersion) {
        return;
      }

      setState(() {
        _transactionError = error;

        _isLoadingTransactions = false;

        _isLoadingMore = false;
      });
    }
  }

  Future<List<TransactionModel>> _expandTransactionGroups(
    List<TransactionModel> transactions,
  ) async {
    final Set<String> groupIds = <String>{};

    for (final TransactionModel transaction in transactions) {
      if (!_isStockOut(transaction)) {
        continue;
      }

      /*
       * Data lama menggunakan document ID sebagai fallback.
       * Data baru mempunyai transactionGroupId berbeda
       * dari document ID.
       */
      if (transaction.transactionGroupId.trim().isEmpty ||
          transaction.transactionGroupId == transaction.id) {
        continue;
      }

      groupIds.add(
        transaction.transactionGroupId,
      );
    }

    if (groupIds.isEmpty) {
      return transactions;
    }

    final List<TransactionModel> additionalTransactions = <TransactionModel>[];

    for (final String groupId in groupIds) {
      try {
        final List<TransactionModel> groupTransactions =
            await _transactionRepository.getTransactionsByGroupId(
          groupId,
        );

        additionalTransactions.addAll(
          groupTransactions,
        );
      } catch (_) {
        /*
         * Gagal mengambil detail tambahan tidak
         * menggagalkan seluruh halaman.
         */
      }
    }

    return _deduplicateTransactions(
      <TransactionModel>[
        ...transactions,
        ...additionalTransactions,
      ],
    );
  }

  List<TransactionModel> _deduplicateTransactions(
    List<TransactionModel> transactions,
  ) {
    final Map<String, TransactionModel> map = <String, TransactionModel>{};

    for (final TransactionModel transaction in transactions) {
      map[transaction.id] = transaction;
    }

    return map.values.toList();
  }

  List<TransactionModel> _sortTransactions(
    List<TransactionModel> transactions,
  ) {
    final List<TransactionModel> sorted = List<TransactionModel>.from(
      transactions,
    );

    sorted.sort(
      (
        TransactionModel first,
        TransactionModel second,
      ) {
        final int timeComparison = second.createdAt.compareTo(
          first.createdAt,
        );

        if (timeComparison != 0) {
          return timeComparison;
        }

        return second.id.compareTo(
          first.id,
        );
      },
    );

    return sorted;
  }

  // ============================================================
  // GROUPING
  // ============================================================

  List<_TransactionGroup> _groupTransactions(
    List<TransactionModel> transactions,
  ) {
    final Map<String, List<TransactionModel>> grouped =
        <String, List<TransactionModel>>{};

    for (final TransactionModel transaction in transactions) {
      final String key;

      if (_isStockOut(transaction) &&
          transaction.transactionGroupId.trim().isNotEmpty) {
        key = 'stock_out:${transaction.transactionGroupId}';
      } else {
        key = 'single:${transaction.id}';
      }

      grouped.putIfAbsent(
        key,
        () => <TransactionModel>[],
      );

      grouped[key]!.add(
        transaction,
      );
    }

    final List<_TransactionGroup> result = grouped.entries.map(
      (
        MapEntry<String, List<TransactionModel>> entry,
      ) {
        final List<TransactionModel> details = List<TransactionModel>.from(
          entry.value,
        );

        details.sort(
          (
            TransactionModel first,
            TransactionModel second,
          ) {
            return first.id.compareTo(
              second.id,
            );
          },
        );

        return _TransactionGroup(
          key: entry.key,
          details: details,
        );
      },
    ).toList();

    result.sort(
      (
        _TransactionGroup first,
        _TransactionGroup second,
      ) {
        return second.createdAt.compareTo(
          first.createdAt,
        );
      },
    );

    return result;
  }

  // ============================================================
  // FILTER
  // ============================================================

  DateTime? _getFilterStartDate() {
    final DateTimeRange? range = _selectedDateRangeNotifier.value;

    if (range == null) {
      return null;
    }

    return DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
  }

  DateTime? _getFilterEndDate() {
    final DateTimeRange? range = _selectedDateRangeNotifier.value;

    if (range == null) {
      return null;
    }

    return DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );
  }

  String? _getFilterProductId() {
    final String selectedProductId = _selectedProductIdNotifier.value;

    if (selectedProductId == _allProductsValue) {
      return null;
    }

    return selectedProductId;
  }

  String? _getFilterType() {
    switch (_selectedTypeFilterNotifier.value) {
      case _TransactionTypeFilter.all:
        return null;

      case _TransactionTypeFilter.stockIn:
        return 'stock_in';

      case _TransactionTypeFilter.stockOut:
        return 'stock_out';
    }
  }

  Future<void> _pickDateRange() async {
    final DateTime now = DateTime.now();

    final DateTimeRange? currentDateRange = _selectedDateRangeNotifier.value;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      initialDateRange: currentDateRange ??
          DateTimeRange(
            start: DateTime(
              now.year,
              now.month,
              1,
            ),
            end: now,
          ),
      builder: (
        BuildContext context,
        Widget? child,
      ) {
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

  // ============================================================
  // HELPERS
  // ============================================================

  bool _isStockIn(
    TransactionModel transaction,
  ) {
    return transaction.type.trim().toLowerCase() == 'stock_in';
  }

  bool _isStockOut(
    TransactionModel transaction,
  ) {
    return transaction.type.trim().toLowerCase() == 'stock_out';
  }

  int _calculateTotalStockIn(
    List<TransactionModel> transactions,
  ) {
    return transactions.where(_isStockIn).fold<int>(
      0,
      (
        int total,
        TransactionModel transaction,
      ) {
        return total + transaction.qty;
      },
    );
  }

  int _calculateTotalStockOut(
    List<TransactionModel> transactions,
  ) {
    return transactions.where(_isStockOut).fold<int>(
      0,
      (
        int total,
        TransactionModel transaction,
      ) {
        return total + transaction.qty;
      },
    );
  }

  String _getTransactionTypeText(
    String type,
  ) {
    final String normalized = type.trim().toLowerCase();

    if (normalized == 'stock_in') {
      return 'Stok Masuk';
    }

    if (normalized == 'stock_out') {
      return 'Stok Keluar';
    }

    return type;
  }

  Color _getTransactionColor(
    String type,
  ) {
    final String normalized = type.trim().toLowerCase();

    if (normalized == 'stock_in') {
      return Colors.green.shade600;
    }

    if (normalized == 'stock_out') {
      return Colors.red.shade500;
    }

    return Colors.grey;
  }

  IconData _getTransactionIcon(
    String type,
  ) {
    final String normalized = type.trim().toLowerCase();

    if (normalized == 'stock_in') {
      return Icons.call_received_rounded;
    }

    if (normalized == 'stock_out') {
      return Icons.call_made_rounded;
    }

    return Icons.receipt_long;
  }

  String _formatDateTime(
    DateTime dateTime,
  ) {
    final String day = dateTime.day.toString().padLeft(2, '0');

    final String month = dateTime.month.toString().padLeft(2, '0');

    final String hour = dateTime.hour.toString().padLeft(2, '0');

    final String minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/${dateTime.year} '
        '$hour:$minute';
  }

  String _formatDate(
    DateTime dateTime,
  ) {
    final String day = dateTime.day.toString().padLeft(2, '0');

    final String month = dateTime.month.toString().padLeft(2, '0');

    return '$day/$month/${dateTime.year}';
  }

  String _shortenText(
    String text, {
    int maxLength = 25,
  }) {
    if (text.length <= maxLength) {
      return text;
    }

    return '${text.substring(0, maxLength)}...';
  }

  String _errorText(Object error) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        )
        .trim();
  }

  void _showSnackBar(
    String message,
    Color color,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getSelectedProductName({
    String? selectedProductId,
  }) {
    final String currentProductId =
        selectedProductId ?? _selectedProductIdNotifier.value;

    if (currentProductId == _allProductsValue) {
      return 'Semua Produk';
    }

    final Iterable<ProductModel> matched = _products.where(
      (ProductModel product) => product.id == currentProductId,
    );

    if (matched.isEmpty) {
      return 'Produk tidak ditemukan';
    }

    return matched.first.name;
  }

  String _getSelectedPeriodText({
    DateTimeRange? selectedDateRange,
  }) {
    final DateTimeRange? current =
        selectedDateRange ?? _selectedDateRangeNotifier.value;

    if (current == null) {
      return 'Semua Periode';
    }

    return '${_formatDate(current.start)} - '
        '${_formatDate(current.end)}';
  }

  String _getSelectedTypeText({
    _TransactionTypeFilter? selectedTypeFilter,
  }) {
    final _TransactionTypeFilter current =
        selectedTypeFilter ?? _selectedTypeFilterNotifier.value;

    switch (current) {
      case _TransactionTypeFilter.all:
        return 'Semua Transaksi';

      case _TransactionTypeFilter.stockIn:
        return 'Stok Masuk';

      case _TransactionTypeFilter.stockOut:
        return 'Stok Keluar';
    }
  }

  // ============================================================
  // PDF
  // ============================================================

  Future<Uint8List> _buildTransactionReportPdf(
    List<TransactionModel> transactions,
  ) async {
    final pw.Document pdf = pw.Document();

    final DateTime now = DateTime.now();

    final List<_TransactionGroup> groups = _groupTransactions(
      transactions,
    );

    final int totalStockIn = _calculateTotalStockIn(
      transactions,
    );

    final int totalStockOut = _calculateTotalStockOut(
      transactions,
    );

    final int netStock = totalStockIn - totalStockOut;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return <pw.Widget>[
            pw.Text(
              'Laporan Transaksi Stok',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Toko Beras Abunawas',
            ),
            pw.Text(
              'Tanggal cetak: '
              '${_formatDateTime(now)}',
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(
                12,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.grey400,
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text(
                    'Filter Laporan',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(
                    height: 5,
                  ),
                  pw.Text(
                    'Produk: '
                    '${_getSelectedProductName()}',
                  ),
                  pw.Text(
                    'Jenis transaksi: '
                    '${_getSelectedTypeText()}',
                  ),
                  pw.Text(
                    'Periode: '
                    '${_getSelectedPeriodText()}',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(
                12,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.grey400,
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text(
                    'Ringkasan',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(
                    height: 5,
                  ),
                  pw.Text(
                    'Permintaan transaksi: '
                    '${groups.length}',
                  ),
                  pw.Text(
                    'Dokumen Firestore: '
                    '${transactions.length}',
                  ),
                  pw.Text(
                    'Total stok masuk: '
                    '$totalStockIn karung',
                  ),
                  pw.Text(
                    'Total stok keluar: '
                    '$totalStockOut karung',
                  ),
                  pw.Text(
                    'Selisih: '
                    '$netStock karung',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.TableHelper.fromTextArray(
              headers: <String>[
                'No',
                'Tanggal',
                'Jenis',
                'Produk',
                'Batch / Alokasi',
                'Jumlah',
                'User',
                'Group ID',
              ],
              data: List<List<String>>.generate(
                groups.length,
                (int index) {
                  final _TransactionGroup group = groups[index];

                  return <String>[
                    '${index + 1}',
                    _formatDateTime(
                      group.createdAt,
                    ),
                    _getTransactionTypeText(
                      group.type,
                    ),
                    _shortenText(
                      group.productName,
                      maxLength: 25,
                    ),
                    group.allocationSummary,
                    '${group.totalQty} '
                        '${group.unit}',
                    _shortenText(
                      group.performedByName,
                      maxLength: 18,
                    ),
                    group.isCrossBatch ? group.transactionGroupId : '-',
                  ];
                },
              ),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 7,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.green700,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 6.5,
              ),
              cellPadding: const pw.EdgeInsets.all(
                3,
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Catatan: pada pengeluaran lintas-batch, '
              'beberapa dokumen stok keluar dapat memiliki '
              'transactionGroupId yang sama dan ditampilkan '
              'sebagai satu permintaan transaksi.',
              style: const pw.TextStyle(
                fontSize: 8,
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _generateTransactionPdf() async {
    if (_isGeneratingPdf) {
      return;
    }

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final List<TransactionModel> reportTransactions =
          await _transactionRepository.getTransactionsForReport(
        productId: _getFilterProductId(),
        type: _getFilterType(),
        startDate: _getFilterStartDate(),
        endDate: _getFilterEndDate(),
      );

      if (!mounted) {
        return;
      }

      if (reportTransactions.isEmpty) {
        _showSnackBar(
          'Tidak ada transaksi yang sesuai dengan filter.',
          Colors.orange,
        );

        return;
      }

      await Printing.layoutPdf(
        name: 'laporan_transaksi_stok_abunawas.pdf',
        onLayout: (PdfPageFormat format) async {
          return _buildTransactionReportPdf(
            reportTransactions,
          );
        },
      );
    } catch (error) {
      _showSnackBar(
        'Gagal membuat PDF: '
        '${_errorText(error)}',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  // ============================================================
  // EXCEL
  // ============================================================

  Future<void> _generateTransactionExcel() async {
    if (_isGeneratingExcel) {
      return;
    }

    setState(() {
      _isGeneratingExcel = true;
    });

    try {
      final List<TransactionModel> reportTransactions =
          await _transactionRepository.getTransactionsForReport(
        productId: _getFilterProductId(),
        type: _getFilterType(),
        startDate: _getFilterStartDate(),
        endDate: _getFilterEndDate(),
      );

      if (!mounted) {
        return;
      }

      if (reportTransactions.isEmpty) {
        _showSnackBar(
          'Tidak ada transaksi yang sesuai dengan filter.',
          Colors.orange,
        );

        return;
      }

      final List<_TransactionGroup> groups = _groupTransactions(
        reportTransactions,
      );

      final Excel excel = Excel.createExcel();

      final Sheet sheet = excel['Transaksi'];

      if (excel.tables.containsKey(
        'Sheet1',
      )) {
        excel.delete(
          'Sheet1',
        );
      }

      sheet.appendRow(
        <CellValue>[
          TextCellValue('No'),
          TextCellValue(
            'Tanggal',
          ),
          TextCellValue(
            'Jenis Transaksi',
          ),
          TextCellValue(
            'Produk',
          ),
          TextCellValue(
            'Transaction Group ID',
          ),
          TextCellValue(
            'Jumlah Batch',
          ),
          TextCellValue(
            'Rincian Batch',
          ),
          TextCellValue(
            'Jumlah Total',
          ),
          TextCellValue(
            'Satuan',
          ),
          TextCellValue(
            'Pengguna',
          ),
          TextCellValue(
            'Catatan',
          ),
        ],
      );

      for (int index = 0; index < groups.length; index++) {
        final _TransactionGroup group = groups[index];

        sheet.appendRow(
          <CellValue>[
            IntCellValue(
              index + 1,
            ),
            TextCellValue(
              _formatDateTime(
                group.createdAt,
              ),
            ),
            TextCellValue(
              _getTransactionTypeText(
                group.type,
              ),
            ),
            TextCellValue(
              group.productName,
            ),
            TextCellValue(
              group.isCrossBatch ? group.transactionGroupId : '-',
            ),
            IntCellValue(
              group.details.length,
            ),
            TextCellValue(
              group.allocationSummary,
            ),
            IntCellValue(
              group.totalQty,
            ),
            TextCellValue(
              group.unit,
            ),
            TextCellValue(
              group.performedByName,
            ),
            TextCellValue(
              group.notes,
            ),
          ],
        );
      }

      sheet.setColumnWidth(
        0,
        8,
      );

      sheet.setColumnWidth(
        1,
        20,
      );

      sheet.setColumnWidth(
        2,
        18,
      );

      sheet.setColumnWidth(
        3,
        26,
      );

      sheet.setColumnWidth(
        4,
        28,
      );

      sheet.setColumnWidth(
        5,
        12,
      );

      sheet.setColumnWidth(
        6,
        55,
      );

      sheet.setColumnWidth(
        7,
        14,
      );

      sheet.setColumnWidth(
        8,
        12,
      );

      sheet.setColumnWidth(
        9,
        20,
      );

      sheet.setColumnWidth(
        10,
        30,
      );

      final List<int>? encodedBytes = excel.encode();

      if (encodedBytes == null) {
        throw Exception(
          'File Excel gagal dibuat.',
        );
      }

      final Uint8List bytes = Uint8List.fromList(
        encodedBytes,
      );

      await FlutterFileSaver().writeFileAsBytes(
        fileName: 'laporan_transaksi_stok_abunawas.xlsx',
        bytes: bytes,
      );

      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Laporan Excel berhasil dibuat.',
        const Color(0xFF038E1B),
      );
    } catch (error) {
      _showSnackBar(
        'Gagal membuat Excel: '
        '${_errorText(error)}',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingExcel = false;
        });
      }
    }
  }

  // ============================================================
  // UI COMPONENTS
  // ============================================================

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
        ),
        boxShadow: <BoxShadow>[
          _softShadow,
        ],
      ),
      child: Padding(
        padding: padding ??
            const EdgeInsets.all(
              16,
            ),
        child: child,
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              height: 1.35,
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
    final bool isSelected = filter == selectedTypeFilter;

    return Expanded(
      child: InkWell(
        onTap: () {
          _selectedTypeFilterNotifier.value = filter;
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 180,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(
                    0xFF038E1B,
                  )
                : Colors.white,
            borderRadius: BorderRadius.circular(
              14,
            ),
            border: Border.all(
              color: isSelected
                  ? const Color(
                      0xFF038E1B,
                    )
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : Colors.black54,
              ),
              const SizedBox(
                width: 5,
              ),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black87,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSectionTitle(
          title: 'Filter Transaksi',
          subtitle:
              'Transaksi lintas-batch dikelompokkan menggunakan transactionGroupId.',
        ),
        _buildCleanCard(
          child: Column(
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: selectedProductId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Produk / Merek',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: _allProductsValue,
                    child: Text(
                      'Semua Produk',
                    ),
                  ),
                  ..._products.map(
                    (
                      ProductModel product,
                    ) {
                      return DropdownMenuItem<String>(
                        value: product.id,
                        child: Text(
                          product.name,
                        ),
                      );
                    },
                  ),
                ],
                onChanged: _isLoadingProducts
                    ? null
                    : (
                        String? value,
                      ) {
                        if (value == null) {
                          return;
                        }

                        _selectedProductIdNotifier.value = value;
                      },
              ),
              const SizedBox(
                height: 14,
              ),
              Row(
                children: <Widget>[
                  _buildTypeFilterChip(
                    label: 'Semua',
                    icon: Icons.all_inclusive,
                    filter: _TransactionTypeFilter.all,
                    selectedTypeFilter: selectedTypeFilter,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  _buildTypeFilterChip(
                    label: 'Masuk',
                    icon: Icons.call_received_rounded,
                    filter: _TransactionTypeFilter.stockIn,
                    selectedTypeFilter: selectedTypeFilter,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  _buildTypeFilterChip(
                    label: 'Keluar',
                    icon: Icons.call_made_rounded,
                    filter: _TransactionTypeFilter.stockOut,
                    selectedTypeFilter: selectedTypeFilter,
                  ),
                ],
              ),
              const SizedBox(
                height: 16,
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(
                        Icons.calendar_month,
                      ),
                      label: const Text(
                        'Pilih Periode',
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetFilter,
                      icon: const Icon(
                        Icons.refresh,
                      ),
                      label: const Text(
                        'Reset',
                      ),
                    ),
                  ),
                ],
              ),
              if (selectedDateRange != null) ...<Widget>[
                const SizedBox(
                  height: 10,
                ),
                Text(
                  'Periode aktif: '
                  '${_getSelectedPeriodText(
                    selectedDateRange: selectedDateRange,
                  )}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(
    List<TransactionModel> transactions,
  ) {
    final List<_TransactionGroup> groups = _groupTransactions(
      transactions,
    );

    final int totalStockIn = _calculateTotalStockIn(
      transactions,
    );

    final int totalStockOut = _calculateTotalStockOut(
      transactions,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSectionTitle(
          title: 'Ringkasan Tampilan',
          subtitle:
              'Permintaan transaksi dibedakan dari jumlah dokumen Firestore.',
        ),
        _buildCleanCard(
          child: Column(
            children: <Widget>[
              _buildSummaryRow(
                label: 'Permintaan Transaksi',
                value: '${groups.length}',
              ),
              _buildSummaryRow(
                label: 'Dokumen Firestore Dimuat',
                value: '${transactions.length}',
              ),
              _buildSummaryRow(
                label: 'Total Stok Masuk',
                value: '$totalStockIn Karung',
              ),
              _buildSummaryRow(
                label: 'Total Stok Keluar',
                value: '$totalStockOut Karung',
                isLast: true,
              ),
              const SizedBox(
                height: 18,
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isGeneratingPdf ? null : _generateTransactionPdf,
                      icon: _isGeneratingPdf
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.picture_as_pdf,
                              color: Colors.white,
                            ),
                      label: const Text(
                        'PDF',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF038E1B,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isGeneratingExcel ? null : _generateTransactionExcel,
                      icon: _isGeneratingExcel
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.table_view,
                              color: Colors.white,
                            ),
                      label: const Text(
                        'Excel',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF038E1B,
                        ),
                      ),
                    ),
                  ),
                ],
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
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 6,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 10,
          ),
      ],
    );
  }

  Widget _buildGroupCard(
    _TransactionGroup group,
  ) {
    final Color color = _getTransactionColor(
      group.type,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(
        14,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(
          0.055,
        ),
        borderRadius: BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: color.withOpacity(
            0.20,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: color.withOpacity(
                  0.15,
                ),
                child: Icon(
                  _getTransactionIcon(
                    group.type,
                  ),
                  color: color,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      group.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      _getTransactionTypeText(
                        group.type,
                      ),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${group.totalQty} '
                '${group.unit}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          _buildInfoRow(
            icon: Icons.calendar_today_outlined,
            text: 'Tanggal: '
                '${_formatDateTime(group.createdAt)}',
          ),
          _buildInfoRow(
            icon: Icons.person_outline,
            text: 'Dilakukan oleh: '
                '${group.performedByName}',
          ),
          if (group.isCrossBatch) ...<Widget>[
            _buildInfoRow(
              icon: Icons.account_tree_outlined,
              text: 'FIFO lintas-batch: '
                  '${group.details.length} batch',
            ),
            _buildInfoRow(
              icon: Icons.fingerprint,
              text: 'Group ID: '
                  '${group.transactionGroupId}',
            ),
            const SizedBox(
              height: 10,
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(
                12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  12,
                ),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Rincian Alokasi FIFO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  ...group.details.map(
                    (
                      TransactionModel transaction,
                    ) {
                      final String remainingText =
                          transaction.remainingQtyAfter != null
                              ? ' → sisa '
                                  '${transaction.remainingQtyAfter}'
                              : '';

                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 5,
                        ),
                        child: Text(
                          '• ${transaction.batchCode}: '
                          '${transaction.qty} '
                          '${transaction.unit}'
                          '$remainingText',
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ] else ...<Widget>[
            _buildInfoRow(
              icon: Icons.qr_code_2,
              text: 'Kode Batch: '
                  '${group.details.first.batchCode}',
            ),
          ],
          if (group.notes.trim().isNotEmpty)
            _buildInfoRow(
              icon: Icons.notes_outlined,
              text: 'Catatan: '
                  '${group.notes}',
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 5,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            size: 14,
            color: Colors.black45,
          ),
          const SizedBox(
            width: 7,
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(
    List<TransactionModel> transactions,
  ) {
    final List<_TransactionGroup> groups = _groupTransactions(
      transactions,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSectionTitle(
          title: 'Daftar Transaksi',
          subtitle:
              'Pengeluaran FIFO lintas-batch ditampilkan sebagai satu kelompok transaksi.',
        ),
        if (groups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(
              20,
            ),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(
                14,
              ),
            ),
            child: const Text(
              'Tidak ada transaksi yang sesuai dengan filter.',
              textAlign: TextAlign.center,
            ),
          )
        else ...<Widget>[
          ...groups.map(
            _buildGroupCard,
          ),
          const SizedBox(
            height: 6,
          ),
          if (_hasMoreTransactions)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoadingMore
                    ? null
                    : () {
                        _loadTransactions(
                          reset: false,
                        );
                      },
                icon: _isLoadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.expand_more,
                      ),
                label: Text(
                  _isLoadingMore ? 'Memuat...' : 'Muat Lagi',
                ),
              ),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(
                  8,
                ),
                child: Text(
                  'Semua data sudah dimuat.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                  ),
                ),
              ),
            ),
        ],
      ],
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
    Object error,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(
          24,
        ),
        child: Text(
          'Gagal memuat riwayat transaksi:\n'
          '${_errorText(error)}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.red,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      centerTitle: true,
      foregroundColor: Colors.white,
      title: const Text(
        'RIWAYAT TRANSAKSI',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(
                0xFF015816,
              ),
              Color(
                0xFF038E1B,
              ),
              Color(
                0xFF84E977,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool initialLoading =
        _isLoadingProducts || (_isLoadingTransactions && _transactions.isEmpty);

    return Scaffold(
      backgroundColor: const Color(
        0xFFFAFAFA,
      ),
      appBar: _buildAppBar(),
      body: initialLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_transactionError != null && _transactions.isEmpty) {
      return _buildErrorState(
        _transactionError!,
      );
    }

    return ValueListenableBuilder<String>(
      valueListenable: _selectedProductIdNotifier,
      builder: (
        BuildContext context,
        String selectedProductId,
        Widget? child,
      ) {
        return ValueListenableBuilder<DateTimeRange?>(
          valueListenable: _selectedDateRangeNotifier,
          builder: (
            BuildContext context,
            DateTimeRange? selectedDateRange,
            Widget? child,
          ) {
            return ValueListenableBuilder<_TransactionTypeFilter>(
              valueListenable: _selectedTypeFilterNotifier,
              builder: (
                BuildContext context,
                _TransactionTypeFilter selectedTypeFilter,
                Widget? child,
              ) {
                return RefreshIndicator(
                  onRefresh: () => _loadTransactions(
                    reset: true,
                  ),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(
                      16,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 650,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _buildFilterSection(
                              selectedProductId: selectedProductId,
                              selectedDateRange: selectedDateRange,
                              selectedTypeFilter: selectedTypeFilter,
                            ),
                            const SizedBox(
                              height: 24,
                            ),
                            _buildSummary(
                              _transactions,
                            ),
                            const SizedBox(
                              height: 24,
                            ),
                            _buildTransactionList(
                              _transactions,
                            ),
                            if (_transactionError != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 12,
                                ),
                                child: Text(
                                  'Sebagian data gagal dimuat: '
                                  '${_errorText(
                                    _transactionError!,
                                  )}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            const SizedBox(
                              height: 40,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ================================================================
// TRANSACTION GROUP
// ================================================================

class _TransactionGroup {
  final String key;

  final List<TransactionModel> details;

  const _TransactionGroup({
    required this.key,
    required this.details,
  });

  TransactionModel get first {
    return details.first;
  }

  String get type {
    return first.type;
  }

  String get productName {
    return first.productName;
  }

  String get unit {
    return first.unit;
  }

  String get performedByName {
    return first.performedByName;
  }

  String get notes {
    for (final TransactionModel transaction in details) {
      if (transaction.notes.trim().isNotEmpty) {
        return transaction.notes;
      }
    }

    return '';
  }

  DateTime get createdAt {
    return first.createdAt.toDate();
  }

  String get transactionGroupId {
    return first.transactionGroupId;
  }

  int get totalQty {
    return details.fold<int>(
      0,
      (
        int total,
        TransactionModel transaction,
      ) {
        return total + transaction.qty;
      },
    );
  }

  bool get isStockOut {
    return type.trim().toLowerCase() == 'stock_out';
  }

  bool get isCrossBatch {
    return isStockOut && details.length > 1;
  }

  String get allocationSummary {
    if (details.length == 1) {
      final TransactionModel transaction = details.first;

      return '${transaction.batchCode} '
          '(${transaction.qty} '
          '${transaction.unit})';
    }

    return details.map(
      (
        TransactionModel transaction,
      ) {
        return '${transaction.batchCode} '
            '(${transaction.qty} '
            '${transaction.unit})';
      },
    ).join(' | ');
  }
}
