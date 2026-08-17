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
  final ProductRepository _productRepository = ProductRepository();
  final TransactionRepository _transactionRepository = TransactionRepository();

  List<ProductModel> _products = [];
  List<TransactionModel> _transactions = [];

  String _selectedProduct = _allProductsValue;

  bool _loading = true;
  bool _generatingPdf = false;

  String? _errorMessage;
  _ValidationResult? _result;

  late final DateTime _validationEnd;
  late final DateTime _validationStart;
  late final DateTime _trainingEnd;
  late final DateTime _trainingStart;

  @override
  void initState() {
    super.initState();

    // Historical backtesting berdasarkan dataset penelitian
    // 31 Januari 2026 sampai 31 Juli 2026 (182 hari).
    //
    // 31 Januari - 24 Juli 2026 = data training.
    // 25 Juli - 31 Juli 2026 = data validasi/holdout.
    //
    // Data validasi tidak digunakan saat membentuk model regresi.
    _trainingStart = DateTime(2026, 1, 31);
    _trainingEnd = DateTime(2026, 7, 24);
    _validationStart = DateTime(2026, 7, 25);
    _validationEnd = DateTime(2026, 7, 31);

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
        startDate: _trainingStart,
        endDate: _endOfDay(
          _validationEnd,
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

      _calculateValidation();
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

      final matchesProduct = _isAllProducts
          ? _activeProductIds.contains(
              transaction.productId,
            )
          : transaction.productId == _selectedProduct;

      if (!matchesProduct) {
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

  void _calculateValidation() {
    if (_loading) {
      return;
    }

    try {
      final trainingData = _buildDailyValues(
        start: _trainingStart,
        end: _trainingEnd,
      );

      final actualValidationData = _buildDailyValues(
        start: _validationStart,
        end: _validationEnd,
      );

      final model = _calculateRegressionModel(
        trainingData,
      );

      if (model == null) {
        setState(() {
          _result = null;
          _errorMessage = 'Data belum cukup untuk validasi. '
              'Minimal diperlukan 3 hari aktif stok keluar '
              'pada periode training.';
        });

        return;
      }

      final comparison = <_ValidationDailyResult>[];

      double absoluteErrorTotal = 0;
      double squaredErrorTotal = 0;

      int actualTotal = 0;
      int predictedTotal = 0;

      for (var index = 0; index < actualValidationData.length; index++) {
        final actual = actualValidationData[index];

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

      final mae = n == 0 ? 0.0 : absoluteErrorTotal / n;

      final rmse = n == 0
          ? 0.0
          : math.sqrt(
              squaredErrorTotal / n,
            );

      final totalDifference = predictedTotal - actualTotal;

      final absoluteTotalDifference = totalDifference.abs();

      final wape =
          actualTotal > 0 ? (absoluteErrorTotal / actualTotal) * 100 : null;

      setState(() {
        _errorMessage = null;
        _result = _ValidationResult(
          model: model,
          comparison: comparison,
          mae: mae,
          rmse: rmse,
          actualTotal: actualTotal,
          predictedTotal: predictedTotal,
          totalDifference: totalDifference,
          absoluteTotalDifference: absoluteTotalDifference,
          totalAbsoluteError: absoluteErrorTotal.round(),
          wape: wape,
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

  String _errorInterpretation(
    _ValidationResult result,
  ) {
    final wape = result.wape;

    if (wape == null) {
      return 'Total aktual pada periode validasi adalah 0, '
          'sehingga WAPE tidak dapat dihitung. '
          'Gunakan Total Error Absolut, MAE, dan RMSE '
          'sebagai ukuran error model.';
    }

    return 'Selisih total prediksi-aktual menunjukkan perbedaan '
        'antara total prediksi dan total aktual selama periode validasi. '
        'Total error absolut merupakan penjumlahan seluruh nilai |error| '
        'harian dan menjadi dasar perhitungan MAE serta WAPE. '
        'MAE menunjukkan rata-rata error absolut per hari, sedangkan '
        'RMSE memberi penalti lebih besar pada error harian yang besar. '
        'WAPE pada periode ini sebesar '
        '${wape.toStringAsFixed(2)}%.';
  }

  Future<Uint8List> _buildPdf(
    _ValidationResult result,
  ) async {
    final document = pw.Document();

    final generatedAt = DateTime.now();

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
              'Hasil Validasi Linear Regression',
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
              'Dibuat: ${_formatDateTime(generatedAt)}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(
                10,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.grey400,
                ),
                borderRadius: pw.BorderRadius.circular(
                  6,
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Informasi Pengujian',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Produk: ${_analysisName()}',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                    ),
                  ),
                  pw.Text(
                    'Dataset: '
                    '${_formatDate(_trainingStart)} - '
                    '${_formatDate(_validationEnd)}',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                    ),
                  ),
                  pw.Text(
                    'Training: '
                    '${_formatDate(_trainingStart)} - '
                    '${_formatDate(_trainingEnd)}',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                    ),
                  ),
                  pw.Text(
                    'Validasi: '
                    '${_formatDate(_validationStart)} - '
                    '${_formatDate(_validationEnd)}',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                    ),
                  ),
                  pw.Text(
                    'Persamaan: Y = '
                    '${result.model.intercept.toStringAsFixed(4)} '
                    '${result.model.slope >= 0 ? '+' : '-'} '
                    '${result.model.slope.abs().toStringAsFixed(4)}X',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                    ),
                  ),
                  pw.Text(
                    'Trend: ${_trendLabel(result.model.slope)}',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
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
                fontSize: 8,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 7.5,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 5,
              ),
              headers: const [
                'Tanggal',
                'Aktual',
                'Prediksi',
                'Error Absolut',
                'Error Kuadrat',
              ],
              data: result.comparison.map(
                (item) {
                  return [
                    _formatDate(
                      item.date,
                    ),
                    '${item.actualQty}',
                    '${item.predictedQty}',
                    item.absoluteError.toStringAsFixed(2),
                    item.squaredError.toStringAsFixed(2),
                  ];
                },
              ).toList(),
              columnWidths: const {
                0: pw.FlexColumnWidth(
                  1.25,
                ),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(
                  1.25,
                ),
                4: pw.FlexColumnWidth(
                  1.25,
                ),
              },
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(
                10,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(
                  6,
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Ringkasan Hasil',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Total aktual: ${result.actualTotal} ${_unit()}',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                    ),
                  ),
                  pw.Text(
                    'Total prediksi: ${result.predictedTotal} ${_unit()}',
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
                    '${result.totalAbsoluteError} ${_unit()}',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                    ),
                  ),
                  pw.Text(
                    'MAE: ${result.mae.toStringAsFixed(2)} ${_unit()}/hari',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                    ),
                  ),
                  pw.Text(
                    'RMSE: ${result.rmse.toStringAsFixed(2)} ${_unit()}/hari',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                    ),
                  ),
                  pw.Text(
                    'Persentase error (WAPE): '
                    '${result.wape == null ? '-' : '${result.wape!.toStringAsFixed(2)}%'}',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                    ),
                  ),
                  pw.SizedBox(height: 7),
                  pw.Text(
                    _errorInterpretation(
                      result,
                    ),
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      lineSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 7),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(7),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Rumus evaluasi:',
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'MAE = (1/n) x jumlah |Aktual - Prediksi|',
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                        pw.Text(
                          'RMSE = akar[(1/n) x jumlah (Aktual - Prediksi)^2]',
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                        pw.Text(
                          'WAPE = (jumlah |Aktual - Prediksi| / jumlah Aktual) x 100%',
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Metode validasi menggunakan historical backtesting '
              'dengan holdout 7 hari. Dataset penelitian 31 Januari '
              'sampai 31 Juli 2026 dipisahkan menjadi data training '
              '31 Januari sampai 24 Juli 2026 dan data validasi '
              '25 Juli sampai 31 Juli 2026. Data validasi tidak '
              'digunakan dalam pembentukan model.',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey700,
              ),
            ),
          ];
        },
      ),
    );

    return document.save();
  }

  Future<void> _generatePdf(
    _ValidationResult result,
  ) async {
    if (_generatingPdf) {
      return;
    }

    setState(() {
      _generatingPdf = true;
    });

    try {
      await Printing.layoutPdf(
        name: 'validasi_regresi_abunawas.pdf',
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

  Widget _buildFilterCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Pengaturan Validasi',
          'Pilih produk yang akan diuji. Validasi menggunakan '
              'historical backtesting dari dataset penelitian '
              '31 Januari sampai 31 Juli 2026.',
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

                  _calculateValidation();
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
                      'Dataset',
                      '${_formatDate(_trainingStart)} - '
                          '${_formatDate(_validationEnd)}',
                    ),
                    const Divider(
                      height: 16,
                    ),
                    _periodRow(
                      'Training',
                      '${_formatDate(_trainingStart)} - '
                          '${_formatDate(_trainingEnd)}',
                    ),
                    const Divider(
                      height: 16,
                    ),
                    _periodRow(
                      'Validasi',
                      '${_formatDate(_validationStart)} - '
                          '${_formatDate(_validationEnd)}',
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

  Widget _periodRow(
    String label,
    String period,
  ) {
    return Row(
      children: [
        const Icon(
          Icons.date_range_outlined,
          color: Color(0xFF038E1B),
          size: 20,
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 78,
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
            period,
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

  Widget _buildModelCard(
    _ValidationResult result,
  ) {
    final model = result.model;
    final trendColor = _trendColor(model.slope);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Model yang Diuji',
          'Model linear regression dibentuk hanya dari periode '
              'training. Data validasi tidak ikut digunakan '
              'dalam pembentukan persamaan.',
        ),
        _card(
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: trendColor.withOpacity(
                      0.13,
                    ),
                    child: Icon(
                      Icons.show_chart_rounded,
                      color: trendColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Persamaan Regresi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          'Y = '
                          '${model.intercept.toStringAsFixed(4)} '
                          '${model.slope >= 0 ? '+' : '-'} '
                          '${model.slope.abs().toStringAsFixed(4)}X',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
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
                        model.slope,
                      ),
                      style: TextStyle(
                        color: trendColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _resultRow(
                'Mode Analisis',
                _analysisName(),
              ),
              _resultRow(
                'Jumlah Data Training',
                '${model.dataCount} hari',
              ),
              _resultRow(
                'Hari Aktif Stok Keluar',
                '${model.activeDays} hari',
              ),
              _resultRow(
                'Total Stok Keluar Training',
                '${model.totalQty} ${_unit()}',
              ),
              _resultRow(
                'Rata-rata Training',
                '${model.averageQty.toStringAsFixed(2)} '
                    '${_unit()}/hari',
              ),
              _resultRow(
                'Slope',
                model.slope.toStringAsFixed(4),
              ),
              _resultRow(
                'Intercept',
                model.intercept.toStringAsFixed(4),
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsCard(
    _ValidationResult result,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Hasil Validasi',
          'Prediksi 7 hari dibandingkan dengan data stok keluar '
              'aktual pada tanggal yang sama.',
        ),
        _card(
          child: Column(
            children: [
              _resultRow(
                'Total Aktual',
                '${result.actualTotal} ${_unit()}',
              ),
              _resultRow(
                'Total Prediksi',
                '${result.predictedTotal} ${_unit()}',
              ),
              _resultRow(
                'Selisih Total Prediksi-Aktual',
                '${result.absoluteTotalDifference} ${_unit()}',
              ),
              _resultRow(
                'Total Error Absolut',
                '${result.totalAbsoluteError} ${_unit()}',
              ),
              _resultRow(
                'MAE',
                '${result.mae.toStringAsFixed(2)} '
                    '${_unit()}/hari',
              ),
              _resultRow(
                'RMSE',
                '${result.rmse.toStringAsFixed(2)} '
                    '${_unit()}/hari',
              ),
              _resultRow(
                'Persentase Error (WAPE)',
                result.wape == null
                    ? '-'
                    : '${result.wape!.toStringAsFixed(2)}%',
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
                  _errorInterpretation(
                    result,
                  ),
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyComparisonCard(
    _ValidationResult result,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Perbandingan Harian',
          'Error harian = Aktual - Prediksi. |Error| digunakan '
              'untuk MAE/WAPE dan Error² digunakan untuk RMSE.',
        ),
        _card(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 42,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 52,
              horizontalMargin: 10,
              columnSpacing: 18,
              columns: const [
                DataColumn(
                  label: Text(
                    'Tanggal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    'Aktual',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    'Prediksi',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    '|Error|',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    'Error²',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              rows: result.comparison
                  .map(
                    (item) => DataRow(
                      cells: [
                        DataCell(
                          Text(
                            _formatDate(
                              item.date,
                            ),
                            style: const TextStyle(
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${item.actualQty}',
                            style: const TextStyle(
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${item.predictedQty}',
                            style: const TextStyle(
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.absoluteError.toStringAsFixed(
                              2,
                            ),
                            style: const TextStyle(
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.squaredError.toStringAsFixed(
                              2,
                            ),
                            style: const TextStyle(
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPdfButton(
    _ValidationResult result,
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
                    : 'Generate PDF Hasil Validasi',
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
                        _buildFilterCard(),
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
                          _buildModelCard(
                            _result!,
                          ),
                          const SizedBox(
                            height: 24,
                          ),
                          _buildMetricsCard(
                            _result!,
                          ),
                          const SizedBox(
                            height: 24,
                          ),
                          _buildDailyComparisonCard(
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

class _ValidationResult {
  final _RegressionModel model;
  final List<_ValidationDailyResult> comparison;
  final double mae;
  final double rmse;
  final int actualTotal;
  final int predictedTotal;
  final int totalDifference;
  final int absoluteTotalDifference;
  final int totalAbsoluteError;
  final double? wape;

  const _ValidationResult({
    required this.model,
    required this.comparison,
    required this.mae,
    required this.rmse,
    required this.actualTotal,
    required this.predictedTotal,
    required this.totalDifference,
    required this.absoluteTotalDifference,
    required this.totalAbsoluteError,
    required this.wape,
  });
}
