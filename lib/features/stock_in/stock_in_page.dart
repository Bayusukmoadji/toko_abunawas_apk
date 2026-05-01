import 'package:flutter/material.dart';

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
  final _formKey = GlobalKey<FormState>();
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveStockIn() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih produk terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

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
        productId: _selectedProduct!.id,
        qty: qty,
      );

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stok masuk berhasil disimpan dengan kode ${batchResult['batchCode']}.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      _formKey.currentState!.reset();
      _qtyController.clear();
      _locationController.clear();
      _notesController.clear();

      setState(() {
        _selectedProduct = null;
        _selectedDate = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan stok masuk: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildHeaderCard(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.add_box_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stok Masuk',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Catat stok beras yang masuk ke gudang, buat batch, dan hasilkan QR Code otomatis.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2E7D32).withOpacity(0.18),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Color(0xFF2E7D32),
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Setiap stok masuk akan dibuat sebagai batch baru. Pada sistem ini, satuan beras adalah karung dengan asumsi 1 karung = 50 kg.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.black87,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedProductInfo() {
    final product = _selectedProduct;

    if (product == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: Colors.blue,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kode: ${product.code}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  'Stok saat ini: ${product.totalStock} ${product.unit}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  'Minimum stok: ${product.minimumStock} ${product.unit}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Form Input Stok Masuk',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Lengkapi data produk, jumlah stok, lokasi penyimpanan, dan tanggal masuk.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<ProductModel>(
                value: _selectedProduct,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Pilih Produk',
                  prefixIcon: Icon(Icons.rice_bowl_outlined),
                ),
                items: _products.map((product) {
                  return DropdownMenuItem<ProductModel>(
                    value: product,
                    child: Text(
                      product.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProduct = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Produk harus dipilih';
                  }
                  return null;
                },
              ),
              _buildSelectedProductInfo(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Stok Masuk',
                  hintText: 'Contoh: 10',
                  prefixIcon: Icon(Icons.numbers),
                  suffixText: 'karung',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Jumlah tidak boleh kosong';
                  }

                  final qty = int.tryParse(value.trim());

                  if (qty == null || qty <= 0) {
                    return 'Jumlah harus berupa angka lebih dari 0';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Lokasi Batch di Gudang',
                  hintText: 'Contoh: Rak A1 / Tumpukan Depan',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lokasi batch tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Masuk',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(
                    _formatDate(_selectedDate),
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  hintText: 'Opsional',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _saveStockIn,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSubmitting ? 'Menyimpan...' : 'Simpan Stok Masuk',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyProductState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Masuk'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 54,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Belum Ada Produk Aktif',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tambahkan data produk aktif terlebih dahulu di Firestore agar dapat melakukan input stok masuk.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: _loadProducts,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Muat Ulang'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProducts) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Stok Masuk'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_products.isEmpty) {
      return _buildEmptyProductState();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Masuk'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderCard(context),
                  const SizedBox(height: 14),
                  _buildInfoNote(),
                  const SizedBox(height: 14),
                  _buildFormCard(context),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
