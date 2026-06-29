import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository.dart';

enum _ProductFilter {
  all,
  active,
  inactive,
}

class ProductManagementPage extends StatefulWidget {
  const ProductManagementPage({super.key});

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  final ProductRepository _productRepository = ProductRepository();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');
  final ValueNotifier<_ProductFilter> _selectedFilterNotifier =
      ValueNotifier<_ProductFilter>(_ProductFilter.all);

  final Set<String> _updatingProductIds = <String>{};
  final Map<String, bool> _activeStatusOverrides = <String, bool>{};

  final BoxShadow _softShadow = BoxShadow(
    color: Colors.black.withOpacity(0.07),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    _selectedFilterNotifier.dispose();
    super.dispose();
  }

  bool _effectiveIsActive(ProductModel product) {
    return _activeStatusOverrides[product.id] ?? product.isActive;
  }

  void _clearSyncedOverrides(List<ProductModel> products) {
    final idsToRemove = <String>[];

    for (final product in products) {
      final overrideValue = _activeStatusOverrides[product.id];

      if (overrideValue == null) continue;
      if (_updatingProductIds.contains(product.id)) continue;

      if (product.isActive == overrideValue) {
        idsToRemove.add(product.id);
      }
    }

    if (idsToRemove.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        for (final id in idsToRemove) {
          _activeStatusOverrides.remove(id);
        }
      });
    });
  }

  void _showSnackBar({
    required String message,
    required Color color,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      ),
    );
  }

  String _filterLabel(_ProductFilter filter) {
    switch (filter) {
      case _ProductFilter.all:
        return 'Semua';
      case _ProductFilter.active:
        return 'Aktif';
      case _ProductFilter.inactive:
        return 'Nonaktif';
    }
  }

  List<ProductModel> _filterProducts({
    required List<ProductModel> products,
    required String searchQuery,
    required _ProductFilter selectedFilter,
  }) {
    final query = searchQuery.trim().toLowerCase();

    final filteredProducts = products.where((product) {
      bool matchStatus = true;
      final isActive = _effectiveIsActive(product);

      if (selectedFilter == _ProductFilter.active) {
        matchStatus = isActive;
      } else if (selectedFilter == _ProductFilter.inactive) {
        matchStatus = !isActive;
      }

      final matchSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.code.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query) ||
          product.unit.toLowerCase().contains(query);

      return matchStatus && matchSearch;
    }).toList();

    filteredProducts.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return filteredProducts;
  }

  int _countActive(List<ProductModel> products) {
    return products.where((product) => _effectiveIsActive(product)).length;
  }

  int _countInactive(List<ProductModel> products) {
    return products.where((product) => !_effectiveIsActive(product)).length;
  }

  int _countLowStock(List<ProductModel> products) {
    return products.where((product) {
      if (!_effectiveIsActive(product)) return false;
      if (product.minimumStock <= 0) return false;
      return product.totalStock <= product.minimumStock;
    }).length;
  }

  bool _isLowStock(ProductModel product) {
    return _effectiveIsActive(product) &&
        product.minimumStock > 0 &&
        product.totalStock <= product.minimumStock;
  }

  Color _getProductStatusColor(ProductModel product) {
    if (!_effectiveIsActive(product)) {
      return Colors.red.shade400;
    }

    if (_isLowStock(product)) {
      return Colors.orange.shade500;
    }

    return Colors.green.shade600;
  }

  IconData _getProductStatusIcon(ProductModel product) {
    if (!_effectiveIsActive(product)) {
      return Icons.block;
    }

    if (_isLowStock(product)) {
      return Icons.warning_amber_rounded;
    }

    return Icons.inventory_2_outlined;
  }

  String _getProductStatusText(ProductModel product) {
    if (!_effectiveIsActive(product)) {
      return 'Nonaktif';
    }

    if (_isLowStock(product)) {
      return 'Stok Menipis';
    }

    return 'Aktif';
  }

  Future<void> _toggleProductStatus({
    required ProductModel product,
    required bool isActive,
  }) async {
    if (_updatingProductIds.contains(product.id)) {
      return;
    }

    final previousValue = _effectiveIsActive(product);

    setState(() {
      _activeStatusOverrides[product.id] = isActive;
      _updatingProductIds.add(product.id);
    });

    try {
      await _productRepository.updateProductActiveStatus(
        productId: product.id,
        isActive: isActive,
      );

      _showSnackBar(
        message: isActive
            ? '${product.name} berhasil diaktifkan.'
            : '${product.name} berhasil dinonaktifkan.',
        color: Colors.green,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _activeStatusOverrides[product.id] = previousValue;
        });

        _showSnackBar(
          message: 'Gagal memperbarui status produk ${product.name}: $e',
          color: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingProductIds.remove(product.id);
        });

        Future.delayed(const Duration(milliseconds: 700), () {
          if (!mounted) return;

          setState(() {
            _activeStatusOverrides.remove(product.id);
          });
        });
      }
    }
  }

  Future<bool> _confirmAndDeleteProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Hapus Produk?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Produk "${product.name}" akan dihapus.\n\n'
            'Jika produk sudah pernah digunakan pada batch/transaksi, sistem akan menonaktifkan produk agar riwayat data tetap aman.',
            style: const TextStyle(
              height: 1.4,
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return false;

    try {
      final result = await _productRepository.deleteProduct(
        productId: product.id,
      );

      _showSnackBar(
        message: result.message,
        color: result.action == ProductDeleteAction.deleted
            ? Colors.green
            : Colors.orange,
      );

      return false;
    } catch (e) {
      _showSnackBar(
        message: 'Gagal menghapus produk: $e',
        color: Colors.red,
      );

      return false;
    }
  }

  void _showProductFormDialog({
    ProductModel? product,
  }) {
    final isEdit = product != null;

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: product?.name ?? '');
    final codeController = TextEditingController(text: product?.code ?? '');
    final categoryController = TextEditingController(
      text: product?.category.trim().isEmpty == false
          ? product!.category
          : 'Beras',
    );
    final unitController = TextEditingController(
      text: product?.unit.trim().isEmpty == false ? product!.unit : 'karung',
    );
    final minimumStockController = TextEditingController(
      text: product?.minimumStock.toString() ?? '10',
    );

    bool isActive = product == null ? true : _effectiveIsActive(product);
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF015816),
                      Color(0xFF038E1B),
                      Color(0xFF84E977),
                    ],
                    stops: [0.0, 0.55, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isEdit ? Icons.edit_outlined : Icons.add_box_outlined,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit Produk' : 'Tambah Produk',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isEdit)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFB9DFBD),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                color: Color(0xFF038E1B),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Total stok saat ini: ${product.totalStock} ${product.unit}',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      _buildDialogTextField(
                        controller: nameController,
                        label: 'Nama Produk',
                        hint: 'Contoh: Beras Ramos',
                        icon: Icons.rice_bowl_outlined,
                        validatorMessage: 'Nama produk wajib diisi',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: codeController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.characters,
                        decoration: _dialogInputDecoration(
                          label: 'Kode Produk',
                          hint: 'Kosongkan untuk dibuat otomatis',
                          icon: Icons.qr_code_2_outlined,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9_\-\s]'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDialogTextField(
                        controller: categoryController,
                        label: 'Kategori',
                        icon: Icons.category_outlined,
                        validatorMessage: 'Kategori wajib diisi',
                      ),
                      const SizedBox(height: 12),
                      _buildDialogTextField(
                        controller: unitController,
                        label: 'Satuan',
                        hint: 'Contoh: karung',
                        icon: Icons.scale_outlined,
                        validatorMessage: 'Satuan wajib diisi',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: minimumStockController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: _dialogInputDecoration(
                          label: 'Minimum Stok',
                          icon: Icons.warning_amber_outlined,
                        ),
                        validator: (value) {
                          final rawValue = value?.trim() ?? '';

                          if (rawValue.isEmpty) {
                            return 'Minimum stok wajib diisi';
                          }

                          final minimumStock = int.tryParse(rawValue);

                          if (minimumStock == null) {
                            return 'Minimum stok harus berupa angka';
                          }

                          if (minimumStock < 0) {
                            return 'Minimum stok tidak boleh kurang dari 0';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isActive,
                        activeColor: const Color(0xFF038E1B),
                        title: const Text(
                          'Produk Aktif',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          isActive
                              ? 'Produk dapat dipilih saat stok masuk.'
                              : 'Produk tidak tampil pada input stok masuk.',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onChanged: isSubmitting
                            ? null
                            : (value) {
                                setDialogState(() {
                                  isActive = value;
                                });
                              },
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Catatan: total stok tidak diedit manual dari halaman ini. Total stok berubah otomatis dari transaksi stok masuk dan stok keluar.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Batal'),
                ),
                Container(
                  height: 42,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: isSubmitting
                        ? null
                        : const LinearGradient(
                            colors: [
                              Color(0xFF015816),
                              Color(0xFF038E1B),
                              Color(0xFF84E977),
                            ],
                            stops: [0.0, 0.55, 1.0],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: isSubmitting ? Colors.grey : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isSubmitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;

                              setDialogState(() {
                                isSubmitting = true;
                              });

                              final minimumStock = int.parse(
                                minimumStockController.text.trim(),
                              );

                              try {
                                if (isEdit) {
                                  await _productRepository.updateProduct(
                                    productId: product.id,
                                    name: nameController.text.trim(),
                                    code: codeController.text.trim(),
                                    category: categoryController.text.trim(),
                                    unit: unitController.text.trim(),
                                    minimumStock: minimumStock,
                                    isActive: isActive,
                                  );
                                } else {
                                  await _productRepository.createProduct(
                                    name: nameController.text.trim(),
                                    code: codeController.text.trim(),
                                    category: categoryController.text.trim(),
                                    unit: unitController.text.trim(),
                                    minimumStock: minimumStock,
                                    isActive: isActive,
                                  );
                                }

                                if (!dialogContext.mounted) return;

                                Navigator.of(dialogContext).pop();

                                _showSnackBar(
                                  message: isEdit
                                      ? 'Produk berhasil diperbarui.'
                                      : 'Produk berhasil ditambahkan.',
                                  color: Colors.green,
                                );
                              } catch (e) {
                                if (!dialogContext.mounted) return;

                                setDialogState(() {
                                  isSubmitting = false;
                                });

                                _showSnackBar(
                                  message: '$e',
                                  color: Colors.red,
                                );
                              }
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSubmitting)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Icon(
                                isEdit ? Icons.save_outlined : Icons.add,
                                color: Colors.white,
                                size: 18,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              isSubmitting ? 'Menyimpan...' : 'Simpan',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      codeController.dispose();
      categoryController.dispose();
      unitController.dispose();
      minimumStockController.dispose();
    });
  }

  InputDecoration _dialogInputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDADADA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF038E1B)),
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String validatorMessage,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      decoration: _dialogInputDecoration(
        label: label,
        hint: hint,
        icon: icon,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return validatorMessage;
        }

        return null;
      },
    );
  }

  Widget _buildCleanCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color color = Colors.white,
    Color borderColor = const Color(0xFFE5E5E5),
  }) {
    return Container(
      width: double.infinity,
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
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
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(List<ProductModel> products) {
    final activeCount = _countActive(products);
    final inactiveCount = _countInactive(products);
    final lowStockCount = _countLowStock(products);

    return _buildCleanCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSummaryRow(
            icon: Icons.inventory_2_outlined,
            label: 'Total Produk',
            value: '${products.length}',
          ),
          _buildSummaryRow(
            icon: Icons.check_circle_outline,
            label: 'Produk Aktif',
            value: '$activeCount',
          ),
          _buildSummaryRow(
            icon: Icons.block,
            label: 'Produk Nonaktif',
            value: '$inactiveCount',
          ),
          _buildSummaryRow(
            icon: Icons.warning_amber_outlined,
            label: 'Stok Menipis',
            value: '$lowStockCount',
            isLast: true,
          ),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Catatan: produk yang sudah memiliki batch tidak dihapus permanen, melainkan dinonaktifkan agar riwayat transaksi tetap aman.',
              style: TextStyle(
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

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: const Color(0xFF038E1B),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
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

  Widget _buildSearchField() {
    return TextField(
      key: const ValueKey('product_search_field'),
      controller: _searchController,
      focusNode: _searchFocusNode,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Cari nama, kode, kategori, atau satuan produk...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder<String>(
          valueListenable: _searchQueryNotifier,
          builder: (context, searchQuery, _) {
            if (searchQuery.isEmpty) {
              return const SizedBox.shrink();
            }

            return IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _searchController.clear();
                _searchQueryNotifier.value = '';
                _searchFocusNode.requestFocus();
              },
            );
          },
        ),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF038E1B)),
        ),
      ),
      onChanged: (value) {
        _searchQueryNotifier.value = value;
      },
    );
  }

  Widget _buildFilterButton({
    required _ProductFilter filter,
    required _ProductFilter selectedFilter,
  }) {
    final isSelected = selectedFilter == filter;

    return Expanded(
      child: InkWell(
        onTap: () {
          _selectedFilterNotifier.value = filter;
          _searchFocusNode.unfocus();
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
          ),
          child: Center(
            child: Text(
              _filterLabel(filter),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return _buildCleanCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSearchField(),
          const SizedBox(height: 12),
          ValueListenableBuilder<_ProductFilter>(
            valueListenable: _selectedFilterNotifier,
            builder: (context, selectedFilter, _) {
              return Row(
                children: [
                  _buildFilterButton(
                    filter: _ProductFilter.all,
                    selectedFilter: selectedFilter,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterButton(
                    filter: _ProductFilter.active,
                    selectedFilter: selectedFilter,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterButton(
                    filter: _ProductFilter.inactive,
                    selectedFilter: selectedFilter,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductListBySearchAndFilter(List<ProductModel> products) {
    return ValueListenableBuilder<String>(
      valueListenable: _searchQueryNotifier,
      builder: (context, searchQuery, _) {
        return ValueListenableBuilder<_ProductFilter>(
          valueListenable: _selectedFilterNotifier,
          builder: (context, selectedFilter, _) {
            final filteredProducts = _filterProducts(
              products: products,
              searchQuery: searchQuery,
              selectedFilter: selectedFilter,
            );

            if (filteredProducts.isEmpty) {
              return _buildNotFoundState();
            }

            return Column(
              children: filteredProducts.map(_buildProductCard).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Hapus',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          Icon(
            Icons.delete_outline,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final effectiveActive = _effectiveIsActive(product);
    final stockIsLow = _isLowStock(product);
    final statusColor = _getProductStatusColor(product);
    final statusIcon = _getProductStatusIcon(product);
    final statusText = _getProductStatusText(product);
    final isUpdating = _updatingProductIds.contains(product.id);

    final card = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.18),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.15),
                  radius: 18,
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Kode: ${product.code}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 10.5,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildMiniBadge(
                              text: product.category,
                              color: Colors.blue,
                              icon: Icons.category_outlined,
                            ),
                            _buildMiniBadge(
                              text: statusText,
                              color: statusColor,
                              icon: statusIcon,
                            ),
                            if (stockIsLow && effectiveActive)
                              _buildMiniBadge(
                                text: 'Perlu Pantau',
                                color: Colors.orange,
                                icon: Icons.visibility_outlined,
                              ),
                            if (isUpdating)
                              _buildMiniBadge(
                                text: 'Menyimpan',
                                color: Colors.blueGrey,
                                icon: Icons.sync,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  key: ValueKey('product-switch-${product.id}'),
                  value: effectiveActive,
                  activeColor: Colors.white,
                  activeTrackColor: const Color(0xFF038E1B),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade400,
                  onChanged: isUpdating
                      ? null
                      : (value) {
                          _toggleProductStatus(
                            product: product,
                            isActive: value,
                          );
                        },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.86),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE5E5E5),
                ),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.inventory_outlined,
                    label: 'Total Stok',
                    value: '${product.totalStock} ${product.unit}',
                    valueColor: stockIsLow ? Colors.orange : Colors.black87,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    icon: Icons.warning_amber_outlined,
                    label: 'Minimum Stok',
                    value: '${product.minimumStock} ${product.unit}',
                    valueColor: Colors.black87,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    icon: Icons.scale_outlined,
                    label: 'Satuan',
                    value: product.unit,
                    valueColor: Colors.black87,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF038E1B),
                  side: const BorderSide(color: Color(0xFF038E1B)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: isUpdating
                    ? null
                    : () {
                        _showProductFormDialog(product: product);
                      },
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text(
                  'Edit Produk',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Geser kartu ke kiri untuk menghapus produk.',
              style: TextStyle(
                fontSize: 10,
                color: Colors.black54,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('product-card-${product.id}'),
      direction: DismissDirection.endToStart,
      background: _buildDismissBackground(),
      confirmDismiss: (_) => _confirmAndDeleteProduct(product),
      child: card,
    );
  }

  Widget _buildMiniBadge({
    required String text,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: const Color(0xFF038E1B),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 12,
            color: valueColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Text(
            'Belum ada data produk. Tekan tombol tambah di kanan bawah untuk menambahkan produk baru.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
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
              'Produk tidak ditemukan berdasarkan pencarian atau filter yang dipilih.',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
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
            'Gagal memuat data produk: $error',
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

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.green),
    );
  }

  Widget _buildGradientFloatingButton() {
    return Container(
      height: 48,
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
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProductFormDialog(),
          borderRadius: BorderRadius.circular(99),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_box_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Tambah',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
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
            size: 28,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'KELOLA PRODUK',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
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
              stops: [0.0, 0.55, 1.0],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      floatingActionButton: _buildGradientFloatingButton(),
      appBar: _buildAppBar(),
      body: StreamBuilder<List<ProductModel>>(
        stream: _productRepository.getProductsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          final products = snapshot.data ?? [];

          _clearSyncedOverrides(products);

          if (products.isEmpty) {
            return _buildEmptyState();
          }

          return SafeArea(
            child: SingleChildScrollView(
              key: const PageStorageKey<String>('product_management_scroll'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                        _buildSectionTitle(
                          title: 'Ringkasan Produk',
                          subtitle:
                              'Ringkasan jumlah produk berdasarkan status aktif dan kondisi stok.',
                        ),
                        _buildSummaryCard(products),
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          title: 'Filter Produk',
                          subtitle:
                              'Cari produk dan tampilkan berdasarkan semua, aktif, atau nonaktif.',
                        ),
                        _buildSearchAndFilter(),
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          title: 'Daftar Produk',
                          subtitle:
                              'Kelola data produk, status aktif, minimum stok, dan informasi satuan.',
                        ),
                        _buildProductListBySearchAndFilter(products),
                        const SizedBox(height: 72),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
