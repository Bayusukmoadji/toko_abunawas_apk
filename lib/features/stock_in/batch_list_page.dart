import 'package:flutter/material.dart';
import '../../data/models/batch_model.dart';
import '../../data/repositories/batch_repository.dart';
import 'batch_detail_page.dart';

class BatchListPage extends StatelessWidget {
  BatchListPage({super.key});

  final BatchRepository _batchRepository = BatchRepository();

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(String status) {
    if (status == 'empty') {
      return Colors.grey;
    }

    return Colors.green;
  }

  String _getStatusText(String status) {
    if (status == 'empty') {
      return 'Habis';
    }

    return 'Aktif';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Batch'),
      ),
      body: StreamBuilder<List<BatchModel>>(
        stream: _batchRepository.getBatchesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Gagal memuat data batch: ${snapshot.error}'),
            );
          }

          final batches = snapshot.data ?? [];

          if (batches.isEmpty) {
            return const Center(
              child: Text('Belum ada data batch.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: batches.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final batch = batches[index];
              final receivedDate = batch.receivedAt.toDate();

              return Card(
                child: ListTile(
                  title: Text(
                    '${batch.batchCode} - ${batch.productName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tanggal Masuk: ${_formatDate(receivedDate)}'),
                        Text(
                          'Sisa Stok: ${batch.remainingQty} ${batch.unit}',
                        ),
                        Text(
                          'Lokasi: ${batch.storageLocation.isEmpty ? '-' : batch.storageLocation}',
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _getStatusColor(batch.status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(batch.status),
                            style: TextStyle(
                              color: _getStatusColor(batch.status),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BatchDetailPage(batch: batch),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
