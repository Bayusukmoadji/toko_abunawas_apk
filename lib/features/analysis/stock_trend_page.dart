import 'package:flutter/material.dart';
import '../../data/models/product_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class StockTrendPage extends StatefulWidget {
  const StockTrendPage({super.key});

  @override
  State<StockTrendPage> createState() => _StockTrendPageState();
}

class _StockTrendPageState extends State<StockTrendPage> {
  final ProductRepository _productRepository = ProductRepository();
  final TransactionRepository _transactionRepository = TransactionRepository();

  List<ProductModel> _products = [];
  String? _selectedProductId;
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
        _selectedProductId = products.isNotEmpty ? products.first.id : null;
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String _getSelectedProductName() {
    if (_selectedProductId == null) {
      return '-';
    }

    final matchedProducts = _products.where(
      (product) => product.id == _selectedProductId,
    );

    if (matchedProducts.isEmpty) {
      return '-';
    }

    return matchedProducts.first.name;
  }

  List<_DailyStockOut> _buildDailyStockOutData(
    List<TransactionModel> transactions,
  ) {
    final Map<String, _DailyStockOut> dailyMap = {};

    final stockOutTransactions = transactions.where((transaction) {
      return transaction.type == 'stock_out' &&
          transaction.productId == _selectedProductId;
    }).toList();

    for (final transaction in stockOutTransactions) {
      final dateTime = transaction.createdAt.toDate();

      final dateOnly = DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
      );

      final key = '${dateOnly.year}-${dateOnly.month}-${dateOnly.day}';

      if (!dailyMap.containsKey(key)) {
        dailyMap[key] = _DailyStockOut(
          date: dateOnly,
          qty: 0,
        );
      }

      dailyMap[key] = _DailyStockOut(
        date: dateOnly,
        qty: dailyMap[key]!.qty + transaction.qty,
      );
    }

    final dailyData = dailyMap.values.toList();

    dailyData.sort((a, b) => a.date.compareTo(b.date));

    return dailyData;
  }

  _RegressionResult? _calculateLinearRegression(List<_DailyStockOut> data) {
    if (data.length < 3) {
      return null;
    }

    final n = data.length;

    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;

    for (int i = 0; i < n; i++) {
      final x = i.toDouble();
      final y = data[i].qty.toDouble();

      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    final denominator = (n * sumX2) - (sumX * sumX);

    if (denominator == 0) {
      return null;
    }

    final slope = ((n * sumXY) - (sumX * sumY)) / denominator;
    final intercept = (sumY - (slope * sumX)) / n;

    double estimatedNext7Days = 0;

    for (int i = n; i < n + 7; i++) {
      final prediction = intercept + (slope * i);
      estimatedNext7Days += prediction < 0 ? 0 : prediction;
    }

    String trendStatus;

    if (slope > 0.1) {
      trendStatus = 'Pengeluaran stok cenderung meningkat.';
    } else if (slope < -0.1) {
      trendStatus = 'Pengeluaran stok cenderung menurun.';
    } else {
      trendStatus = 'Pengeluaran stok relatif stabil.';
    }

    final totalQty = data.fold<int>(
      0,
      (total, item) => total + item.qty,
    );

    final averageQty = totalQty / data.length;

    return _RegressionResult(
      slope: slope,
      intercept: intercept,
      trendStatus: trendStatus,
      totalQty: totalQty,
      averageQty: averageQty,
      estimatedNext7Days: estimatedNext7Days,
    );
  }

  Widget _buildProductFilter() {
    if (_products.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Belum ada produk aktif untuk dianalisis.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DropdownButtonFormField<String>(
          value: _selectedProductId,
          decoration: const InputDecoration(
            labelText: 'Pilih Produk / Merk Beras',
            border: OutlineInputBorder(),
          ),
          items: _products.map((product) {
            return DropdownMenuItem<String>(
              value: product.id,
              child: Text(product.name),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedProductId = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildAnalysisResult({
    required List<_DailyStockOut> dailyData,
    required _RegressionResult? result,
  }) {
    if (_selectedProductId == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Silakan pilih produk terlebih dahulu.'),
        ),
      );
    }

    if (dailyData.length < 3 || result == null) {
      return Card(
        color: Colors.orange.shade50,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Data transaksi keluar belum mencukupi untuk analisis tren. '
            'Minimal diperlukan 3 hari data transaksi stok keluar untuk produk yang dipilih.',
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hasil Analisis Linear Regression',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text('Produk: ${_getSelectedProductName()}'),
            Text('Jumlah data harian: ${dailyData.length} hari'),
            Text('Total stok keluar: ${result.totalQty} karung'),
            Text(
              'Rata-rata stok keluar per hari: ${result.averageQty.toStringAsFixed(2)} karung',
            ),
            Text(
              'Nilai slope: ${result.slope.toStringAsFixed(3)}',
            ),
            const SizedBox(height: 12),
            Text(
              result.trendStatus,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Estimasi kebutuhan 7 hari ke depan: '
              '${result.estimatedNext7Days.toStringAsFixed(0)} karung',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Catatan: hasil ini merupakan analisis pendukung sederhana '
              'berdasarkan data transaksi stok keluar historis, bukan keputusan otomatis.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyDataList(List<_DailyStockOut> dailyData) {
    if (dailyData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Belum ada transaksi stok keluar untuk produk yang dipilih.',
          ),
        ),
      );
    }

    return Column(
      children: dailyData.map((item) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(_formatDate(item.date)),
            subtitle: Text('Stok keluar: ${item.qty} karung'),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProducts) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analisis Tren Stok'),
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _transactionRepository.getTransactionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Gagal memuat transaksi: ${snapshot.error}'),
            );
          }

          final transactions = snapshot.data ?? [];
          final dailyData = _buildDailyStockOutData(transactions);
          final regressionResult = _calculateLinearRegression(dailyData);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProductFilter(),
                    const SizedBox(height: 16),
                    _buildAnalysisResult(
                      dailyData: dailyData,
                      result: regressionResult,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Data Harian Stok Keluar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDailyDataList(dailyData),
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

class _DailyStockOut {
  final DateTime date;
  final int qty;

  _DailyStockOut({
    required this.date,
    required this.qty,
  });
}

class _RegressionResult {
  final double slope;
  final double intercept;
  final String trendStatus;
  final int totalQty;
  final double averageQty;
  final double estimatedNext7Days;

  _RegressionResult({
    required this.slope,
    required this.intercept,
    required this.trendStatus,
    required this.totalQty,
    required this.averageQty,
    required this.estimatedNext7Days,
  });
}
