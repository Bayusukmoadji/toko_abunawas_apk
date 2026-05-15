import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/models/app_user_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/batch_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class StockInPage extends StatefulWidget {
  final AppUserModel user;

  const StockInPage({
    super.key,
    required this.user,
  });

  @override
  State<StockInPage> createState() => _StockInPageState();
}

class _StockInPageState extends State<StockInPage> {
  final _qtyController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  final ProductRepository _productRepository = ProductRepository();
  final BatchRepository _batchRepository = BatchRepository();
  final TransactionRepository _transactionRepository = TransactionRepository();

  List<ProductModel> _products = [];
  ProductModel? _selectedProduct;
  DateTime _selectedDate = DateTime.now();

  bool _isLoadingProducts = true;
  bool _isSubmitting = false;

  // --- STATE UNTUK VALIDASI KUSTOM (ERROR DI SAMPING) ---
  bool _hasErrorProduct = false;
  bool _hasErrorQty = false;
  bool _hasErrorLocation = false;

  // --- KUNCIAN PARAMETER VISUAL ---

  final BoxShadow figmaStrictShadow = BoxShadow(
    color: Colors.black.withOpacity(0.25),
    offset: const Offset(3.0, 3.0),
    blurRadius: 5.0,
    spreadRadius: -1.0,
  );

  final BoxShadow cardFormShadow = BoxShadow(
    color: Colors.black.withOpacity(0.32),
    offset: const Offset(1, 2),
    blurRadius: 4,
  );

