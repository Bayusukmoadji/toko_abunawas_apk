import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

import '../../data/models/product_model.dart';

import '../../data/models/transaction_model.dart';

import '../../data/repositories/product_repository.dart';

class StockTrendPage extends StatefulWidget {
  const StockTrendPage({super.key});

  @override
  State<StockTrendPage> createState() => _StockTrendPageState();
}

class _StockTrendPageState extends State<StockTrendPage> {
  static const String _allProductsValue = '__all_products__';

  static const int _historyMonths = 6;

  static const int _forecastDays = 7;

  static const int _weeklyWindowDays = 7;

  static const double _trendThresholdPercentPerDay = 0.10;

  static const int _validationWindows = 4;

  static const int _validationDaysPerWindow = 7;

  static const double _pointSpacing = 72;

  final ProductRepository _productRepository = ProductRepository();

  final ScrollController _trendScrollController = ScrollController();

  late final DateTime _historyStart;

  late final DateTime _historyEnd;

  late final Stream<List<TransactionModel>> _transactionsStream;

  late final Stream<List<TransactionModel>> _futureTransactionsStream;

  List<ProductModel> _products = [];

  String _selectedProduct = _allProductsValue;

  String? _lastScrollKey;

  bool _loadingProducts = true;

  bool get _isAllProducts => _selectedProduct == _allProductsValue;

  Set<String> get _activeProductIds =>
      _products.map((product) => product.id).toSet();

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _historyEnd = DateTime(now.year, now.month, now.day);

    _historyStart = _subtractMonths(_historyEnd, _historyMonths);

    _transactionsStream = _getTransactionsByDateRangeStream(
      startDate: _historyStart,
      endDate: _historyEnd,
    );

    // Digunakan untuk mengembalikan state stok Firestore ke posisi

    // pada tanggal analisis. Ini penting jika database sudah berisi

    // transaksi dengan tanggal setelah tanggal aplikasi dibuka.

    _futureTransactionsStream = _getTransactionsByDateRangeStream(
      startDate: _historyEnd.add(const Duration(days: 1)),
      endDate: DateTime(2100, 12, 31),
    );

