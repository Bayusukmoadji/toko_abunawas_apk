import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/product_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class RegressionValidationPage extends StatefulWidget {
  final String? initialProductId;

  const RegressionValidationPage({
    super.key,
    this.initialProductId,
  });

  @override
  State<RegressionValidationPage> createState() =>
      _RegressionValidationPageState();
}

class _RegressionValidationPageState extends State<RegressionValidationPage> {
  static const String _allProductsValue = '__all_products__';

  // Validasi mengikuti konsep regresi operasional:
  // - training rolling 6 bulan
  // - testing 7 hari
  // - maksimal 4 window terbaru
  // - tanggal maksimum data = tanggal aplikasi/halaman dibuka
  static const int _trainingMonths = 6;
  static const int _testingDays = 7;
  static const int _maxWindows = 4;

  final ProductRepository _productRepository = ProductRepository();
  final TransactionRepository _transactionRepository = TransactionRepository();

  List<ProductModel> _products = [];
  List<TransactionModel> _transactions = [];

  String _selectedProduct = _allProductsValue;

  bool _loading = true;
  bool _generatingPdf = false;

  String? _errorMessage;
  _RollingValidationResult? _result;

  late final DateTime _appOpenedDate;
  late final DateTime _queryStart;

  @override
  void initState() {
    super.initState();

    // Tanggal maksimum validasi dikunci saat halaman dibuka.
    // Transaksi dengan tanggal setelah hari ini tidak digunakan,
    // walaupun dokumennya sudah ada di Firestore.
    _appOpenedDate = _dateOnly(DateTime.now());

    // Ambil data secukupnya untuk 4 window terbaru.
    // Window tertua memiliki testing 7 hari dan training 6 bulan.
    final oldestTestingStart = _appOpenedDate.subtract(
      const Duration(
        days: (_testingDays * _maxWindows) - 1,
      ),
    );

    _queryStart = _subtractMonths(
      oldestTestingStart,
      _trainingMonths,
    );

    _loadData();
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  DateTime _endOfDay(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    );
  }

  DateTime _subtractMonths(
    DateTime date,
    int months,
  ) {
    final totalMonths = (date.year * 12) + (date.month - 1) - months;

    final year = totalMonths ~/ 12;
    final month = (totalMonths % 12) + 1;

    final lastDayOfTargetMonth = DateTime(
      year,
      month + 1,
      0,
    ).day;

    final day = math.min(
      date.day,
      lastDayOfTargetMonth,
    );

    return DateTime(
      year,
      month,
      day,
    );
  }

  String _dateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  bool get _isAllProducts {
    return _selectedProduct == _allProductsValue;
  }

  ProductModel? _selectedProductModel() {
    if (_isAllProducts) {
      return null;
    }

    for (final product in _products) {
      if (product.id == _selectedProduct) {
        return product;
      }
    }

    return null;
  }

  String _analysisName() {
    if (_isAllProducts) {
      return 'Semua Merek';
    }

    return _selectedProductModel()?.name ?? '-';
  }

  String _unit() {
    if (_isAllProducts) {
      return 'Karung';
    }

    final value = _selectedProductModel()?.unit.trim() ?? '';

    return value.isEmpty ? 'Karung' : value;
  }

  Set<String> get _activeProductIds {
    return _products
        .map(
          (product) => product.id,
        )
        .toSet();
  }

