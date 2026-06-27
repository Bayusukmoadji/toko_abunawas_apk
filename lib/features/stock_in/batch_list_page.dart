import 'package:flutter/material.dart';

import '../../data/models/batch_model.dart';
import '../../data/repositories/batch_repository.dart';
import 'batch_detail_page.dart';

class BatchListPage extends StatefulWidget {
  const BatchListPage({super.key});

  @override
  State<BatchListPage> createState() => _BatchListPageState();
}

class _BatchListPageState extends State<BatchListPage> {
  final BatchRepository _batchRepository = BatchRepository();

  String _selectedStatusFilter = 'Semua';
  DateTime? _selectedReceivedDate;

  final BoxShadow _softShadow = BoxShadow(
    color: Colors.black.withOpacity(0.07),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  bool _isSameDate(DateTime firstDate, DateTime secondDate) {
    return firstDate.year == secondDate.year &&
        firstDate.month == secondDate.month &&
        firstDate.day == secondDate.day;
  }

  Color _getStatusColor(String status) {
    final normalizedStatus = status.toLowerCase().trim();

    if (normalizedStatus == 'empty') {
      return Colors.red.shade400;
    }

    return Colors.green.shade600;
  }

  IconData _getStatusIcon(String status) {
    final normalizedStatus = status.toLowerCase().trim();

    if (normalizedStatus == 'empty') {
      return Icons.cancel_outlined;
    }

    return Icons.inventory_2_outlined;
  }

  String _getStatusText(String status) {
    final normalizedStatus = status.toLowerCase().trim();

    if (normalizedStatus == 'empty') {
      return 'Habis';
    }

    return 'Aktif';
  }

  int _getActiveBatchCount(List<BatchModel> batches) {
    return batches.where((batch) {
      return batch.status.toLowerCase().trim() != 'empty';
    }).length;
  }

  int _getEmptyBatchCount(List<BatchModel> batches) {
    return batches.where((batch) {
      return batch.status.toLowerCase().trim() == 'empty';
    }).length;
  }

  int _getTotalRemainingStock(List<BatchModel> batches) {
    return batches.fold<int>(
      0,
      (total, batch) => total + batch.remainingQty,
    );
  }

  List<BatchModel> _filterBatches(List<BatchModel> batches) {
    final filteredBatches = batches.where((batch) {
      final normalizedStatus = batch.status.toLowerCase().trim();

      bool matchStatus = true;

      if (_selectedStatusFilter == 'Aktif') {
        matchStatus = normalizedStatus != 'empty';
      } else if (_selectedStatusFilter == 'Habis') {
        matchStatus = normalizedStatus == 'empty';
      }

      bool matchDate = true;

      if (_selectedReceivedDate != null) {
        matchDate = _isSameDate(
          batch.receivedAt.toDate(),
          _selectedReceivedDate!,
        );
      }

      return matchStatus && matchDate;
    }).toList();

    filteredBatches.sort(
      (a, b) => b.receivedAt.toDate().compareTo(a.receivedAt.toDate()),
    );

    return filteredBatches;
  }

  String _getFilterDescription() {
    final statusText = _selectedStatusFilter;
    final dateText = _selectedReceivedDate == null
        ? 'Semua tanggal'
        : _formatDate(_selectedReceivedDate!);

    return '$statusText • $dateText';
  }

  Future<void> _pickReceivedDate({
    StateSetter? setModalState,
  }) async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      initialDate: _selectedReceivedDate ?? now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedReceivedDate = pickedDate;
    });

    setModalState?.call(() {});
  }

  void _clearReceivedDate({
    StateSetter? setModalState,
  }) {
    setState(() {
      _selectedReceivedDate = null;
    });

    setModalState?.call(() {});
  }

  void _resetFilter({
    StateSetter? setModalState,
  }) {
    setState(() {
      _selectedStatusFilter = 'Semua';
      _selectedReceivedDate = null;
    });

    setModalState?.call(() {});
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedDateText = _selectedReceivedDate == null
                ? 'Semua tanggal masuk'
                : _formatDate(_selectedReceivedDate!);

            return SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                            'Filter Batch',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Status Batch',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: ['Semua', 'Aktif', 'Habis'].map((status) {
                        final isSelected = _selectedStatusFilter == status;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                setState(() {
                                  _selectedStatusFilter = status;
                                });
                                setModalState(() {});
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF038E1B)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF038E1B)
                                        : const Color(0xFFDADADA),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Tanggal Masuk Batch',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFDADADA),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedDateText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (_selectedReceivedDate != null)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.black54,
                              ),
                              onPressed: () {
                                _clearReceivedDate(
                                  setModalState: setModalState,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFilterActionButton(
                            label: 'Pilih Tanggal',
                            icon: Icons.calendar_month,
                            onTap: () {
                              _pickReceivedDate(
                                setModalState: setModalState,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFilterActionButton(
                            label: 'Reset Filter',
                            icon: Icons.refresh,
                            onTap: () {
                              _resetFilter(setModalState: setModalState);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF038E1B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Terapkan Filter',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 42,
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
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.11),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  Widget _buildSummaryCard(List<BatchModel> batches) {
    final activeBatch = _getActiveBatchCount(batches);
    final emptyBatch = _getEmptyBatchCount(batches);
    final totalRemainingStock = _getTotalRemainingStock(batches);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan Batch',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ringkasan mengikuti filter status dan tanggal masuk yang dipilih.',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 11,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        _buildCleanCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSummaryRow(
                label: 'Total Batch',
                value: '${batches.length}',
              ),
              _buildSummaryRow(
                label: 'Batch Aktif',
                value: '$activeBatch',
              ),
              _buildSummaryRow(
                label: 'Batch Habis',
                value: '$emptyBatch',
              ),
              _buildSummaryRow(
                label: 'Total Sisa Stok',
                value: '$totalRemainingStock karung',
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
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

  Widget _buildStatusChip(String status) {
    final statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: statusColor.withOpacity(0.35),
        ),
      ),
      child: Text(
        _getStatusText(status),
        style: TextStyle(
          color: statusColor,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 13,
            color: Colors.black45,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10.5,
                color: Colors.black54,
                height: 1.25,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard({
    required BuildContext context,
    required BatchModel batch,
  }) {
    final receivedDate = batch.receivedAt.toDate();
    final location = batch.storageLocation.trim().isEmpty
        ? '-'
        : batch.storageLocation.trim();
    final statusColor = _getStatusColor(batch.status);
    final statusIcon = _getStatusIcon(batch.status);

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BatchDetailPage(batch: batch),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: statusColor.withOpacity(0.15),
                      child: Icon(
                        statusIcon,
                        size: 17,
                        color: statusColor,
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
                              batch.productName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              batch.batchCode,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _buildStatusChip(batch.status),
                    ),
                    const SizedBox(width: 4),
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.keyboard_double_arrow_right,
                        color: Colors.black54,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        icon: Icons.calendar_today_outlined,
                        text: 'Tanggal masuk: ${_formatDate(receivedDate)}',
                      ),
                      _buildInfoRow(
                        icon: Icons.inventory_outlined,
                        text:
                            'Sisa stok: ${batch.remainingQty} ${batch.unit} dari ${batch.initialQty} ${batch.unit}',
                      ),
                      _buildInfoRow(
                        icon: Icons.location_on_outlined,
                        text: 'Lokasi: $location',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Belum ada data batch.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEmptyFilterState() {
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
              'Tidak ada batch yang sesuai dengan filter yang dipilih.',
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
            'Gagal memuat data batch: $error',
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
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'DAFTAR BATCH',
          style: TextStyle(
            color: Colors.white,
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
              stops: [0.0, 0.5, 1.0],
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
      appBar: _buildAppBar(),
      body: StreamBuilder<List<BatchModel>>(
        stream: _batchRepository.getBatchesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          final allBatches = snapshot.data ?? [];

          if (allBatches.isEmpty) {
            return _buildEmptyState();
          }

          final displayedBatches = _filterBatches(allBatches);

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                        _buildSummaryCard(displayedBatches),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Data Batch',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Data batch mengikuti filter yang dipilih.',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 11,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: _showFilterBottomSheet,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFC8E6C9).withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.green.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.filter_alt_outlined,
                                      size: 16,
                                      color: Colors.green.shade800,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Filter',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getFilterDescription(),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (displayedBatches.isEmpty)
                          _buildEmptyFilterState()
                        else
                          ...displayedBatches.map(
                            (batch) => _buildBatchCard(
                              context: context,
                              batch: batch,
                            ),
                          ),
                        const SizedBox(height: 12),
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