    _loadProducts();
  }

  @override
  void dispose() {
    _trendScrollController.dispose();

    super.dispose();
  }

  DateTime _subtractMonths(DateTime date, int months) {
    final monthIndex = date.year * 12 + date.month - 1 - months;

    final year = monthIndex ~/ 12;

    final month = monthIndex % 12 + 1;

    final lastDay = DateTime(year, month + 1, 0).day;

    return DateTime(
      year,
      month,
      math.min(date.day, lastDay),
    );
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Stream<List<TransactionModel>> _getTransactionsByDateRangeStream({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final start = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final endExclusive = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    ).add(const Duration(days: 1));

    return FirebaseFirestore.instance
        .collection('transactions')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(
          'createdAt',
          isLessThan: Timestamp.fromDate(endExclusive),
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => TransactionModel.fromMap(
                  document.id,
                  document.data(),
                ),
              )
              .toList(),
        );
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _productRepository.getActiveProducts();

      if (!mounted) return;

      setState(() {
        _products = products;

        _loadingProducts = false;

        if (!_isAllProducts &&
            !_products.any((product) => product.id == _selectedProduct)) {
          _selectedProduct = _allProductsValue;
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingProducts = false;
      });

      _showSnackBar(
        'Gagal memuat produk: ${_cleanError(error)}',
        Colors.red.shade600,
      );
    }
  }

  ProductModel? _selectedProductModel() {
    if (_isAllProducts) return null;

    for (final product in _products) {
      if (product.id == _selectedProduct) return product;
    }

    return null;
  }

  String _analysisName() {
    return _isAllProducts
        ? 'Semua Merek'
        : (_selectedProductModel()?.name ?? '-');
  }

  String _unit() {
    if (_isAllProducts) return 'Karung';

    final value = _selectedProductModel()?.unit.trim() ?? '';

    return value.isEmpty ? 'Karung' : value;
  }

  int _stockForProductAsOf(
    ProductModel product,
    List<TransactionModel> futureTransactions,
  ) {
    var stock = product.totalStock;

    for (final transaction in futureTransactions) {
      if (transaction.productId != product.id) {
        continue;
      }

      final type = transaction.type.trim().toLowerCase();

      // products.totalStock merepresentasikan state Firestore terbaru.

      // Untuk mendapatkan stok pada _historyEnd, semua transaksi setelah

      // tanggal tersebut dibalik secara matematis:

      //

      // stock_in masa depan  -> dikurangi kembali

      // stock_out masa depan -> ditambahkan kembali

      if (type == 'stock_in') {
        stock -= transaction.qty;
      } else if (type == 'stock_out') {
        stock += transaction.qty;
      }
    }

    return math.max(0, stock);
  }

  int _currentStockAsOf(
    List<TransactionModel> futureTransactions,
  ) {
    if (_isAllProducts) {
      return _products.fold<int>(
        0,
        (total, product) =>
            total + _stockForProductAsOf(product, futureTransactions),
      );
    }

    final product = _selectedProductModel();

    if (product == null) {
      return 0;
    }

    return _stockForProductAsOf(
      product,
      futureTransactions,
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

  String _formatShortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  String _historyPeriod() {
    return '${_formatDate(_historyStart)} - ${_formatDate(_historyEnd)}';
  }

  String _forecastPeriod() {
    final start = _historyEnd.add(const Duration(days: 1));

    final end = _historyEnd.add(const Duration(days: _forecastDays));

    return '${_formatDate(start)} - ${_formatDate(end)}';
  }

  _DailySeries _buildDailySeries(
    List<TransactionModel> transactions, {
    String? productId,
  }) {
    final map = <String, _DailyStockOut>{};

    final totalDays = _historyEnd.difference(_historyStart).inDays;

    for (var index = 0; index <= totalDays; index++) {
      final date = _historyStart.add(Duration(days: index));

      map[_dateKey(date)] = _DailyStockOut(
        date: date,
        qty: 0,
      );
    }

    var transactionCount = 0;

    for (final transaction in transactions) {
      if (transaction.type.trim().toLowerCase() != 'stock_out') {
        continue;
      }

      final matchesProduct = productId != null
          ? transaction.productId == productId
          : _activeProductIds.contains(transaction.productId);

      if (!matchesProduct) {
        continue;
      }

      final date = _dateOnly(
        transaction.createdAt.toDate().toLocal(),
      );

      if (date.isBefore(_historyStart) || date.isAfter(_historyEnd)) {
        continue;
      }

      final key = _dateKey(date);

      final oldQty = map[key]?.qty ?? 0;

      map[key] = _DailyStockOut(
        date: date,
        qty: oldQty + transaction.qty,
      );

      transactionCount++;
    }

    final points = map.values.toList()
      ..sort(
        (first, second) => first.date.compareTo(second.date),
      );

    return _DailySeries(
      points: points,
      transactionCount: transactionCount,
      activeDays: points.where((point) => point.qty > 0).length,
      totalQty: points.fold<int>(
        0,
        (total, point) => total + point.qty,
      ),
    );
  }

  _RegressionResult? _calculateRegression(
    _DailySeries series,
  ) {
    final data = series.points;

    if (data.length < 3 || series.activeDays < 3) {
      return null;
    }

    final n = data.length;

    double sumX = 0;

    double sumY = 0;

    double sumXY = 0;

    double sumX2 = 0;

    for (var index = 0; index < n; index++) {
      final x = index.toDouble();

      final y = data[index].qty.toDouble();

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

    final meanY = sumY / n;

    final relativeSlopePercentPerDay =
        meanY == 0 ? 0.0 : (slope / meanY) * 100.0;

    double ssResidual = 0;

    double ssTotal = 0;

    for (var index = 0; index < n; index++) {
      final x = index.toDouble();

      final actual = data[index].qty.toDouble();

      final fitted = intercept + slope * x;

      final residual = actual - fitted;

      final deviationFromMean = actual - meanY;

      ssResidual += residual * residual;

      ssTotal += deviationFromMean * deviationFromMean;
    }

    final double rSquared;

    if (ssTotal == 0) {
      rSquared = ssResidual == 0 ? 1.0 : 0.0;
    } else {
      rSquared = (1 - (ssResidual / ssTotal)).clamp(0.0, 1.0).toDouble();
    }

    final predictions = <_PredictedStockOut>[];

    var predictionTotal = 0;

    for (var index = 0; index < _forecastDays; index++) {
      final x = n + index;

      final raw = intercept + slope * x;

      final qty = math.max(0, raw).round();

      predictions.add(
        _PredictedStockOut(
          date: _historyEnd.add(
            Duration(days: index + 1),
          ),
          qty: qty,
        ),
      );

      predictionTotal += qty;
    }

    final validation = _calculateWalkForwardValidation(series);

    return _RegressionResult(
      slope: slope,
      intercept: intercept,
      rSquared: rSquared,
      relativeSlopePercentPerDay: relativeSlopePercentPerDay,
      validation: validation,
      totalQty: series.totalQty,
      averageQty: series.totalQty / data.length,
      estimatedNext7Days: predictionTotal,
      predictedDaily: predictions,
    );
  }

  _ValidationMetrics? _calculateWalkForwardValidation(
    _DailySeries series,
  ) {
    final data = series.points;

    const requiredTestDays = _validationWindows * _validationDaysPerWindow;

    if (data.length <= requiredTestDays + 2) {
      return null;
    }

    final firstTestIndex = data.length - requiredTestDays;

    double absoluteErrorTotal = 0.0;

    double squaredErrorTotal = 0.0;

    double actualTotal = 0.0;

    double predictedTotal = 0.0;

    int observationCount = 0;

    for (var window = 0; window < _validationWindows; window++) {
      final testStart = firstTestIndex + window * _validationDaysPerWindow;

      final trainingData = data.sublist(0, testStart);

      final activeTrainingDays =
          trainingData.where((point) => point.qty > 0).length;

      if (trainingData.length < 3 || activeTrainingDays < 3) {
        return null;
      }

      final fit = _calculateLinearFit(trainingData);

      if (fit == null) {
        return null;
      }

      for (var offset = 0; offset < _validationDaysPerWindow; offset++) {
        final dataIndex = testStart + offset;

        if (dataIndex >= data.length) {
          break;
        }

        final actual = data[dataIndex].qty.toDouble();

        final rawPrediction = fit.intercept + fit.slope * dataIndex.toDouble();

        final predicted = math.max(0.0, rawPrediction).round().toDouble();

        final error = actual - predicted;

        absoluteErrorTotal += error.abs();

        squaredErrorTotal += error * error;

        actualTotal += actual;

        predictedTotal += predicted;

        observationCount++;
      }
    }

    if (observationCount == 0) {
      return null;
    }

    final mae = absoluteErrorTotal / observationCount;

    final rmse = math.sqrt(squaredErrorTotal / observationCount);

    final wape =
        actualTotal == 0 ? 0.0 : (absoluteErrorTotal / actualTotal) * 100.0;

    return _ValidationMetrics(
      windows: _validationWindows,
      testDays: observationCount,
      totalActual: actualTotal.round(),
      totalPredicted: predictedTotal.round(),
      mae: mae,
      rmse: rmse,
      wape: wape,
    );
  }

  _LinearFit? _calculateLinearFit(
    List<_DailyStockOut> data,
  ) {
    if (data.length < 3) {
      return null;
    }

    final n = data.length;

    double sumX = 0.0;

    double sumY = 0.0;

    double sumXY = 0.0;

    double sumX2 = 0.0;

    for (var index = 0; index < n; index++) {
      final x = index.toDouble();

      final y = data[index].qty.toDouble();

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

    return _LinearFit(
      slope: slope,
      intercept: intercept,
    );
  }

  List<_TrendPoint> _buildWeeklyPoints(
    _DailySeries series,
  ) {
    final result = <_TrendPoint>[];

    final data = series.points;

    for (var startIndex = 0;
        startIndex < data.length;
        startIndex += _weeklyWindowDays) {
      final endIndex = math.min(
        startIndex + _weeklyWindowDays - 1,
        data.length - 1,
      );

      var total = 0;

      for (var index = startIndex; index <= endIndex; index++) {
        total += data[index].qty;
      }

      final dayCount = endIndex - startIndex + 1;

      final endDate = data[endIndex].date;

      result.add(
        _TrendPoint(
          label: _formatShortDate(endDate),
          value: dayCount == 0 ? 0.0 : total / dayCount,
          sourceIndex: endIndex,
        ),
      );
    }

    return result;
  }

  _DailyStockOut _peakDay(
    _DailySeries series,
  ) {
    var peak = series.points.first;

    for (final point in series.points.skip(1)) {
      if (point.qty > peak.qty) {
        peak = point;
      }
    }

    return peak;
  }

  List<_ProductForecast> _productForecasts(
    List<TransactionModel> transactions,
    List<TransactionModel> futureTransactions,
  ) {
    final forecasts = _products.map((product) {
      final series = _buildDailySeries(
        transactions,
        productId: product.id,
      );

      final result = _calculateRegression(series);

      final estimated = result?.estimatedNext7Days ?? 0;

      final stockAsOf = _stockForProductAsOf(
        product,
        futureTransactions,
      );

      return _ProductForecast(
        product: product,
        activeDays: series.activeDays,
        currentStockAsOf: stockAsOf,
        estimatedNeed: estimated,
        additionalNeed: math.max(
          0,
          estimated - stockAsOf,
        ),
        hasEnoughData: result != null,
      );
    }).toList();

    forecasts.sort((first, second) {
      final restock = second.additionalNeed.compareTo(
        first.additionalNeed,
      );

      if (restock != 0) {
        return restock;
      }

      return first.product.name.compareTo(
        second.product.name,
      );
    });

    return forecasts;
  }

  void _scrollTrendToLatest(int pointCount) {
    final key = '$_selectedProduct:$pointCount';

    if (_lastScrollKey == key) {
      return;
    }

    _lastScrollKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_trendScrollController.hasClients) {
        return;
      }

      _trendScrollController.jumpTo(
        _trendScrollController.position.maxScrollExtent,
      );
    });
  }

  String _trendLabel(double relativeSlopePercentPerDay) {
    if (relativeSlopePercentPerDay > _trendThresholdPercentPerDay) {
      return 'Meningkat';
    }

    if (relativeSlopePercentPerDay < -_trendThresholdPercentPerDay) {
      return 'Menurun';
    }

    return 'Stabil';
  }

  String _trendDescription(double relativeSlopePercentPerDay) {
    if (relativeSlopePercentPerDay > _trendThresholdPercentPerDay) {
      return 'Pengeluaran stok cenderung meningkat.';
    }

    if (relativeSlopePercentPerDay < -_trendThresholdPercentPerDay) {
      return 'Pengeluaran stok cenderung menurun.';
    }

    return 'Pengeluaran stok relatif stabil.';
  }

  Color _trendColor(double relativeSlopePercentPerDay) {
    if (relativeSlopePercentPerDay > _trendThresholdPercentPerDay) {
      return Colors.green.shade600;
    }

    if (relativeSlopePercentPerDay < -_trendThresholdPercentPerDay) {
      return Colors.red.shade600;
    }

    return Colors.orange.shade600;
  }

  IconData _trendIcon(double relativeSlopePercentPerDay) {
    if (relativeSlopePercentPerDay > _trendThresholdPercentPerDay) {
      return Icons.trending_up_rounded;
    }

    if (relativeSlopePercentPerDay < -_trendThresholdPercentPerDay) {
      return Icons.trending_down_rounded;
    }

    return Icons.trending_flat_rounded;
  }

  String _predictionStatus(
    int currentStock,
    int estimatedNeed,
  ) {
    if (currentStock < estimatedNeed || currentStock <= 0) {
      return 'Perlu Restock';
    }

    if (currentStock <= (estimatedNeed * 1.3).ceil()) {
      return 'Perlu Dipantau';
    }

    return 'Stok Aman';
  }

  Color _predictionColor(String status) {
    if (status == 'Perlu Restock') {
      return Colors.red.shade600;
    }

    if (status == 'Perlu Dipantau') {
      return Colors.orange.shade600;
    }

    return Colors.green.shade600;
  }

  String _cleanError(Object? error) {
    return error.toString().replaceFirst(
          'Exception: ',
          '',
        );
  }

  void _showSnackBar(
    String message,
    Color color,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _appBar(),
      body: _loadingProducts
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF038E1B),
              ),
            )
          : StreamBuilder<List<TransactionModel>>(
              stream: _transactionsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF038E1B),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _errorState(snapshot.error);
                }

                final transactions = snapshot.data ?? [];

                return StreamBuilder<List<TransactionModel>>(
                  stream: _futureTransactionsStream,
                  builder: (context, futureSnapshot) {
                    if (futureSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !futureSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF038E1B),
                        ),
                      );
                    }

                    if (futureSnapshot.hasError) {
                      return _futureStockErrorState(
                        futureSnapshot.error,
                      );
                    }

                    final futureTransactions = futureSnapshot.data ?? [];

                    final series = _buildDailySeries(
                      transactions,
                      productId: _isAllProducts ? null : _selectedProduct,
                    );

                    final regression = _calculateRegression(series);

                    return SafeArea(
                      child: SingleChildScrollView(
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
                                _filterCard(),
                                const SizedBox(height: 24),
                                _analysisCard(
                                  series,
                                  regression,
                                ),
                                const SizedBox(height: 24),
                                _trendChartCard(
                                  series,
                                  regression,
                                ),
                                const SizedBox(height: 24),
                                _predictionButton(
                                  transactions,
                                  futureTransactions,
                                  regression,
                                ),
                                const SizedBox(height: 24),
                                _dailyDataCard(series),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      centerTitle: true,
      elevation: 0,
      foregroundColor: Colors.white,
      title: const Text(
        'ANALISIS TREN',
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

  Widget _filterCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Filter Analisis',
          'Pilih semua merek atau satu merek. Periode histori otomatis menggunakan enam bulan terakhir.',
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
                },
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8F1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFC8E6C9),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.date_range_outlined,
                      color: Color(0xFF038E1B),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Periode Histori Otomatis',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _historyPeriod(),
                            style: const TextStyle(
                              color: Color(0xFF015816),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
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

  Widget _analysisCard(
    _DailySeries series,
    _RegressionResult? regression,
  ) {
    if (series.transactionCount == 0) {
      return _infoCard(
        'Belum ada transaksi stok keluar untuk ${_analysisName()} pada periode ${_historyPeriod()}.',
      );
    }

    if (regression == null) {
      return _infoCard(
        '${_analysisName()} baru memiliki ${series.activeDays} hari aktif. Minimal diperlukan 3 hari aktif untuk analisis dan prediksi.',
      );
    }

    final relativeSlope = regression.relativeSlopePercentPerDay;

    final color = _trendColor(relativeSlope);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Dashboard Analisis Tren',
          'Ringkasan linear regression dari data stok keluar selama enam bulan terakhir.',
        ),
        _card(
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.14),
                    child: Icon(
                      _trendIcon(relativeSlope),
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status Tren',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _trendDescription(relativeSlope),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _chip(
                    _trendLabel(relativeSlope),
                    color,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _resultRow(
                'Mode Analisis',
                _analysisName(),
              ),
              _resultRow(
                'Periode Histori',
                _historyPeriod(),
              ),
              _resultRow(
                'Jumlah Data Harian',
                '${series.points.length} hari',
              ),
              _resultRow(
                'Hari Ada Stok Keluar',
                '${series.activeDays} hari',
              ),
              _resultRow(
                'Jumlah Transaksi',
                '${series.transactionCount} transaksi',
              ),
              _resultRow(
                'Total Stok Keluar',
                '${regression.totalQty} ${_unit()}',
              ),
              _resultRow(
                'Rata-rata per Hari',
                '${regression.averageQty.toStringAsFixed(2)} ${_unit()}',
              ),
              _resultRow(
                'Nilai Slope',
                regression.slope.toStringAsFixed(4),
              ),
              _resultRow(
                'Slope Relatif',
                '${regression.relativeSlopePercentPerDay.toStringAsFixed(4)}% per hari',
              ),
              _resultRow(
                'Nilai Intercept',
                regression.intercept.toStringAsFixed(4),
              ),
              _resultRow(
                'Koefisien Determinasi (R²)',
                '${regression.rSquared.toStringAsFixed(4)} '
                    '(${(regression.rSquared * 100).toStringAsFixed(2)}%)',
              ),
              if (regression.validation != null) ...[
                _resultRow(
                  'MAE',
                  '${regression.validation!.mae.toStringAsFixed(2)} ${_unit()}/hari',
                ),
                _resultRow(
                  'RMSE',
                  '${regression.validation!.rmse.toStringAsFixed(2)} ${_unit()}/hari',
                ),
                _resultRow(
                  'WAPE',
                  '${regression.validation!.wape.toStringAsFixed(2)}%',
                ),
              ],
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8F1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFC8E6C9),
                  ),
                ),
                child: const Text(
                  'R² menunjukkan proporsi variasi stok keluar yang dapat '
                  'dijelaskan oleh model regresi linear terhadap waktu. '
                  'Nilai R² bukan persentase akurasi prediksi. Status tren '
                  'menggunakan slope relatif dengan ambang ±0,10% per hari. '
                  'MAE, RMSE, dan WAPE dihitung menggunakan validasi '
                  'walk-forward 4 jendela × 7 hari.',
                  style: TextStyle(
                    color: Color(0xFF015816),
                    fontSize: 10.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _trendChartCard(
    _DailySeries series,
    _RegressionResult? regression,
  ) {
    if (series.transactionCount == 0 || regression == null) {
      return const SizedBox.shrink();
    }

    final points = _buildWeeklyPoints(series);

    final peak = _peakDay(series);

    final chartWidth = 58 +
        math.max(
              0,
              points.length - 1,
            ) *
            _pointSpacing;

    _scrollTrendToLatest(points.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Grafik Tren Stok Keluar 6 Bulan',
          'Satu titik mewakili rata-rata tujuh hari dan memiliki satu label tanggal pada sumbu X.',
        ),
        _card(
          padding: const EdgeInsets.fromLTRB(
            12,
            14,
            12,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _miniSummary(
                      'Rata-rata Harian',
                      '${regression.averageQty.toStringAsFixed(2)} ${_unit()}',
                      Icons.show_chart_rounded,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _miniSummary(
                      'Puncak Harian',
                      '${peak.qty} ${_unit()}',
                      Icons.north_east_rounded,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Puncak terjadi pada ${_formatDate(peak.date)}.',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sumbu Y: Rata-rata stok keluar (${_unit()}/hari)',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = math.max(
                    constraints.maxWidth,
                    chartWidth.toDouble(),
                  );

                  return Scrollbar(
                    controller: _trendScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: SingleChildScrollView(
                      controller: _trendScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: SizedBox(
                        width: width,
                        height: 334,
                        child: CustomPaint(
                          painter: _TrendChartPainter(
                            points: points,
                            regression: regression,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Sumbu X: Tanggal akhir setiap periode 7 hari',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.swipe_rounded,
                      size: 17,
                      color: Color(0xFF038E1B),
                    ),
                    SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'Geser ke kiri untuk melihat histori yang lebih lama.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  _legend(
                    const Color(0xFF038E1B),
                    'Rata-rata 7 Hari',
                    false,
                  ),
                  _legend(
                    Colors.orange.shade700,
                    'Garis Tren Regresi',
                    true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _predictionButton(
    List<TransactionModel> transactions,
    List<TransactionModel> futureTransactions,
    _RegressionResult? regression,
  ) {
    final enabled = regression != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Prediksi Stok Keluar 7 Hari',
          'Prediksi dihitung untuk tujuh hari setelah tanggal akhir histori.',
        ),
        Opacity(
          opacity: enabled ? 1 : 0.55,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF015816),
                    Color(0xFF038E1B),
                    Color(0xFF84E977),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: regression != null
                      ? () {
                          _showPredictionSheet(
                            transactions,
                            futureTransactions,
                            regression,
                          );
                        }
                      : () {
                          _showSnackBar(
                            'Minimal diperlukan 3 hari aktif untuk membuat prediksi.',
                            Colors.orange.shade700,
                          );
                        },
                  child: const Center(
                    child: Text(
                      'Lihat Prediksi 7 Hari',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showPredictionSheet(
    List<TransactionModel> transactions,
    List<TransactionModel> futureTransactions,
    _RegressionResult regression,
  ) {
    final forecasts = _isAllProducts
        ? _productForecasts(
            transactions,
            futureTransactions,
          )
        : const <_ProductForecast>[];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.86,
          minChildSize: 0.58,
          maxChildSize: 0.94,
          builder: (
            context,
            controller,
          ) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  30,
                ),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Prediksi Stok Keluar 7 Hari',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_analysisName()} • ${_forecastPeriod()}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _predictionSummary(
                    regression,
                    futureTransactions,
                  ),
                  const SizedBox(height: 20),
                  _predictionChart(regression),
                  const SizedBox(height: 20),
                  _predictionDailyList(regression),
                  if (_isAllProducts) ...[
                    const SizedBox(height: 20),
                    _forecastList(forecasts),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _predictionSummary(
    _RegressionResult regression,
    List<TransactionModel> futureTransactions,
  ) {
    final current = _currentStockAsOf(
      futureTransactions,
    );

    final estimated = regression.estimatedNext7Days;

    final additional = math.max(
      0,
      estimated - current,
    );

    final status = _predictionStatus(
      current,
      estimated,
    );

    final color = _predictionColor(status);

    return _card(
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.14),
                child: Icon(
                  Icons.insights_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _chip(
                additional > 0 ? 'Restock' : 'Aman',
                color,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _resultRow(
            'Mode Analisis',
            _analysisName(),
          ),
          _resultRow(
            'Periode Prediksi',
            _forecastPeriod(),
          ),
          _resultRow(
            'Stok s.d. ${_formatDate(_historyEnd)}',
            '$current ${_unit()}',
          ),
          _resultRow(
            'Estimasi 7 Hari',
            '$estimated ${_unit()}',
          ),
          _resultRow(
            'Saran Tambahan',
            additional == 0 ? 'Tidak perlu' : '$additional ${_unit()}',
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFDCE8DC),
              ),
            ),
            child: Text(
              'Stok dihitung pada batas akhir histori '
              '${_formatDate(_historyEnd)}. Transaksi setelah tanggal '
              'tersebut tidak memengaruhi status dan saran prediksi.',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 10,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _predictionChart(
    _RegressionResult regression,
  ) {
    final points = regression.predictedDaily
        .map(
          (item) => _TrendPoint(
            label: _formatShortDate(item.date),
            value: item.qty.toDouble(),
            sourceIndex: 0,
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Grafik Prediksi 7 Hari',
          'Setiap titik menunjukkan estimasi stok keluar harian.',
        ),
        _card(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 270,
            child: CustomPaint(
              painter: _PredictionChartPainter(points),
            ),
          ),
        ),
      ],
    );
  }

  Widget _predictionDailyList(
    _RegressionResult regression,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Rincian Prediksi Harian',
          'Estimasi per tanggal.',
        ),
        ...regression.predictedDaily.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(item.date),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _chip(
                  '${item.qty} ${_unit()}',
                  Colors.deepPurple,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _forecastList(
    List<_ProductForecast> forecasts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Prediksi per Merek',
          'Rincian kebutuhan stok masing-masing produk.',
        ),
        ...forecasts.map((forecast) {
          final unit = forecast.product.unit.trim().isEmpty
              ? 'Karung'
              : forecast.product.unit.trim();

          final color = !forecast.hasEnoughData
              ? Colors.grey
              : forecast.additionalNeed > 0
                  ? Colors.red
                  : Colors.green;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        forecast.product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _chip(
                      !forecast.hasEnoughData
                          ? 'Data kurang'
                          : forecast.additionalNeed > 0
                              ? 'Restock'
                              : 'Aman',
                      color,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _resultRow(
                  'Hari Aktif',
                  '${forecast.activeDays} hari',
                ),
                _resultRow(
                  'Stok s.d. ${_formatDate(_historyEnd)}',
                  '${forecast.currentStockAsOf} $unit',
                ),
                _resultRow(
                  'Prediksi 7 Hari',
                  forecast.hasEnoughData
                      ? '${forecast.estimatedNeed} $unit'
                      : '-',
                ),
                _resultRow(
                  'Saran Tambahan',
                  !forecast.hasEnoughData
                      ? '-'
                      : forecast.additionalNeed == 0
                          ? 'Tidak perlu'
                          : '${forecast.additionalNeed} $unit',
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _dailyDataCard(
    _DailySeries series,
  ) {
    if (series.transactionCount == 0) {
      return const SizedBox.shrink();
    }

    final maxQty = series.points.fold<int>(
      0,
      (current, point) => math.max(
        current,
        point.qty,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Data Harian Stok Keluar',
          'Hari tanpa transaksi tetap ditampilkan dengan nilai 0.',
        ),
        _card(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 300,
            child: ListView.separated(
              itemCount: series.points.length,
              separatorBuilder: (_, __) {
                return const SizedBox(height: 7);
              },
              itemBuilder: (context, index) {
                final item = series.points[index];

                final ratio = maxQty == 0 ? 0.0 : item.qty / maxQty;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 58,
                        child: Text(
                          _formatShortDate(item.date),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: ratio
                              .clamp(
                                0.0,
                                1.0,
                              )
                              .toDouble(),
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 82,
                        child: Text(
                          '${item.qty} ${_unit()}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(
    String title,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E5E5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
        color: const Color(0xFF038E1B),
      ),
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF038E1B),
          width: 2,
        ),
      ),
    );
  }

  Widget _resultRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniSummary(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
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

  Widget _legend(
    Color color,
    String label,
    bool dashed,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 26,
          height: 8,
          child: CustomPaint(
            painter: _LegendPainter(
              color: color,
              dashed: dashed,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _infoCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message),
          ),
        ],
      ),
    );
  }

  Widget _errorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Gagal memuat transaksi: ${_cleanError(error)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.red.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _futureStockErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Gagal menghitung stok pada tanggal analisis: '
          '${_cleanError(error)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.red.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _DailyStockOut {
  final DateTime date;

  final int qty;

  const _DailyStockOut({
    required this.date,
    required this.qty,
  });
}

class _DailySeries {
  final List<_DailyStockOut> points;

  final int transactionCount;

  final int activeDays;

  final int totalQty;

  const _DailySeries({
    required this.points,
    required this.transactionCount,
    required this.activeDays,
    required this.totalQty,
  });
}

class _PredictedStockOut {
  final DateTime date;

  final int qty;

  const _PredictedStockOut({
    required this.date,
    required this.qty,
  });
}

class _RegressionResult {
  final double slope;

  final double intercept;

  final double rSquared;

  final double relativeSlopePercentPerDay;

  final _ValidationMetrics? validation;

  final int totalQty;

  final double averageQty;

  final int estimatedNext7Days;

  final List<_PredictedStockOut> predictedDaily;

  const _RegressionResult({
    required this.slope,
    required this.intercept,
    required this.rSquared,
    required this.relativeSlopePercentPerDay,
    required this.validation,
    required this.totalQty,
    required this.averageQty,
    required this.estimatedNext7Days,
    required this.predictedDaily,
  });
}

class _ValidationMetrics {
  final int windows;

  final int testDays;

  final int totalActual;

  final int totalPredicted;

  final double mae;

  final double rmse;

  final double wape;

  const _ValidationMetrics({
    required this.windows,
    required this.testDays,
    required this.totalActual,
    required this.totalPredicted,
    required this.mae,
    required this.rmse,
    required this.wape,
  });
}

class _LinearFit {
  final double slope;

  final double intercept;

  const _LinearFit({
    required this.slope,
    required this.intercept,
  });
}

class _ProductForecast {
  final ProductModel product;

  final int activeDays;

  final int currentStockAsOf;

  final int estimatedNeed;

  final int additionalNeed;

  final bool hasEnoughData;

  const _ProductForecast({
    required this.product,
    required this.activeDays,
    required this.currentStockAsOf,
    required this.estimatedNeed,
    required this.additionalNeed,
    required this.hasEnoughData,
  });
}

class _TrendPoint {
  final String label;

  final double value;

  final int sourceIndex;

  const _TrendPoint({
    required this.label,
    required this.value,
    required this.sourceIndex,
  });
}

class _LegendPainter extends CustomPainter {
  final Color color;

  final bool dashed;

  const _LegendPainter({
    required this.color,
    required this.dashed,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    if (!dashed) {
      canvas.drawLine(
        Offset(
          0,
          size.height / 2,
        ),
        Offset(
          size.width,
          size.height / 2,
        ),
        paint,
      );

      return;
    }

    var x = 0.0;

    while (x < size.width) {
      canvas.drawLine(
        Offset(
          x,
          size.height / 2,
        ),
        Offset(
          math.min(
            x + 6,
            size.width,
          ),
          size.height / 2,
        ),
        paint,
      );

      x += 10;
    }
  }

  @override
  bool shouldRepaint(
    covariant _LegendPainter oldDelegate,
  ) {
    return oldDelegate.color != color || oldDelegate.dashed != dashed;
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<_TrendPoint> points;

  final _RegressionResult regression;

  const _TrendChartPainter({
    required this.points,
    required this.regression,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (points.isEmpty) {
      return;
    }

    final rect = Rect.fromLTWH(
      44,
      18,
      math
          .max(
            1,
            size.width - 58,
          )
          .toDouble(),
      math
          .max(
            1,
            size.height - 66,
          )
          .toDouble(),
    );

    var maxValue = points.fold<double>(
      0,
      (current, point) {
        return math.max(
          current,
          point.value,
        );
      },
    );

    for (final point in points) {
      maxValue = math.max(
        maxValue,
        math.max(
          0,
          regression.intercept + regression.slope * point.sourceIndex,
        ),
      );
    }

    maxValue = maxValue <= 0 ? 1.0 : maxValue * 1.12;

    _drawGrid(
      canvas,
      rect,
      maxValue,
    );

    _drawVerticalGuides(
      canvas,
      rect,
      points.length,
    );

    _drawLabels(
      canvas,
      rect,
      points,
      showAll: true,
    );

    final actualOffsets = <Offset>[];

    final trendOffsets = <Offset>[];

    for (var index = 0; index < points.length; index++) {
      actualOffsets.add(
        _offset(
          index,
          points.length,
          points[index].value,
          maxValue,
          rect,
        ),
      );

      final trendValue = math.max(
        0,
        regression.intercept + regression.slope * points[index].sourceIndex,
      );

      trendOffsets.add(
        _offset(
          index,
          points.length,
          trendValue.toDouble(),
          maxValue,
          rect,
        ),
      );
    }

    _drawSolidPath(
      canvas,
      actualOffsets,
      const Color(0xFF038E1B),
    );

    _drawDashedPath(
      canvas,
      trendOffsets,
      Colors.orange.shade700,
    );

    final border = Paint()..color = Colors.white;

    final fill = Paint()..color = const Color(0xFF038E1B);

    for (final point in actualOffsets) {
      canvas.drawCircle(
        point,
        4.4,
        border,
      );

      canvas.drawCircle(
        point,
        3,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _TrendChartPainter oldDelegate,
  ) {
    return true;
  }
}

class _PredictionChartPainter extends CustomPainter {
  final List<_TrendPoint> points;

  const _PredictionChartPainter(this.points);

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (points.isEmpty) {
      return;
    }

    final rect = Rect.fromLTWH(
      44,
      18,
      math
          .max(
            1,
            size.width - 58,
          )
          .toDouble(),
      math
          .max(
            1,
            size.height - 58,
          )
          .toDouble(),
    );

    var maxValue = points.fold<double>(
      0,
      (current, point) {
        return math.max(
          current,
          point.value,
        );
      },
    );

    maxValue = maxValue <= 0 ? 1.0 : maxValue * 1.15;

    _drawGrid(
      canvas,
      rect,
      maxValue,
    );

    _drawLabels(
      canvas,
      rect,
      points,
      showAll: true,
    );

    final offsets = <Offset>[];

    for (var index = 0; index < points.length; index++) {
      offsets.add(
        _offset(
          index,
          points.length,
          points[index].value,
          maxValue,
          rect,
        ),
      );
    }

    _drawSolidPath(
      canvas,
      offsets,
      Colors.deepPurple.shade500,
    );

    final paint = Paint()..color = Colors.deepPurple.shade500;

    for (final point in offsets) {
      canvas.drawCircle(
        point,
        3.4,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _PredictionChartPainter oldDelegate,
  ) {
    return true;
  }
}

Offset _offset(
  int index,
  int total,
  double value,
  double maxValue,
  Rect rect,
) {
  final xRatio = total <= 1 ? 0.5 : index / (total - 1);

  final yRatio = (value / maxValue)
      .clamp(
        0.0,
        1.0,
      )
      .toDouble();

  return Offset(
    rect.left + rect.width * xRatio,
    rect.bottom - rect.height * yRatio,
  );
}

void _drawGrid(
  Canvas canvas,
  Rect rect,
  double maxValue,
) {
  final paint = Paint()
    ..color = Colors.black.withOpacity(0.11)
    ..strokeWidth = 1;

  for (var index = 0; index <= 4; index++) {
    final ratio = index / 4;

    final y = rect.bottom - rect.height * ratio;

    canvas.drawLine(
      Offset(rect.left, y),
      Offset(rect.right, y),
      paint,
    );

    final text = TextPainter(
      text: TextSpan(
        text: '${(maxValue * ratio).round()}',
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 9,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    text.paint(
      canvas,
      Offset(
        rect.left - text.width - 6,
        y - text.height / 2,
      ),
    );
  }
}

void _drawVerticalGuides(
  Canvas canvas,
  Rect rect,
  int count,
) {
  final paint = Paint()
    ..color = Colors.black.withOpacity(0.055)
    ..strokeWidth = 1;

  for (var index = 0; index < count; index++) {
    final ratio = count <= 1 ? 0.5 : index / (count - 1);

    final x = rect.left + rect.width * ratio;

    canvas.drawLine(
      Offset(x, rect.top),
      Offset(x, rect.bottom),
      paint,
    );
  }
}

void _drawLabels(
  Canvas canvas,
  Rect rect,
  List<_TrendPoint> points, {
  required bool showAll,
}) {
  final indexes = <int>{};

  if (showAll || points.length <= 7) {
    for (var index = 0; index < points.length; index++) {
      indexes.add(index);
    }
  } else {
    for (var index = 0; index < 6; index++) {
      indexes.add(
        ((points.length - 1) * index / 5).round(),
      );
    }
  }

  for (final index in indexes) {
    final ratio = points.length <= 1 ? 0.5 : index / (points.length - 1);

    final x = rect.left + rect.width * ratio;

    final text = TextPainter(
      text: TextSpan(
        text: points[index].label,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(
        maxWidth: 44,
      );

    final left = (x - text.width / 2).clamp(
      rect.left - 8,
      rect.right - text.width + 8,
    );

    text.paint(
      canvas,
      Offset(
        left.toDouble(),
        rect.bottom + 7,
      ),
    );
  }
}

void _drawSolidPath(
  Canvas canvas,
  List<Offset> points,
  Color color,
) {
  if (points.isEmpty) {
    return;
  }

  final path = Path()
    ..moveTo(
      points.first.dx,
      points.first.dy,
    );

  for (final point in points.skip(1)) {
    path.lineTo(
      point.dx,
      point.dy,
    );
  }

  canvas.drawPath(
    path,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

void _drawDashedPath(
  Canvas canvas,
  List<Offset> points,
  Color color,
) {
  if (points.length < 2) {
    return;
  }

  final paint = Paint()
    ..color = color
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;

  for (var index = 0; index < points.length - 1; index++) {
    final start = points[index];

    final end = points[index + 1];

    final delta = end - start;

    final distance = delta.distance;

    if (distance == 0) {
      continue;
    }

    final direction = delta / distance;

    var travelled = 0.0;

    while (travelled < distance) {
      final dashEnd = math.min(
        travelled + 7,
        distance,
      );

      canvas.drawLine(
        start + direction * travelled,
        start + direction * dashEnd,
        paint,
      );

      travelled += 12;
    }
  }
}