  bool _matchesSelectedProduct(
    TransactionModel transaction,
  ) {
    if (_isAllProducts) {
      return _activeProductIds.contains(
        transaction.productId,
      );
    }

    return transaction.productId == _selectedProduct;
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final products = await _productRepository.getActiveProducts();

      final transactions =
          await _transactionRepository.getTransactionsForReport(
        startDate: _queryStart,
        endDate: _endOfDay(
          _appOpenedDate,
        ),
        maxLimit: 5000,
      );

      if (!mounted) {
        return;
      }

      var selectedProduct = widget.initialProductId?.trim() ?? '';

      if (selectedProduct.isEmpty ||
          !products.any(
            (product) => product.id == selectedProduct,
          )) {
        selectedProduct = _allProductsValue;
      }

      setState(() {
        _products = products;
        _transactions = transactions;
        _selectedProduct = selectedProduct;
        _loading = false;
      });

      _calculateRollingValidation();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _result = null;
        _errorMessage = error.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  DateTime? _earliestRelevantTransactionDate() {
    DateTime? earliest;

    for (final transaction in _transactions) {
      if (!_matchesSelectedProduct(
        transaction,
      )) {
        continue;
      }

      final date = _dateOnly(
        transaction.createdAt.toDate().toLocal(),
      );

      if (earliest == null || date.isBefore(earliest)) {
        earliest = date;
      }
    }

    return earliest;
  }

  DateTime? _latestRelevantTransactionDate() {
    DateTime? latest;

    for (final transaction in _transactions) {
      if (!_matchesSelectedProduct(
        transaction,
      )) {
        continue;
      }

      final date = _dateOnly(
        transaction.createdAt.toDate().toLocal(),
      );

      if (date.isAfter(
        _appOpenedDate,
      )) {
        continue;
      }

      if (latest == null || date.isAfter(latest)) {
        latest = date;
      }
    }

    return latest;
  }

  Map<String, int> _buildDailyMap({
    required DateTime start,
    required DateTime end,
  }) {
    final result = <String, int>{};

    final totalDays = end.difference(start).inDays;

    for (var index = 0; index <= totalDays; index++) {
      final date = start.add(
        Duration(days: index),
      );

      result[_dateKey(date)] = 0;
    }

    for (final transaction in _transactions) {
      if (transaction.type.trim().toLowerCase() != 'stock_out') {
        continue;
      }

      if (!_matchesSelectedProduct(
        transaction,
      )) {
        continue;
      }

      final transactionDate = _dateOnly(
        transaction.createdAt.toDate().toLocal(),
      );

      if (transactionDate.isBefore(start) || transactionDate.isAfter(end)) {
        continue;
      }

      final key = _dateKey(
        transactionDate,
      );

      result[key] = (result[key] ?? 0) + transaction.qty;
    }

    return result;
  }

  List<_DailyValue> _buildDailyValues({
    required DateTime start,
    required DateTime end,
  }) {
    final map = _buildDailyMap(
      start: start,
      end: end,
    );

    final totalDays = end.difference(start).inDays;

    final values = <_DailyValue>[];

    for (var index = 0; index <= totalDays; index++) {
      final date = start.add(
        Duration(days: index),
      );

      values.add(
        _DailyValue(
          date: date,
          qty: map[_dateKey(date)] ?? 0,
        ),
      );
    }

    return values;
  }

  _RegressionModel? _calculateRegressionModel(
    List<_DailyValue> trainingData,
  ) {
    if (trainingData.length < 3) {
      return null;
    }

    final activeDays = trainingData
        .where(
          (item) => item.qty > 0,
        )
        .length;

    if (activeDays < 3) {
      return null;
    }

    final n = trainingData.length;

    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;

    for (var index = 0; index < n; index++) {
      final x = index.toDouble();
      final y = trainingData[index].qty.toDouble();

      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    final denominator = n * sumX2 - sumX * sumX;

    if (denominator == 0) {
      return null;
    }

    final slope = (n * sumXY - sumX * sumY) / denominator;

    final intercept = (sumY - slope * sumX) / n;

    final totalQty = trainingData.fold<int>(
      0,
      (total, item) => total + item.qty,
    );

    return _RegressionModel(
      slope: slope,
      intercept: intercept,
      dataCount: n,
      activeDays: activeDays,
      totalQty: totalQty,
      averageQty: totalQty / trainingData.length,
    );
  }

  List<_ValidationWindowDefinition> _buildWindowDefinitions({
    required DateTime earliestDataDate,
  }) {
    final definitions = <_ValidationWindowDefinition>[];

    for (var index = 0; index < _maxWindows; index++) {
      // Window terbaru berakhir tepat pada tanggal halaman dibuka.
      // Window sebelumnya mundur 7 hari tanpa overlap.
      final testingEnd = _appOpenedDate.subtract(
        Duration(
          days: index * _testingDays,
        ),
      );

      final testingStart = testingEnd.subtract(
        const Duration(
          days: _testingDays - 1,
        ),
      );

      final trainingEnd = testingStart.subtract(
        const Duration(days: 1),
      );

      final trainingStart = _subtractMonths(
        testingStart,
        _trainingMonths,
      );

      // Hanya window dengan histori 6 bulan penuh yang dipakai.
      if (trainingStart.isBefore(
        earliestDataDate,
      )) {
        continue;
      }

      definitions.add(
        _ValidationWindowDefinition(
          trainingStart: trainingStart,
          trainingEnd: trainingEnd,
          testingStart: testingStart,
          testingEnd: testingEnd,
        ),
      );
    }

    // Tampilkan kronologis dari window terlama ke terbaru.
    definitions.sort(
      (a, b) => a.testingStart.compareTo(
        b.testingStart,
      ),
    );

    return definitions;
  }

  _WindowValidationResult? _calculateSingleWindow(
    _ValidationWindowDefinition definition,
  ) {
    final trainingData = _buildDailyValues(
      start: definition.trainingStart,
      end: definition.trainingEnd,
    );

    final testingData = _buildDailyValues(
      start: definition.testingStart,
      end: definition.testingEnd,
    );

    final model = _calculateRegressionModel(
      trainingData,
    );

    if (model == null) {
      return null;
    }

    final comparison = <_ValidationDailyResult>[];

    double absoluteErrorTotal = 0;
    double squaredErrorTotal = 0;

    int actualTotal = 0;
    int predictedTotal = 0;

    for (var index = 0; index < testingData.length; index++) {
      final actual = testingData[index];

      // X diteruskan setelah data training,
      // sama seperti memprediksi 7 hari setelah window training.
      final x = model.dataCount + index;

      final rawPrediction = model.intercept + model.slope * x;

      final predicted = math
          .max(
            0,
            rawPrediction,
          )
          .round();

      final error = actual.qty - predicted;

      final absoluteError = error.abs().toDouble();

      final squaredError = error.toDouble() * error.toDouble();

      absoluteErrorTotal += absoluteError;

      squaredErrorTotal += squaredError;

      actualTotal += actual.qty;
      predictedTotal += predicted;

      comparison.add(
        _ValidationDailyResult(
          date: actual.date,
          actualQty: actual.qty,
          predictedQty: predicted,
          error: error,
          absoluteError: absoluteError,
          squaredError: squaredError,
        ),
      );
    }

    final n = comparison.length;

    if (n == 0) {
      return null;
    }

    final mae = absoluteErrorTotal / n;

    final rmse = math.sqrt(
      squaredErrorTotal / n,
    );

    final difference = predictedTotal - actualTotal;

    final wape =
        actualTotal > 0 ? (absoluteErrorTotal / actualTotal) * 100 : null;

    return _WindowValidationResult(
      definition: definition,
      model: model,
      comparison: comparison,
      mae: mae,
      rmse: rmse,
      actualTotal: actualTotal,
      predictedTotal: predictedTotal,
      absoluteTotalDifference: difference.abs(),
      totalAbsoluteError: absoluteErrorTotal,
      totalSquaredError: squaredErrorTotal,
      wape: wape,
    );
  }

  void _calculateRollingValidation() {
    if (_loading) {
      return;
    }

    try {
      final earliestDataDate = _earliestRelevantTransactionDate();

      if (earliestDataDate == null) {
        setState(() {
          _result = null;
          _errorMessage = 'Belum ada data transaksi yang dapat digunakan '
              'untuk validasi pada produk yang dipilih.';
        });

        return;
      }

      final definitions = _buildWindowDefinitions(
        earliestDataDate: earliestDataDate,
      );

      if (definitions.isEmpty) {
        setState(() {
          _result = null;
          _errorMessage = 'Data belum cukup untuk membentuk window validasi. '
              'Diperlukan minimal 6 bulan histori sebelum '
              'periode testing 7 hari.';
        });

        return;
      }

      final windows = <_WindowValidationResult>[];

      for (final definition in definitions) {
        final window = _calculateSingleWindow(
          definition,
        );

        if (window != null) {
          windows.add(window);
        }
      }

      if (windows.isEmpty) {
        setState(() {
          _result = null;
          _errorMessage = 'Window tersedia, tetapi data stok keluar pada '
              'periode training belum cukup untuk membentuk '
              'model Linear Regression.';
        });

        return;
      }

      double totalAbsoluteError = 0;
      double totalSquaredError = 0;

      int totalActual = 0;
      int totalPredicted = 0;
      int totalPoints = 0;

      for (final window in windows) {
        totalAbsoluteError += window.totalAbsoluteError;

        totalSquaredError += window.totalSquaredError;

        totalActual += window.actualTotal;

        totalPredicted += window.predictedTotal;

        totalPoints += window.comparison.length;
      }

      final overallMae =
          totalPoints == 0 ? 0.0 : totalAbsoluteError / totalPoints;

      final overallRmse = totalPoints == 0
          ? 0.0
          : math.sqrt(
              totalSquaredError / totalPoints,
            );

      final overallWape =
          totalActual > 0 ? (totalAbsoluteError / totalActual) * 100 : null;

      final totalDifference = totalPredicted - totalActual;

      setState(() {
        _errorMessage = null;
        _result = _RollingValidationResult(
          windows: windows,
          earliestDataDate: earliestDataDate,
          latestTransactionDate: _latestRelevantTransactionDate(),
          maxDataDate: _appOpenedDate,
          totalActual: totalActual,
          totalPredicted: totalPredicted,
          absoluteTotalDifference: totalDifference.abs(),
          totalAbsoluteError: totalAbsoluteError,
          overallMae: overallMae,
          overallRmse: overallRmse,
          overallWape: overallWape,
          totalValidationDays: totalPoints,
        );
      });
    } catch (error) {
      setState(() {
        _result = null;
        _errorMessage = error.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  String _trendLabel(double slope) {
    if (slope > 0.1) {
      return 'Meningkat';
    }

    if (slope < -0.1) {
      return 'Menurun';
    }

    return 'Stabil';
  }

  Color _trendColor(double slope) {
    if (slope > 0.1) {
      return Colors.green.shade700;
    }

    if (slope < -0.1) {
      return Colors.red.shade600;
    }

    return Colors.orange.shade700;
  }

  String _wapeText(double? value) {
    if (value == null) {
      return '-';
    }

    return '${value.toStringAsFixed(2)}%';
  }

  String _overallInterpretation(
    _RollingValidationResult result,
  ) {
    final wape = result.overallWape;

    if (wape == null) {
      return 'Total aktual pada seluruh window adalah 0, sehingga '
          'WAPE tidak dapat dihitung. Gunakan Total Error Absolut, '
          'MAE, dan RMSE sebagai ukuran error model.';
    }

    return 'Validasi menggunakan ${result.windows.length} window '
        'rolling terbaru. Setiap window membentuk ulang model dari '
        '6 bulan data training sebelum melakukan testing 7 hari. '
        'MAE keseluruhan menunjukkan rata-rata error absolut harian, '
        'RMSE memberi bobot lebih besar pada error yang besar, dan '
        'WAPE keseluruhan sebesar ${wape.toStringAsFixed(2)}% '
        'menunjukkan proporsi total error absolut terhadap total '
        'stok keluar aktual pada seluruh window.';
  }

  Future<Uint8List> _buildPdf(
    _RollingValidationResult result,
  ) async {
    final document = pw.Document();

    final generatedAt = DateTime.now();

    pw.Widget buildSummaryBox() {
      return pw.Container(
        width: double.infinity,
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
              'Informasi Validasi',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Metode: Rolling / Walk-Forward Backtesting',
              style: const pw.TextStyle(
                fontSize: 8.5,
              ),
            ),
            pw.Text(
              'Produk: ${_analysisName()}',
              style: const pw.TextStyle(
                fontSize: 8.5,
              ),
            ),
            pw.Text(
              'Tanggal aplikasi dibuka: '
              '${_formatDate(result.maxDataDate)}',
              style: const pw.TextStyle(
                fontSize: 8.5,
              ),
            ),
            pw.Text(
              'Tanggal maksimum data validasi: '
              '${_formatDate(result.maxDataDate)}',
              style: const pw.TextStyle(
                fontSize: 8.5,
              ),
            ),
            pw.Text(
              'Window: ${result.windows.length} '
              '(training 6 bulan + testing 7 hari)',
              style: const pw.TextStyle(
                fontSize: 8.5,
              ),
            ),
            pw.Text(
              'Data transaksi terawal yang terbaca: '
              '${_formatDate(result.earliestDataDate)}',
              style: const pw.TextStyle(
                fontSize: 8.5,
              ),
            ),
            pw.Text(
              'Transaksi terakhir <= tanggal aplikasi: '
              '${result.latestTransactionDate == null ? '-' : _formatDate(result.latestTransactionDate!)}',
              style: const pw.TextStyle(
                fontSize: 8.5,
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget buildOverallMetrics() {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Hasil Keseluruhan',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Total hari validasi: '
              '${result.totalValidationDays} hari',
              style: const pw.TextStyle(
                fontSize: 8.5,
              ),
            ),
            pw.Text(
              'Total aktual: '
              '${result.totalActual} ${_unit()}',
              style: const pw.TextStyle(
                fontSize: 8.5,
              ),
            ),
            pw.Text(
              'Total prediksi: '
              '${result.totalPredicted} ${_unit()}',
              style: const pw.TextStyle(
                fontSize: 8.5,
              ),
            ),
            pw.Text(
              'Selisih total prediksi-aktual: '
              '${result.absoluteTotalDifference} ${_unit()}',
              style: const pw.TextStyle(
                fontSize: 8.5,
              ),
            ),
            pw.Text(
              'Total error absolut: '
              '${result.totalAbsoluteError.toStringAsFixed(0)} ${_unit()}',
              style: const pw.TextStyle(
                fontSize: 8.5,
              ),
            ),
            pw.Text(
              'MAE keseluruhan: '
              '${result.overallMae.toStringAsFixed(2)} ${_unit()}/hari',
              style: const pw.TextStyle(
                fontSize: 8.5,
              ),
            ),
            pw.Text(
              'RMSE keseluruhan: '
              '${result.overallRmse.toStringAsFixed(2)} ${_unit()}/hari',
              style: const pw.TextStyle(
                fontSize: 8.5,
              ),
            ),
            pw.Text(
              'WAPE keseluruhan: '
              '${_wapeText(result.overallWape)}',
              style: const pw.TextStyle(
                fontSize: 8.5,
              ),
            ),
            pw.SizedBox(height: 7),
            pw.Text(
              _overallInterpretation(
                result,
              ),
              style: const pw.TextStyle(
                fontSize: 7.5,
                lineSpacing: 2,
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget buildWindowSummaryTable() {
      return pw.TableHelper.fromTextArray(
        border: pw.TableBorder.all(
          color: PdfColors.grey400,
          width: 0.5,
        ),
        headerDecoration: const pw.BoxDecoration(
          color: PdfColors.green700,
        ),
        headerStyle: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 7.2,
        ),
        cellStyle: const pw.TextStyle(
          fontSize: 6.8,
          lineSpacing: 1.4,
        ),
        cellPadding: const pw.EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 4,
        ),
        headers: const [
          'Window',
          'Training',
          'Testing',
          'MAE',
          'RMSE',
          'WAPE',
        ],
        data: List.generate(
          result.windows.length,
          (index) {
            final window = result.windows[index];

            return [
              '${index + 1}',
              '${_formatDate(window.definition.trainingStart)}\n'
                  '${_formatDate(window.definition.trainingEnd)}',
              '${_formatDate(window.definition.testingStart)}\n'
                  '${_formatDate(window.definition.testingEnd)}',
              window.mae.toStringAsFixed(2),
              window.rmse.toStringAsFixed(2),
              _wapeText(
                window.wape,
              ),
            ];
          },
        ),
        columnWidths: const {
          0: pw.FixedColumnWidth(38),
          1: pw.FlexColumnWidth(1.4),
          2: pw.FlexColumnWidth(1.4),
          3: pw.FlexColumnWidth(0.8),
          4: pw.FlexColumnWidth(0.8),
          5: pw.FlexColumnWidth(0.8),
        },
      );
    }

    final detailWidgets = <pw.Widget>[];

    for (var index = 0; index < result.windows.length; index++) {
      final window = result.windows[index];

      // Setiap detail window dibungkus dalam satu widget non-spanning.
      // Jika ruang pada halaman saat ini tidak cukup, seluruh blok
      // window akan dipindahkan ke halaman berikutnya sehingga tabel
      // tidak terpotong di tengah pergantian halaman.
      detailWidgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(
            top: 14,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Detail Window ${index + 1}',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Training: '
                '${_formatDate(window.definition.trainingStart)} - '
                '${_formatDate(window.definition.trainingEnd)} | '
                'Testing: '
                '${_formatDate(window.definition.testingStart)} - '
                '${_formatDate(window.definition.testingEnd)}',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                ),
              ),
              pw.Text(
                'Persamaan: Y = '
                '${window.model.intercept.toStringAsFixed(4)} '
                '${window.model.slope >= 0 ? '+' : '-'} '
                '${window.model.slope.abs().toStringAsFixed(4)}X | '
                'Trend: ${_trendLabel(window.model.slope)}',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                ),
              ),
              pw.Text(
                'MAE ${window.mae.toStringAsFixed(2)} | '
                'RMSE ${window.rmse.toStringAsFixed(2)} | '
                'WAPE ${_wapeText(window.wape)}',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.green700,
                ),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 7,
                ),
                cellStyle: const pw.TextStyle(
                  fontSize: 6.8,
                ),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
                headers: const [
                  'Tanggal',
                  'Aktual',
                  'Prediksi',
                  '|Error|',
                  'Error²',
                ],
                data: window.comparison
                    .map(
                      (item) => [
                        _formatDate(
                          item.date,
                        ),
                        '${item.actualQty}',
                        '${item.predictedQty}',
                        item.absoluteError.toStringAsFixed(
                          0,
                        ),
                        item.squaredError.toStringAsFixed(
                          0,
                        ),
                      ],
                    )
                    .toList(),
                columnWidths: const {
                  0: pw.FlexColumnWidth(
                    1.4,
                  ),
                  1: pw.FlexColumnWidth(
                    0.9,
                  ),
                  2: pw.FlexColumnWidth(
                    0.9,
                  ),
                  3: pw.FlexColumnWidth(
                    0.9,
                  ),
                  4: pw.FlexColumnWidth(
                    0.9,
                  ),
                },
              ),
            ],
          ),
        ),
      );
    }

    document.addPage(
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
            margin: const pw.EdgeInsets.only(
              top: 8,
            ),
            child: pw.Text(
              'Halaman ${context.pageNumber} '
              'dari ${context.pagesCount}',
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
              'Validasi Rolling Linear Regression',
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
              'Dibuat: '
              '${_formatDateTime(generatedAt)}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 12),
            buildSummaryBox(),
            pw.SizedBox(height: 12),
            pw.Text(
              'Ringkasan Window Pengujian',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            buildWindowSummaryTable(),
            pw.SizedBox(height: 12),
            buildOverallMetrics(),
            ...detailWidgets,
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Keterangan Metode',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Setiap window memakai 6 bulan data historis '
                    'sebagai training dan 7 hari berikutnya sebagai '
                    'testing. Window bergeser 7 hari tanpa overlap. '
                    'Tanggal maksimum data yang digunakan selalu '
                    'mengikuti tanggal ketika halaman validasi dibuka. '
                    'Transaksi dengan tanggal setelah tanggal tersebut '
                    'tidak ikut dihitung.',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      lineSpacing: 1.7,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'MAE = (1/n) x jumlah |Aktual - Prediksi|',
                    style: const pw.TextStyle(
                      fontSize: 7,
                    ),
                  ),
                  pw.Text(
                    'RMSE = akar[(1/n) x jumlah '
                    '(Aktual - Prediksi)^2]',
                    style: const pw.TextStyle(
                      fontSize: 7,
                    ),
                  ),
                  pw.Text(
                    'WAPE = (jumlah |Aktual - Prediksi| / '
                    'jumlah Aktual) x 100%',
                    style: const pw.TextStyle(
                      fontSize: 7,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return document.save();
  }

  Future<void> _generatePdf(
    _RollingValidationResult result,
  ) async {
    if (_generatingPdf) {
      return;
    }

    setState(() {
      _generatingPdf = true;
    });

    try {
      await Printing.layoutPdf(
        name: 'validasi_rolling_regresi_abunawas.pdf',
        onLayout: (format) async {
          return _buildPdf(
            result,
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _generatingPdf = false;
        });
      }
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      centerTitle: true,
      elevation: 0,
      foregroundColor: Colors.white,
      title: const Text(
        'VALIDASI REGRESI',
        style: TextStyle(
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
          ),
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.black12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.05,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF015816),
      ),
      filled: true,
      fillColor: const Color(0xFFF9FBF9),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFD7E7D7),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF038E1B),
          width: 1.4,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _periodRow(
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.date_range_outlined,
          color: Color(0xFF038E1B),
          size: 20,
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF015816),
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultRow(
    String label,
    String value, {
    bool last = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!last)
          const Divider(
            height: 1,
            color: Colors.black12,
          ),
      ],
    );
  }

  Widget _buildFilterCard(
    _RollingValidationResult? result,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Pengaturan Validasi',
          'Metode rolling / walk-forward. Setiap window menggunakan '
              '6 bulan training dan 7 hari testing. Tanggal maksimum '
              'data mengikuti tanggal saat halaman ini dibuka.',
        ),
        _card(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedProduct,
                isExpanded: true,
                decoration: _inputDecoration(
                  'Produk / Merek Beras',
                  Icons.inventory_2_outlined,
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: _allProductsValue,
                    child: Text(
                      'Semua Merek',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ..._products.map(
                    (product) => DropdownMenuItem<String>(
                      value: product.id,
                      child: Text(
                        product.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedProduct = value;
                  });

                  _calculateRollingValidation();
                },
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(
                  13,
                ),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFF1F8F1,
                  ),
                  borderRadius: BorderRadius.circular(
                    14,
                  ),
                  border: Border.all(
                    color: const Color(
                      0xFFC8E6C9,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    _periodRow(
                      'Metode',
                      'Rolling / Walk-Forward',
                    ),
                    const Divider(
                      height: 16,
                    ),
                    _periodRow(
                      'Maks. Data',
                      _formatDate(
                        _appOpenedDate,
                      ),
                    ),
                    const Divider(
                      height: 16,
                    ),
                    _periodRow(
                      'Training',
                      '6 bulan / window',
                    ),
                    const Divider(
                      height: 16,
                    ),
                    _periodRow(
                      'Testing',
                      '7 hari / window',
                    ),
                    if (result != null) ...[
                      const Divider(
                        height: 16,
                      ),
                      _periodRow(
                        'Window Aktif',
                        '${result.windows.length} window',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(
                  12,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                  border: Border.all(
                    color: Colors.amber.shade200,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Transaksi bertanggal setelah '
                        '${_formatDate(_appOpenedDate)} tidak digunakan. '
                        'Karena hari ini ikut menjadi batas maksimum, '
                        'pastikan data transaksi hari berjalan sudah '
                        'lengkap bila hasil akan dipakai sebagai '
                        'hasil pengujian laporan.',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: 10.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverallMetricsCard(
    _RollingValidationResult result,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Hasil Keseluruhan',
          'Nilai keseluruhan dihitung dari seluruh prediksi harian '
              'pada semua window yang memenuhi syarat.',
        ),
        _card(
          child: Column(
            children: [
              _resultRow(
                'Jumlah Window',
                '${result.windows.length}',
              ),
              _resultRow(
                'Total Hari Validasi',
                '${result.totalValidationDays} hari',
              ),
              _resultRow(
                'Total Aktual',
                '${result.totalActual} ${_unit()}',
              ),
              _resultRow(
                'Total Prediksi',
                '${result.totalPredicted} ${_unit()}',
              ),
              _resultRow(
                'Selisih Total Prediksi-Aktual',
                '${result.absoluteTotalDifference} ${_unit()}',
              ),
              _resultRow(
                'Total Error Absolut',
                '${result.totalAbsoluteError.toStringAsFixed(0)} ${_unit()}',
              ),
              _resultRow(
                'MAE Keseluruhan',
                '${result.overallMae.toStringAsFixed(2)} '
                    '${_unit()}/hari',
              ),
              _resultRow(
                'RMSE Keseluruhan',
                '${result.overallRmse.toStringAsFixed(2)} '
                    '${_unit()}/hari',
              ),
              _resultRow(
                'WAPE Keseluruhan',
                _wapeText(
                  result.overallWape,
                ),
                last: true,
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(
                  12,
                ),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFF7F7F7,
                  ),
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                ),
                child: Text(
                  _overallInterpretation(
                    result,
                  ),
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWindowCard(
    _WindowValidationResult window,
    int index,
  ) {
    final trendColor = _trendColor(
      window.model.slope,
    );

    return _card(
      padding: const EdgeInsets.all(14),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(
          top: 8,
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(
                  0xFFE8F5E9,
                ),
                borderRadius: BorderRadius.circular(
                  10,
                ),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Color(0xFF015816),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Window ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Testing '
                    '${_formatDate(window.definition.testingStart)}'
                    ' - '
                    '${_formatDate(window.definition.testingEnd)}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: trendColor.withOpacity(
                  0.12,
                ),
                borderRadius: BorderRadius.circular(
                  99,
                ),
              ),
              child: Text(
                _trendLabel(
                  window.model.slope,
                ),
                style: TextStyle(
                  color: trendColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(
            top: 8,
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _metricChip(
                'MAE',
                window.mae.toStringAsFixed(2),
              ),
              _metricChip(
                'RMSE',
                window.rmse.toStringAsFixed(2),
              ),
              _metricChip(
                'WAPE',
                _wapeText(
                  window.wape,
                ),
              ),
            ],
          ),
        ),
        children: [
          const Divider(),
          _resultRow(
            'Training',
            '${_formatDate(window.definition.trainingStart)} - '
                '${_formatDate(window.definition.trainingEnd)}',
          ),
          _resultRow(
            'Testing',
            '${_formatDate(window.definition.testingStart)} - '
                '${_formatDate(window.definition.testingEnd)}',
          ),
          _resultRow(
            'Jumlah Data Training',
            '${window.model.dataCount} hari',
          ),
          _resultRow(
            'Hari Aktif Stok Keluar',
            '${window.model.activeDays} hari',
          ),
          _resultRow(
            'Persamaan',
            'Y = '
                '${window.model.intercept.toStringAsFixed(4)} '
                '${window.model.slope >= 0 ? '+' : '-'} '
                '${window.model.slope.abs().toStringAsFixed(4)}X',
          ),
          _resultRow(
            'Total Aktual',
            '${window.actualTotal} ${_unit()}',
          ),
          _resultRow(
            'Total Prediksi',
            '${window.predictedTotal} ${_unit()}',
          ),
          _resultRow(
            'Total Error Absolut',
            '${window.totalAbsoluteError.toStringAsFixed(0)} ${_unit()}',
            last: true,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 42,
              dataRowMaxHeight: 48,
              horizontalMargin: 8,
              columnSpacing: 16,
              columns: const [
                DataColumn(
                  label: Text(
                    'Tanggal',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    'Aktual',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    'Prediksi',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    '|Error|',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    'Error²',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              rows: window.comparison
                  .map(
                    (item) => DataRow(
                      cells: [
                        DataCell(
                          Text(
                            _formatDate(
                              item.date,
                            ),
                            style: const TextStyle(
                              fontSize: 10,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${item.actualQty}',
                            style: const TextStyle(
                              fontSize: 10,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${item.predictedQty}',
                            style: const TextStyle(
                              fontSize: 10,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.absoluteError.toStringAsFixed(
                              0,
                            ),
                            style: const TextStyle(
                              fontSize: 10,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.squaredError.toStringAsFixed(
                              0,
                            ),
                            style: const TextStyle(
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF2F7F2,
        ),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: const Color(
            0xFFD8E8D8,
          ),
        ),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Color(0xFF315A36),
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildWindowsSection(
    _RollingValidationResult result,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Window Pengujian',
          'Window dibentuk otomatis berdasarkan tanggal aplikasi dan '
              'ditampilkan secara kronologis dari periode terlama '
              'hingga terbaru. Setiap window menggunakan 6 bulan '
              'training dan 7 hari testing tanpa overlap.',
        ),
        ...List.generate(
          result.windows.length,
          (index) => _buildWindowCard(
            result.windows[index],
            index,
          ),
        ),
      ],
    );
  }

  Widget _buildPdfButton(
    _RollingValidationResult result,
  ) {
    return Container(
      width: double.infinity,
      height: 46,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF015816),
            Color(0xFF038E1B),
            Color(0xFF84E977),
          ],
          stops: [0, 0.55, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.12,
            ),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _generatingPdf
              ? null
              : () {
                  _generatePdf(
                    result,
                  );
                },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_generatingPdf)
                const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              const SizedBox(width: 8),
              Text(
                _generatingPdf
                    ? 'Membuat PDF...'
                    : 'Generate PDF Validasi Rolling',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(
    String message,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF038E1B),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  16,
                  24,
                  16,
                  32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 620,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFilterCard(
                          _result,
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(
                            height: 20,
                          ),
                          _buildErrorCard(
                            _errorMessage!,
                          ),
                        ],
                        if (_result != null) ...[
                          const SizedBox(
                            height: 24,
                          ),
                          _buildOverallMetricsCard(
                            _result!,
                          ),
                          const SizedBox(
                            height: 24,
                          ),
                          _buildWindowsSection(
                            _result!,
                          ),
                          const SizedBox(
                            height: 18,
                          ),
                          _buildPdfButton(
                            _result!,
                          ),
                        ],
                        const SizedBox(
                          height: 24,
                        ),
                        Center(
                          child: TextButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(
                              Icons.refresh,
                            ),
                            label: const Text(
                              'Muat Ulang Data',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _DailyValue {
  final DateTime date;
  final int qty;

  const _DailyValue({
    required this.date,
    required this.qty,
  });
}

class _RegressionModel {
  final double slope;
  final double intercept;
  final int dataCount;
  final int activeDays;
  final int totalQty;
  final double averageQty;

  const _RegressionModel({
    required this.slope,
    required this.intercept,
    required this.dataCount,
    required this.activeDays,
    required this.totalQty,
    required this.averageQty,
  });
}

class _ValidationDailyResult {
  final DateTime date;
  final int actualQty;
  final int predictedQty;
  final int error;
  final double absoluteError;
  final double squaredError;

  const _ValidationDailyResult({
    required this.date,
    required this.actualQty,
    required this.predictedQty,
    required this.error,
    required this.absoluteError,
    required this.squaredError,
  });
}

class _ValidationWindowDefinition {
  final DateTime trainingStart;
  final DateTime trainingEnd;
  final DateTime testingStart;
  final DateTime testingEnd;

  const _ValidationWindowDefinition({
    required this.trainingStart,
    required this.trainingEnd,
    required this.testingStart,
    required this.testingEnd,
  });
}

class _WindowValidationResult {
  final _ValidationWindowDefinition definition;
  final _RegressionModel model;
  final List<_ValidationDailyResult> comparison;

  final double mae;
  final double rmse;

  final int actualTotal;
  final int predictedTotal;
  final int absoluteTotalDifference;

  final double totalAbsoluteError;
  final double totalSquaredError;
  final double? wape;

  const _WindowValidationResult({
    required this.definition,
    required this.model,
    required this.comparison,
    required this.mae,
    required this.rmse,
    required this.actualTotal,
    required this.predictedTotal,
    required this.absoluteTotalDifference,
    required this.totalAbsoluteError,
    required this.totalSquaredError,
    required this.wape,
  });
}

class _RollingValidationResult {
  final List<_WindowValidationResult> windows;

  final DateTime earliestDataDate;
  final DateTime? latestTransactionDate;
  final DateTime maxDataDate;

  final int totalActual;
  final int totalPredicted;
  final int absoluteTotalDifference;

  final double totalAbsoluteError;
  final double overallMae;
  final double overallRmse;
  final double? overallWape;

  final int totalValidationDays;

  const _RollingValidationResult({
    required this.windows,
    required this.earliestDataDate,
    required this.latestTransactionDate,
    required this.maxDataDate,
    required this.totalActual,
    required this.totalPredicted,
    required this.absoluteTotalDifference,
    required this.totalAbsoluteError,
    required this.overallMae,
    required this.overallRmse,
    required this.overallWape,
    required this.totalValidationDays,
  });
}