  final LinearGradient primaryGradient = const LinearGradient(
    colors: [Color(0xFF84E977), Color(0xFF038E1B), Color(0xFF015816)],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final TextStyle fieldTextStyle = const TextStyle(
    color: Color(0xFF015816),
    fontWeight: FontWeight.w600,
    fontSize: 13.5,
  );

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _locationController.dispose();
    _notesController.dispose();
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
      setState(() => _isLoadingProducts = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // --- CUSTOM DATE PICKER THEME (GLASSY & GRADIENT) ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF038E1B),
              onPrimary: Colors.white,
              onSurface: Color(0xFF015816),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF015816),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // --- LOGIKA SIMPAN & ALERT ---
  Future<void> _saveStockIn() async {
    // 1. Validasi Manual
    setState(() {
      _hasErrorProduct = _selectedProduct == null;
      _hasErrorQty = _qtyController.text.trim().isEmpty;
      _hasErrorLocation = _locationController.text.trim().isEmpty;
    });

    // Cegah proses jika ada error
    if (_hasErrorProduct || _hasErrorQty || _hasErrorLocation) return;

    setState(() => _isSubmitting = true);

    try {
      final qty = int.parse(_qtyController.text.trim());
      final batchResult = await _batchRepository.createBatch(
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        receivedAt: _selectedDate,
        qty: qty,
        unit: _selectedProduct!.unit,
        storageLocation: _locationController.text.trim(),
        createdBy: widget.user.uid,
        createdByName: widget.user.name,
        notes: _notesController.text.trim(),
      );

      await _productRepository.increaseTotalStock(
          productId: _selectedProduct!.id, qty: qty);
      await _transactionRepository.createStockInTransaction(
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        batchId: batchResult['batchId']!,
        batchCode: batchResult['batchCode']!,
        qty: qty,
        unit: _selectedProduct!.unit,
        performedBy: widget.user.uid,
        performedByName: widget.user.name,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      // Bersihkan Form
      _qtyController.clear();
      _locationController.clear();
      _notesController.clear();
      setState(() {
        _selectedProduct = null;
        _selectedDate = DateTime.now();
      });

      // 2. Tampilkan Alert Sukses (Linter Fix: menggunakan const Row)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Stok berhasil ditambahkan!',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF038E1B),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildSvgWrapper(
      {required String svgPath, required Widget child, double height = 48}) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              svgPath,
              fit: BoxFit.fill,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: child,
          ),
        ],
      ),
    );
  }

  // --- KUSTOMISASI DEKORASI DENGAN ALERT DI SAMPING ---
  InputDecoration _customFieldDecoration(String hint,
      {Widget? suffixIcon, String? suffixText, bool hasError = false}) {
    Widget? combinedSuffix;

    if (hasError || suffixIcon != null || suffixText != null) {
      combinedSuffix = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasError)
            const Padding(
              padding: EdgeInsets.only(right: 12.0),
              child: Text('Wajib isi *',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic)),
            ),
          if (suffixText != null)
            Padding(
              padding: EdgeInsets.only(right: suffixIcon != null ? 8.0 : 0),
              child: Text(suffixText,
                  style: fieldTextStyle.copyWith(
                      fontSize: 13, color: const Color(0xFF015816))),
            ),
          if (suffixIcon != null) suffixIcon,
        ],
      );
    }

    return InputDecoration(
      hintText: hint,
      hintStyle: fieldTextStyle.copyWith(
          color: hasError
              ? Colors.red.withOpacity(0.7)
              : const Color(0xFF015816).withOpacity(0.5)),
      contentPadding: EdgeInsets.zero,
      border: InputBorder.none,
      suffixIcon: combinedSuffix != null
          ? Padding(
              padding: const EdgeInsets.only(right: 0), child: combinedSuffix)
          : null,
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProducts) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER ---
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  height: 112,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 40),
                  decoration: BoxDecoration(
                    gradient: primaryGradient,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(32)),
                    boxShadow: [figmaStrictShadow],
                  ),
                  child: SafeArea(
                    child: Transform.translate(
                      offset: const Offset(0, -15),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_double_arrow_left,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Text(
                              'STOK MASUK',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 5,
                  left: 16,
                  right: 16,
                  child: SvgPicture.asset(
                    'assets/stockin/info.svg',
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // --- FORM ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [cardFormShadow],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Form Input Stok Masuk',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lengkapi data produk, jumlah stok, lokasi penyimpanan,\ndan tanggal masuk.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.black.withOpacity(0.6),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // PILIH PRODUK
                    _buildSvgWrapper(
                      svgPath: 'assets/stockin/recm.svg',
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ProductModel>(
                          isExpanded: true,
                          value: _selectedProduct,
                          icon: const SizedBox.shrink(),
                          hint: _customFieldDecoration(
                                    'Pilih Produk',
                                    suffixIcon: const Icon(
                                        Icons.arrow_drop_down,
                                        color: Color(0xFF015816)),
                                    hasError: _hasErrorProduct,
                                  ).hintText !=
                                  null
                              ? TextField(
                                  enabled: false,
                                  decoration: _customFieldDecoration(
                                    'Pilih Produk',
                                    suffixIcon: const Icon(
                                        Icons.arrow_drop_down,
                                        color: Color(0xFF015816)),
                                    hasError: _hasErrorProduct,
                                  ),
                                )
                              : const SizedBox(),
                          selectedItemBuilder: (BuildContext context) {
                            return _products.map<Widget>((ProductModel item) {
                              return Row(
                                children: [
                                  Expanded(
                                      child: Text(item.name,
                                          style: fieldTextStyle)),
                                  const Icon(Icons.arrow_drop_down,
                                      color: Color(0xFF015816)),
                                ],
                              );
                            }).toList();
                          },
                          items: _products
                              .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p.name, style: fieldTextStyle)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedProduct = v;
                              if (_hasErrorProduct) _hasErrorProduct = false;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // JUMLAH STOK
                    _buildSvgWrapper(
                      svgPath: 'assets/stockin/recm.svg',
                      child: TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.left,
                        style: fieldTextStyle,
                        decoration: _customFieldDecoration(
                          'Jumlah Stok Masuk',
                          suffixText:
                              _qtyController.text.isNotEmpty ? 'karung' : null,
                          hasError: _hasErrorQty,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _hasErrorQty = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // LOKASI
                    _buildSvgWrapper(
                      svgPath: 'assets/stockin/recm.svg',
                      child: TextField(
                        controller: _locationController,
                        textAlign: TextAlign.left,
                        style: fieldTextStyle,
                        decoration: _customFieldDecoration(
                          'Lokasi Batch di Gudang',
                          hasError: _hasErrorLocation,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _hasErrorLocation = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // TANGGAL
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: _buildSvgWrapper(
                        svgPath: 'assets/stockin/recm.svg',
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Tanggal Masuk : ${_formatDate(_selectedDate)}',
                                textAlign: TextAlign.left,
                                style: fieldTextStyle,
                              ),
                            ),
                            const Icon(Icons.calendar_month_outlined,
                                color: Color(0xFF015816), size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // CATATAN
                    _buildSvgWrapper(
                      svgPath: 'assets/stockin/recb.svg',
                      height: 100,
                      child: TextField(
                        controller: _notesController,
                        textAlign: TextAlign.left,
                        maxLines: 3,
                        style: fieldTextStyle,
                        decoration: _customFieldDecoration('Catatan...'),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // TOMBOL SIMPAN
                    Center(
                      child: GestureDetector(
                        onTap: _isSubmitting ? null : _saveStockIn,
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [figmaStrictShadow],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isSubmitting)
                                const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                              else ...[
                                const Icon(Icons.save_outlined,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                const Text(
                                  'Simpan',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
