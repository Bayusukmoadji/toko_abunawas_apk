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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    _selectedFilterNotifier.dispose();
    super.dispose();
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

    return products.where((product) {
      bool matchStatus = true;

      if (selectedFilter == _ProductFilter.active) {
        matchStatus = product.isActive;
      } else if (selectedFilter == _ProductFilter.inactive) {
        matchStatus = !product.isActive;
      }

      final matchSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.code.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query) ||
          product.unit.toLowerCase().contains(query);

      return matchStatus && matchSearch;
    }).toList();
  }

  int _countActive(List<ProductModel> products) {
    return products.where((product) => product.isActive).length;
  }

  int _countInactive(List<ProductModel> products) {
    return products.where((product) => !product.isActive).length;
  }

  int _countLowStock(List<ProductModel> products) {
    return products.where((product) {
      if (!product.isActive) return false;
      if (product.minimumStock <= 0) return false;
      return product.totalStock <= product.minimumStock;
    }).length;
  }

  Future<void> _toggleProductStatus({
    required ProductModel product,
    required bool isActive,
  }) async {
    try {
      await _productRepository.updateProductActiveStatus(
        productId: product.id,
        isActive: isActive,
      );

      _showSnackBar(
        message: isActive
            ? 'Produk berhasil diaktifkan.'
            : 'Produk berhasil dinonaktifkan.',
        color: Colors.green,
      );
    } catch (e) {
      _showSnackBar(
        message: 'Gagal memperbarui status produk: $e',
        color: Colors.red,
      );
    }
  }

  Future<bool> _confirmAndDeleteProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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

    bool isActive = product?.isActive ?? true;
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
                      Color(0xFF0F6022),
                      Color(0xFF38B24C),
                    ],
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
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFB9DFBD),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                color: Color(0xFF1B802E),
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
                      TextFormField(
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Nama Produk',
                          hintText: 'Contoh: Beras Ramos',
                          prefixIcon: const Icon(Icons.rice_bowl_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama produk wajib diisi';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: codeController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Kode Produk',
                          hintText: 'Kosongkan untuk dibuat otomatis',
                          prefixIcon: const Icon(Icons.qr_code_2_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9_\-\s]'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: categoryController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Kategori',
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Kategori wajib diisi';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: unitController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Satuan',
                          hintText: 'Contoh: karung',
                          prefixIcon: const Icon(Icons.scale_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Satuan wajib diisi';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: minimumStockController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Minimum Stok',
                          prefixIcon: const Icon(Icons.warning_amber_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                        activeColor: const Color(0xFF1AD426),
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
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F6022),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSubmitting
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
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(isEdit ? Icons.save_outlined : Icons.add),
                  label: Text(isSubmitting ? 'Menyimpan...' : 'Simpan'),
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

  Widget _buildSummaryCard(List<ProductModel> products) {
    final activeCount = _countActive(products);
    final inactiveCount = _countInactive(products);
    final lowStockCount = _countLowStock(products);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F5E9),
            Color(0xFFC8E6C9),
          ],
        ),
        border: Border.all(color: const Color(0xFFB9DFBD), width: 0.5),
      ),
      child: Padding(
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
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Catatan: produk yang sudah memiliki batch tidak dihapus permanen, melainkan dinonaktifkan agar riwayat transaksi tetap aman.',
                style: TextStyle(
                  color: Color(0xFF6B8E70),
                  fontSize: 10,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: const Color(0xFF1B802E),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        ValueListenableBuilder<String>(
          valueListenable: _searchQueryNotifier,
          builder: (context, searchQuery, _) {
            return TextField(
              key: const ValueKey('product_search_field'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari nama, kode, kategori, atau satuan produk...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          _searchQueryNotifier.value = '';
                          _searchFocusNode.requestFocus();
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
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
                  borderSide: const BorderSide(color: Color(0xFF0F6022)),
                ),
              ),
              onChanged: (value) {
                _searchQueryNotifier.value = value;
              },
            );
          },
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<_ProductFilter>(
          valueListenable: _selectedFilterNotifier,
          builder: (context, selectedFilter, _) {
            return Row(
              children: _ProductFilter.values.map((filter) {
                final selected = selectedFilter == filter;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          _filterLabel(filter),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      selected: selected,
                      selectedColor: const Color(0xFF0F6022),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF0F6022)
                            : Colors.grey.shade300,
                      ),
                      onSelected: (_) {
                        _selectedFilterNotifier.value = filter;
                        _searchFocusNode.requestFocus();
                      },
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
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
        borderRadius: BorderRadius.circular(12),
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
    final stockIsLow = product.isActive &&
        product.minimumStock > 0 &&
        product.totalStock <= product.minimumStock;

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F5E9),
            Color(0xFFC8E6C9),
          ],
        ),
        border: Border.all(color: const Color(0xFFB9DFBD), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.8),
                  radius: 22,
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFF1B802E),
                    size: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kode: ${product.code}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
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
                            text: product.isActive ? 'Aktif' : 'Nonaktif',
                            color: product.isActive ? Colors.green : Colors.red,
                            icon: product.isActive
                                ? Icons.check_circle_outline
                                : Icons.block,
                          ),
                          if (stockIsLow)
                            _buildMiniBadge(
                              text: 'Stok Menipis',
                              color: Colors.orange,
                              icon: Icons.warning_amber_outlined,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: product.isActive,
                  activeColor: Colors.white,
                  activeTrackColor: const Color(0xFF1AD426),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade400,
                  onChanged: (value) {
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
                color: Colors.white.withOpacity(0.68),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.6),
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F6022),
                      side: const BorderSide(color: Color(0xFF0F6022)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      _showProductFormDialog(product: product);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text(
                      'Edit',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Geser kartu ke kiri untuk menghapus produk.',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF6B8E70),
              ),
            ),
          ],
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('product-${product.id}'),
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
          color: const Color(0xFF1B802E),
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
        Text(
          value,
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Belum ada data produk. Tekan tombol tambah di kanan bawah untuk menambahkan produk baru.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black54,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildNotFoundState() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Produk tidak ditemukan berdasarkan pencarian atau filter yang dipilih.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.black54,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Gagal memuat data produk: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F6022),
        foregroundColor: Colors.white,
        onPressed: () => _showProductFormDialog(),
        icon: const Icon(Icons.add_box_outlined),
        label: const Text(
          'Tambah',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      appBar: AppBar(
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
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF0F6022),
                Color(0xFF38B24C),
              ],
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<ProductModel>>(
        stream: _productRepository.getProductsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          final products = snapshot.data ?? [];

          if (products.isEmpty) {
            return _buildEmptyState();
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Ringkasan Produk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryCard(products),
                        const SizedBox(height: 20),
                        _buildSearchAndFilter(),
                        const SizedBox(height: 24),
                        const Text(
                          'Daftar Produk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildProductListBySearchAndFilter(products),
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
