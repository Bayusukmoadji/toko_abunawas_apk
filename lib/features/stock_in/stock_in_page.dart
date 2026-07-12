import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _notesController = TextEditingController();
  final _optionalLocationController = TextEditingController();

  final ProductRepository _productRepository = ProductRepository();
  final BatchRepository _batchRepository = BatchRepository();
  final TransactionRepository _transactionRepository = TransactionRepository();

  final List<String> _storageLocations = const [
    'A1',
    'A2',
    'A3',
    'A4',
    'A5',
    'A6',
    'A7',
    'A8',
    'A9',
    'A10',
    'B1',
    'B2',
    'B3',
    'B4',
    'B5',
    'B6',
    'B7',
    'B8',
    'B9',
    'B10',
    'C1',
    'C2',
    'C3',
    'C4',
    'C5',
    'C6',
    'C7',
    'C8',
    'C9',
    'C10',
    'D1',
    'D2',
    'D3',
    'D4',
    'D5',
  ];

  List<ProductModel> _products = [];
  ProductModel? _selectedProduct;
  String? _selectedLocation;
  DateTime _selectedDate = DateTime.now();

  Set<String> _occupiedLocations = {};

  bool _isLoadingProducts = true;
  bool _isLoadingLocations = true;
  bool _isSubmitting = false;

  bool _hasErrorProduct = false;
  bool _hasErrorQty = false;
  bool _hasErrorLocation = false;

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
    _loadOccupiedLocations();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    _optionalLocationController.dispose();
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

      _showFloatingSnackBar(
        'Gagal memuat produk: $e',
        Colors.redAccent,
      );
    }
  }

  Future<void> _loadOccupiedLocations({bool silent = false}) async {
    try {
      if (!silent && mounted) {
        setState(() {
          _isLoadingLocations = true;
        });
      }

      final occupiedLocations =
          await _batchRepository.getOccupiedStorageLocations();

      if (!mounted) return;

      setState(() {
        _occupiedLocations = occupiedLocations;
        _isLoadingLocations = false;

        final selected = _selectedLocation?.trim().toUpperCase() ?? '';

        if (_storageLocations.contains(selected) &&
            _occupiedLocations.contains(selected)) {
          _selectedLocation = null;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingLocations = false;
      });

      _showFloatingSnackBar(
        'Gagal memuat status lokasi: $e',
        Colors.redAccent,
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _normalizeLocation(String value) {
    return value.trim().toUpperCase();
  }

  bool _isLocationOccupied(String location) {
    return _occupiedLocations.contains(_normalizeLocation(location));
  }

  bool get _isAllStandardLocationsOccupied {
    return _storageLocations.every(_isLocationOccupied);
  }

  String _getSelectedLocationText() {
    final location = _selectedLocation?.trim();

    if (location != null && location.isNotEmpty) {
      return location.toUpperCase();
    }

    if (_isLoadingLocations) {
      return 'Memuat lokasi...';
    }

    if (_isAllStandardLocationsOccupied) {
      return 'Semua lokasi penuh, isi lokasi opsional';
    }

    return 'Pilih Lokasi Tumpukan';
  }

  String _getFinalLocation() {
    final selectedLocation = _selectedLocation?.trim() ?? '';

    if (selectedLocation.isNotEmpty) {
      return _normalizeLocation(selectedLocation);
    }

    if (_isAllStandardLocationsOccupied) {
      return _normalizeLocation(_optionalLocationController.text);
    }

    return '';
  }

  void _showFloatingSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.redAccent
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

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

  Future<void> _saveStockIn() async {
    final qtyText = _qtyController.text.trim();
    final notesText = _notesController.text.trim();
    final qty = int.tryParse(qtyText);
    final finalLocation = _getFinalLocation();

    setState(() {
      _hasErrorProduct = _selectedProduct == null;
      _hasErrorQty = qtyText.isEmpty || qty == null || qty <= 0;
      _hasErrorLocation = finalLocation.isEmpty;
    });

    if (_hasErrorProduct || _hasErrorQty || _hasErrorLocation) {
      if (_hasErrorProduct) {
        _showFloatingSnackBar(
          'Produk wajib dipilih.',
          Colors.redAccent,
        );
      } else if (_hasErrorQty && qtyText.isNotEmpty) {
        _showFloatingSnackBar(
          'Jumlah stok harus berupa angka lebih dari 0.',
          Colors.redAccent,
        );
      } else if (_hasErrorLocation) {
        _showFloatingSnackBar(
          'Lokasi tumpukan wajib dipilih atau diisi.',
          Colors.redAccent,
        );
      }

      return;
    }

    final selectedProduct = _selectedProduct!;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final latestOccupiedLocations =
          await _batchRepository.getOccupiedStorageLocations();

      final isStandardLocation = _storageLocations.contains(finalLocation);

      if (isStandardLocation &&
          latestOccupiedLocations.contains(finalLocation)) {
        throw Exception(
          'Lokasi $finalLocation sudah terisi batch aktif. Pilih lokasi lain.',
        );
      }

      final batchResult = await _batchRepository.createBatch(
        productId: selectedProduct.id,
        productCode: selectedProduct.code,
        productName: selectedProduct.name,
        receivedAt: _selectedDate,
        qty: qty!,
        unit: selectedProduct.unit,
        storageLocation: finalLocation,
        createdBy: widget.user.uid,
        createdByName: widget.user.name,
        notes: notesText,
      );

      await _productRepository.increaseTotalStock(
        productId: selectedProduct.id,
        qty: qty,
      );

      await _transactionRepository.createStockInTransaction(
        productId: selectedProduct.id,
        productName: selectedProduct.name,
        batchId: batchResult['batchId']!,
        batchCode: batchResult['batchCode']!,
        qty: qty,
        unit: selectedProduct.unit,
        performedBy: widget.user.uid,
        performedByName: widget.user.name,
        notes: notesText,
      );

      await _productRepository.syncTotalStockFromBatches(
        productId: selectedProduct.id,
      );

      if (!mounted) return;

      final generatedBatchCode = batchResult['batchCode'] ?? 'batch baru';

      _qtyController.clear();
      _notesController.clear();
      _optionalLocationController.clear();

      setState(() {
        _selectedProduct = null;
        _selectedLocation = null;
        _selectedDate = DateTime.now();
        _hasErrorProduct = false;
        _hasErrorQty = false;
        _hasErrorLocation = false;
      });

      await _loadOccupiedLocations(silent: true);

      _showFloatingSnackBar(
        'Stok berhasil ditambahkan. Kode: $generatedBatchCode',
        const Color(0xFF038E1B),
      );
    } catch (e) {
      if (!mounted) return;

      _showFloatingSnackBar(
        'Gagal menambahkan stok: $e',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildSvgWrapper({
    required String svgPath,
    required Widget child,
    double height = 48,
  }) {
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

  InputDecoration _customFieldDecoration(
    String hint, {
    Widget? suffixIcon,
    String? suffixText,
    bool hasError = false,
  }) {
    Widget? combinedSuffix;

    if (hasError || suffixIcon != null || suffixText != null) {
      combinedSuffix = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasError)
            const Padding(
              padding: EdgeInsets.only(right: 12.0),
              child: Text(
                'Wajib isi *',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (suffixText != null)
            Padding(
              padding: EdgeInsets.only(right: suffixIcon != null ? 8.0 : 0),
              child: Text(
                suffixText,
                style: fieldTextStyle.copyWith(
                  fontSize: 13,
                  color: const Color(0xFF015816),
                ),
              ),
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
            : const Color(0xFF015816).withOpacity(0.5),
      ),
      contentPadding: EdgeInsets.zero,
      border: InputBorder.none,
      suffixIcon: combinedSuffix != null
          ? Padding(
              padding: const EdgeInsets.only(right: 0),
              child: combinedSuffix,
            )
          : null,
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    );
  }

  Widget _buildLocationBox({
    required String location,
    required bool isSelected,
    required bool isOccupied,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isOccupied ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 52,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [
                    Color(0xFF84E977),
                    Color(0xFF038E1B),
                    Color(0xFF015816),
                  ],
                  stops: [0.0, 0.5, 1.0],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : isOccupied
                  ? Colors.grey.shade200
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF038E1B)
                : isOccupied
                    ? Colors.grey.shade300
                    : const Color(0xFFDADADA),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          location,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Colors.white
                : isOccupied
                    ? Colors.black38
                    : const Color(0xFF015816),
          ),
        ),
      ),
    );
  }

  void _showLocationPickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allLocationsFull = _isAllStandardLocationsOccupied;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.88,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 46,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Pilih Lokasi Tumpukan',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Muat ulang lokasi',
                              onPressed: () async {
                                await _loadOccupiedLocations(silent: true);
                                if (mounted) {
                                  setModalState(() {});
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Kotak abu-abu berarti lokasi sedang dipakai oleh batch aktif. Lokasi akan tersedia kembali ketika batch habis.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _storageLocations.map((location) {
                            final normalizedLocation =
                                _normalizeLocation(location);
                            final isSelected =
                                _normalizeLocation(_selectedLocation ?? '') ==
                                    normalizedLocation;
                            final isOccupied =
                                _isLocationOccupied(normalizedLocation);

                            return _buildLocationBox(
                              location: location,
                              isSelected: isSelected,
                              isOccupied: isOccupied,
                              onTap: () {
                                setState(() {
                                  _selectedLocation = normalizedLocation;
                                  _optionalLocationController.clear();
                                  _hasErrorLocation = false;
                                });

                                setModalState(() {});
                                Navigator.pop(context);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildMiniLegend(
                              color: const Color(0xFF038E1B),
                              text: 'Dipilih',
                            ),
                            const SizedBox(width: 12),
                            _buildMiniLegend(
                              color: Colors.white,
                              borderColor: const Color(0xFFDADADA),
                              text: 'Kosong',
                            ),
                            const SizedBox(width: 12),
                            _buildMiniLegend(
                              color: Colors.grey.shade200,
                              borderColor: Colors.grey.shade300,
                              text: 'Terisi',
                            ),
                          ],
                        ),
                        if (allLocationsFull) ...[
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.orange.shade200,
                              ),
                            ),
                            child: const Text(
                              'Semua lokasi standar A1-D5 sedang penuh. Isi lokasi opsional sementara di bawah ini.',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _optionalLocationController,
                            textCapitalization: TextCapitalization.characters,
                            style: fieldTextStyle,
                            decoration: InputDecoration(
                              labelText: 'Lokasi Opsional',
                              hintText: 'Contoh: E1 atau Area Sementara 1',
                              labelStyle: const TextStyle(
                                color: Color(0xFF015816),
                                fontWeight: FontWeight.bold,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDADADA),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFF038E1B),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF038E1B),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                final optionalLocation = _normalizeLocation(
                                  _optionalLocationController.text,
                                );

                                if (optionalLocation.isEmpty) {
                                  _showFloatingSnackBar(
                                    'Lokasi opsional wajib diisi.',
                                    Colors.redAccent,
                                  );
                                  return;
                                }

                                setState(() {
                                  _selectedLocation = optionalLocation;
                                  _hasErrorLocation = false;
                                });

                                setModalState(() {});
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Gunakan Lokasi Opsional',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
          },
        );
      },
    );
  }

  Widget _buildMiniLegend({
    required Color color,
    required String text,
    Color? borderColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: borderColor ?? color,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10.5,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSelector() {
    return _buildSvgWrapper(
      svgPath: 'assets/stockin/recm.svg',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoadingLocations ? null : _showLocationPickerBottomSheet,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _getSelectedLocationText(),
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: fieldTextStyle.copyWith(
                    color: _hasErrorLocation
                        ? Colors.red
                        : const Color(0xFF015816),
                  ),
                ),
              ),
              if (_hasErrorLocation)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Text(
                    'Wajib isi *',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              Icon(
                Icons.grid_view_rounded,
                color: _hasErrorLocation ? Colors.red : const Color(0xFF015816),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProducts) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF038E1B),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
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
                      bottom: Radius.circular(32),
                    ),
                    boxShadow: [figmaStrictShadow],
                  ),
                  child: SafeArea(
                    child: Transform.translate(
                      offset: const Offset(0, -15),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.keyboard_double_arrow_left,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Text(
                              'STOK MASUK',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
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
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lengkapi data produk, jumlah stok, lokasi tumpukan,\ndan tanggal masuk.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.black.withOpacity(0.6),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSvgWrapper(
                      svgPath: 'assets/stockin/recm.svg',
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ProductModel>(
                          isExpanded: true,
                          value: _selectedProduct,
                          icon: const SizedBox.shrink(),
                          hint: TextField(
                            enabled: false,
                            decoration: _customFieldDecoration(
                              'Pilih Produk',
                              suffixIcon: const Icon(
                                Icons.arrow_drop_down,
                                color: Color(0xFF015816),
                              ),
                              hasError: _hasErrorProduct,
                            ),
                          ),
                          selectedItemBuilder: (BuildContext context) {
                            return _products.map<Widget>((ProductModel item) {
                              return Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: fieldTextStyle,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: Color(0xFF015816),
                                  ),
                                ],
                              );
                            }).toList();
                          },
                          items: _products.map((p) {
                            return DropdownMenuItem<ProductModel>(
                              value: p,
                              child: Text(
                                p.name,
                                style: fieldTextStyle,
                              ),
                            );
                          }).toList(),
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
                    _buildSvgWrapper(
                      svgPath: 'assets/stockin/recm.svg',
                      child: TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
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
                    _buildLocationSelector(),
                    const SizedBox(height: 14),
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
                            const Icon(
                              Icons.calendar_month_outlined,
                              color: Color(0xFF015816),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
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
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              else ...[
                                const Icon(
                                  Icons.save_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Simpan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
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
