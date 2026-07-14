import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/models/app_user_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/batch_repository.dart';
import '../../data/repositories/product_repository.dart';

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
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final ProductRepository _productRepository = ProductRepository();
  final BatchRepository _batchRepository = BatchRepository();

  final List<String> _mainStorageLocations = const [
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

  final List<String> _backupStorageLocations = const [
    'X1',
    'X2',
    'X3',
    'X4',
    'X5',
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
    offset: const Offset(3, 3),
    blurRadius: 5,
    spreadRadius: -1,
  );

  final BoxShadow cardFormShadow = BoxShadow(
    color: Colors.black.withOpacity(0.32),
    offset: const Offset(1, 2),
    blurRadius: 4,
  );

  final LinearGradient primaryGradient = const LinearGradient(
    colors: [
      Color(0xFF84E977),
      Color(0xFF038E1B),
      Color(0xFF015816),
    ],
    stops: [0, 0.5, 1],
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
    super.dispose();
  }

  String _normalizeLocation(String value) {
    return value.trim().toUpperCase();
  }

  bool _isLocationOccupied(String location) {
    return _occupiedLocations.contains(
      _normalizeLocation(location),
    );
  }

  bool _isMainLocation(String location) {
    return _mainStorageLocations.contains(
      _normalizeLocation(location),
    );
  }

  bool _isBackupLocation(String location) {
    return _backupStorageLocations.contains(
      _normalizeLocation(location),
    );
  }

  bool get _areAllMainLocationsOccupied {
    return _mainStorageLocations.every(_isLocationOccupied);
  }

  bool get _areAllBackupLocationsOccupied {
    return _backupStorageLocations.every(_isLocationOccupied);
  }

  bool get _areAllLocationsOccupied {
    return _areAllMainLocationsOccupied && _areAllBackupLocationsOccupied;
  }

  List<String> get _visibleStorageLocations {
    if (_areAllMainLocationsOccupied) {
      return _backupStorageLocations;
    }

    return _mainStorageLocations;
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _productRepository.getActiveProducts();

      if (!mounted) {
        return;
      }

      setState(() {
        _products = products;
        _isLoadingProducts = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingProducts = false;
      });

      _showFloatingSnackBar(
        'Gagal memuat produk: $e',
        Colors.redAccent,
      );
    }
  }

  Future<void> _loadOccupiedLocations({
    bool silent = false,
  }) async {
    try {
      if (!silent && mounted) {
        setState(() {
          _isLoadingLocations = true;
        });
      }

      final occupiedLocations =
          await _batchRepository.getOccupiedStorageLocations();

      if (!mounted) {
        return;
      }

      final normalizedLocations = occupiedLocations
          .map(_normalizeLocation)
          .where((location) => location.isNotEmpty)
          .toSet();

      setState(() {
        _occupiedLocations = normalizedLocations;
        _isLoadingLocations = false;

        final currentSelectedLocation =
            _normalizeLocation(_selectedLocation ?? '');

        if (currentSelectedLocation.isNotEmpty &&
            _occupiedLocations.contains(currentSelectedLocation)) {
          _selectedLocation = null;
        }

        if (currentSelectedLocation.isNotEmpty &&
            _isBackupLocation(currentSelectedLocation) &&
            !_areAllMainLocationsOccupied) {
          _selectedLocation = null;
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

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
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _getSelectedLocationText() {
    final selectedLocation = _normalizeLocation(_selectedLocation ?? '');

    if (selectedLocation.isNotEmpty) {
      return selectedLocation;
    }

    if (_isLoadingLocations) {
      return 'Memuat lokasi...';
    }

    if (_areAllLocationsOccupied) {
      return 'Seluruh lokasi penyimpanan penuh';
    }

    if (_areAllMainLocationsOccupied) {
      return 'Pilih Lokasi Belakang Gudang';
    }

    return 'Pilih Lokasi Dalam Gudang';
  }

  String _getLocationPickerTitle() {
    if (_areAllMainLocationsOccupied) {
      return 'Pilih Lokasi Belakang Gudang';
    }

    return 'Pilih Lokasi Dalam Gudang';
  }

  String _getLocationPickerDescription() {
    if (_areAllMainLocationsOccupied) {
      return 'Seluruh tumpukan di dalam gudang sedang penuh. '
          'Pilih lokasi cadangan X1-X5 di belakang gudang.';
    }

    return 'Pilih salah satu tumpukan kosong A1-A10, B1-B10, '
        'C1-C10, atau D1-D5 di dalam gudang.';
  }

  String _getLocationInformationText() {
    if (_areAllLocationsOccupied) {
      return 'Seluruh lokasi di dalam gudang dan belakang gudang '
          'sedang digunakan. Stok masuk belum dapat dilakukan.';
    }

    if (_areAllMainLocationsOccupied) {
      return 'Lokasi di dalam gudang penuh. Batch baru akan disimpan '
          'sementara pada lokasi X1-X5 di belakang gudang.';
    }

    return 'Lokasi X1-X5 hanya digunakan ketika seluruh lokasi '
        'di dalam gudang sudah penuh.';
  }

  void _showFloatingSnackBar(
    String message,
    Color color,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.only(
          bottom: 24,
          left: 16,
          right: 16,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _selectDate(
    BuildContext context,
  ) async {
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
    final finalLocation = _normalizeLocation(_selectedLocation ?? '');

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
      } else if (_hasErrorQty) {
        _showFloatingSnackBar(
          'Jumlah stok harus berupa angka lebih dari 0.',
          Colors.redAccent,
        );
      } else {
        _showFloatingSnackBar(
          'Lokasi tumpukan wajib dipilih.',
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

      final normalizedLatestOccupiedLocations = latestOccupiedLocations
          .map(_normalizeLocation)
          .where((location) => location.isNotEmpty)
          .toSet();

      final allMainLocationsOccupied = _mainStorageLocations.every(
        normalizedLatestOccupiedLocations.contains,
      );

      final allBackupLocationsOccupied = _backupStorageLocations.every(
        normalizedLatestOccupiedLocations.contains,
      );

      if (allMainLocationsOccupied && allBackupLocationsOccupied) {
        throw Exception(
          'Seluruh lokasi di dalam gudang dan belakang gudang '
          'sedang penuh.',
        );
      }

      if (normalizedLatestOccupiedLocations.contains(finalLocation)) {
        throw Exception(
          'Lokasi $finalLocation sudah digunakan oleh batch aktif. '
          'Pilih lokasi lain.',
        );
      }

      if (!_isMainLocation(finalLocation) &&
          !_isBackupLocation(finalLocation)) {
        throw Exception(
          'Lokasi penyimpanan tidak valid.',
        );
      }

      if (_isBackupLocation(finalLocation) && !allMainLocationsOccupied) {
        throw Exception(
          'Lokasi belakang gudang hanya dapat digunakan ketika '
          'seluruh lokasi di dalam gudang sudah penuh.',
        );
      }

      if (_isMainLocation(finalLocation) && allMainLocationsOccupied) {
        throw Exception(
          'Seluruh lokasi di dalam gudang sudah penuh. '
          'Gunakan lokasi belakang gudang X1-X5.',
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

      if (!mounted) {
        return;
      }

      final generatedBatchCode = batchResult['batchCode'] ?? 'batch baru';

      _qtyController.clear();
      _notesController.clear();

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
        'Stok berhasil ditambahkan.\n'
        'Kode: $generatedBatchCode\n'
        'Lokasi: $finalLocation',
        const Color(0xFF038E1B),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      final message = e.toString().replaceFirst(
            'Exception: ',
            '',
          );

      _showFloatingSnackBar(
        'Gagal menambahkan stok: $message',
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
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
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
              padding: EdgeInsets.only(right: 12),
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
              padding: EdgeInsets.only(
                right: suffixIcon != null ? 8 : 0,
              ),
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
      suffixIcon: combinedSuffix == null
          ? null
          : Padding(
              padding: EdgeInsets.zero,
              child: combinedSuffix,
            ),
      suffixIconConstraints: const BoxConstraints(
        minWidth: 0,
        minHeight: 0,
      ),
    );
  }

  Widget _buildLocationBox({
    required String location,
    required bool isSelected,
    required bool isOccupied,
    required VoidCallback onTap,
  }) {
    final isBackupLocation = _isBackupLocation(location);

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
                  stops: [0, 0.5, 1],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : isOccupied
                  ? Colors.grey.shade200
                  : isBackupLocation
                      ? Colors.orange.shade50
                      : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF038E1B)
                : isOccupied
                    ? Colors.grey.shade300
                    : isBackupLocation
                        ? Colors.orange.shade300
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
                    : isBackupLocation
                        ? Colors.orange.shade900
                        : const Color(0xFF015816),
          ),
        ),
      ),
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

  Future<void> _refreshLocationsInBottomSheet(
    StateSetter setModalState,
  ) async {
    await _loadOccupiedLocations(silent: true);

    if (!mounted) {
      return;
    }

    setModalState(() {});
  }

  void _showLocationPickerBottomSheet() {
    if (_areAllLocationsOccupied) {
      _showFloatingSnackBar(
        'Seluruh lokasi di dalam gudang dan belakang gudang '
        'sedang penuh.',
        Colors.redAccent,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final visibleLocations = _visibleStorageLocations;

            return SafeArea(
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
                padding: const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20,
                ),
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
                          Expanded(
                            child: Text(
                              _getLocationPickerTitle(),
                              style: const TextStyle(
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
                              await _refreshLocationsInBottomSheet(
                                setModalState,
                              );

                              if (_areAllLocationsOccupied &&
                                  bottomSheetContext.mounted) {
                                Navigator.pop(
                                  bottomSheetContext,
                                );

                                _showFloatingSnackBar(
                                  'Seluruh lokasi penyimpanan '
                                  'sedang penuh.',
                                  Colors.redAccent,
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Navigator.pop(
                                bottomSheetContext,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getLocationPickerDescription(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _areAllMainLocationsOccupied
                              ? Colors.orange.shade50
                              : const Color(0xFFEFFBEF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _areAllMainLocationsOccupied
                                ? Colors.orange.shade200
                                : const Color(0xFFB7E8B4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _areAllMainLocationsOccupied
                                  ? Icons.warehouse_outlined
                                  : Icons.info_outline,
                              size: 20,
                              color: _areAllMainLocationsOccupied
                                  ? Colors.orange.shade800
                                  : const Color(0xFF038E1B),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getLocationInformationText(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black87,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: visibleLocations.map(
                          (location) {
                            final normalizedLocation =
                                _normalizeLocation(location);

                            final isSelected = _normalizeLocation(
                                  _selectedLocation ?? '',
                                ) ==
                                normalizedLocation;

                            final isOccupied = _isLocationOccupied(
                              normalizedLocation,
                            );

                            return _buildLocationBox(
                              location: location,
                              isSelected: isSelected,
                              isOccupied: isOccupied,
                              onTap: () {
                                setState(() {
                                  _selectedLocation = normalizedLocation;
                                  _hasErrorLocation = false;
                                });

                                setModalState(() {});

                                Navigator.pop(
                                  bottomSheetContext,
                                );
                              },
                            );
                          },
                        ).toList(),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildMiniLegend(
                            color: const Color(0xFF038E1B),
                            text: 'Dipilih',
                          ),
                          if (_areAllMainLocationsOccupied)
                            _buildMiniLegend(
                              color: Colors.orange.shade50,
                              borderColor: Colors.orange.shade300,
                              text: 'Kosong',
                            )
                          else
                            _buildMiniLegend(
                              color: Colors.white,
                              borderColor: const Color(0xFFDADADA),
                              text: 'Kosong',
                            ),
                          _buildMiniLegend(
                            color: Colors.grey.shade200,
                            borderColor: Colors.grey.shade300,
                            text: 'Terisi',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLocationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSvgWrapper(
          svgPath: 'assets/stockin/recm.svg',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoadingLocations || _areAllLocationsOccupied
                  ? null
                  : _showLocationPickerBottomSheet,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _getSelectedLocationText(),
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: fieldTextStyle.copyWith(
                        color: _hasErrorLocation || _areAllLocationsOccupied
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
                    _areAllMainLocationsOccupied
                        ? Icons.warehouse_outlined
                        : Icons.grid_view_rounded,
                    color: _hasErrorLocation || _areAllLocationsOccupied
                        ? Colors.red
                        : _areAllMainLocationsOccupied
                            ? Colors.orange.shade800
                            : const Color(0xFF015816),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!_isLoadingLocations &&
            _areAllMainLocationsOccupied &&
            !_areAllLocationsOccupied)
          const Padding(
            padding: EdgeInsets.only(
              top: 7,
              left: 4,
            ),
            child: Text(
              'Lokasi di dalam gudang penuh. '
              'Gunakan lokasi X1-X5 di belakang gudang.',
              style: TextStyle(
                color: Color(0xFFB85C00),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (!_isLoadingLocations && _areAllLocationsOccupied)
          const Padding(
            padding: EdgeInsets.only(
              top: 7,
              left: 4,
            ),
            child: Text(
              'Stok masuk tidak dapat dilakukan karena '
              'seluruh lokasi penyimpanan penuh.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductDropdown() {
    return _buildSvgWrapper(
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
            return _products.map(
              (ProductModel item) {
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
              },
            ).toList();
          },
          items: _products.map(
            (product) {
              return DropdownMenuItem<ProductModel>(
                value: product,
                child: Text(
                  product.name,
                  style: fieldTextStyle,
                ),
              );
            },
          ).toList(),
          onChanged: (value) {
            setState(() {
              _selectedProduct = value;
              _hasErrorProduct = false;
            });
          },
        ),
      ),
    );
  }

  Widget _buildQtyField() {
    return _buildSvgWrapper(
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
          suffixText: _qtyController.text.isNotEmpty ? 'karung' : null,
          hasError: _hasErrorQty,
        ),
        onChanged: (_) {
          setState(() {
            _hasErrorQty = false;
          });
        },
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () {
        _selectDate(context);
      },
      child: _buildSvgWrapper(
        svgPath: 'assets/stockin/recm.svg',
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Tanggal Masuk : '
                '${_formatDate(_selectedDate)}',
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
    );
  }

  Widget _buildNotesField() {
    return _buildSvgWrapper(
      svgPath: 'assets/stockin/recb.svg',
      height: 100,
      child: TextField(
        controller: _notesController,
        textAlign: TextAlign.left,
        maxLines: 3,
        style: fieldTextStyle,
        decoration: _customFieldDecoration(
          'Catatan...',
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    final isDisabled =
        _isSubmitting || _isLoadingLocations || _areAllLocationsOccupied;

    return Center(
      child: GestureDetector(
        onTap: isDisabled ? null : _saveStockIn,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: isDisabled ? 0.55 : 1,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
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
                  Icon(
                    _areAllLocationsOccupied
                        ? Icons.block
                        : Icons.save_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _areAllLocationsOccupied ? 'Lokasi Penuh' : 'Simpan',
                    style: const TextStyle(
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
                            onPressed: () {
                              Navigator.pop(context);
                            },
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
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
                      'Lengkapi data produk, jumlah stok, lokasi tumpukan,\n'
                      'dan tanggal masuk.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.black.withOpacity(0.6),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildProductDropdown(),
                    const SizedBox(height: 14),
                    _buildQtyField(),
                    const SizedBox(height: 14),
                    _buildLocationSelector(),
                    const SizedBox(height: 14),
                    _buildDateSelector(),
                    const SizedBox(height: 14),
                    _buildNotesField(),
                    const SizedBox(height: 28),
                    _buildSaveButton(),
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
