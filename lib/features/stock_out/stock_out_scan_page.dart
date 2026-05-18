import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/models/app_user_model.dart';
import '../../data/repositories/batch_repository.dart';
import 'stock_out_confirm_page.dart';

class StockOutScanPage extends StatefulWidget {
  final AppUserModel user;

  const StockOutScanPage({
    super.key,
    required this.user,
  });

  @override
  State<StockOutScanPage> createState() => _StockOutScanPageState();
}

class _StockOutScanPageState extends State<StockOutScanPage> {
  final BatchRepository _batchRepository = BatchRepository();
  final TextEditingController _manualQrController = TextEditingController();

  bool _isProcessing = false;

  @override
  void dispose() {
    _manualQrController.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String qrValue) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final batch = await _batchRepository.getBatchByQrValue(qrValue);

      if (!mounted) return;

      if (batch == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batch tidak ditemukan.'),
            backgroundColor: Colors.red,
          ),
        );

        setState(() {
          _isProcessing = false;
        });
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StockOutConfirmPage(
            user: widget.user,
            scannedBatch: batch,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membaca QR Code: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _showManualQrDialog() async {
    _manualQrController.clear();

    bool hasError = false;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Manual QR Dialog',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: StatefulBuilder(builder: (context, setStateDialog) {
              return Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage('assets/stockout/bgpop.png'),
                      fit: BoxFit.fill,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.qr_code_2,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Input QR Manual',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Masukkan kode batch beras secara manual jika QR Code tidak dapat dipindai.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _manualQrController,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(
                          color: Color(0xFF015816),
                          fontWeight: FontWeight.w600,
                        ),
                        onChanged: (val) {
                          if (hasError && val.isNotEmpty) {
                            setStateDialog(() {
                              hasError = false;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'QR Value / Batch ID',
                          hintText: 'Tempel QR Value di sini',
                          labelStyle: const TextStyle(color: Color(0xFF038E1B)),
                          floatingLabelStyle: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          prefixIcon: const Icon(Icons.keyboard,
                              color: Color(0xFF038E1B)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: hasError
                                  ? Colors.red
                                  : const Color(0xFF038E1B).withOpacity(0.3),
                              width: hasError ? 2.0 : 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: hasError
                                  ? Colors.red
                                  : const Color(0xFF038E1B),
                              width: 2.0,
                            ),
                          ),
                        ),
                        onSubmitted: (_) {
                          final qrValue = _manualQrController.text.trim();
                          if (qrValue.isEmpty) {
                            setStateDialog(() {
                              hasError = true;
                            });
                            return;
                          }
                          Navigator.pop(context);
                          _handleScan(qrValue);
                        },
                      ),
                      if (hasError)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0, left: 4.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '* Wajib isi',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 98,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'Batal',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 32),
                          Container(
                            width: 98,
                            height: 35,
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/stockout/botpop.png'),
                                fit: BoxFit.fill,
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                final qrValue = _manualQrController.text.trim();
                                if (qrValue.isEmpty) {
                                  setStateDialog(() {
                                    hasError = true;
                                  });
                                  return;
                                }
                                Navigator.pop(context);
                                _handleScan(qrValue);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding:
                                    const EdgeInsets.only(bottom: 6, right: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_forward,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Lanjut',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF038E1B)),
              SizedBox(height: 16),
              Text(
                'Memproses QR Code...',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF015816),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            MobileScanner(
              onDetect: (BarcodeCapture capture) {
                final barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;

                final qrValue = barcodes.first.rawValue;
                if (qrValue == null || qrValue.isEmpty) return;

                _handleScan(qrValue);
              },
            ),
            const QRViewFinderOverlay(),
            Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/stockout/cardtop.png'),
                      fit: BoxFit.fill,
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.keyboard_double_arrow_left,
                          color: Color(0xFF84E977),
                          size: 28,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Scan QR Stok Keluar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 28),
                    ],
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 11),
                const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Scan QR Code Batch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Arahkan kamera ke QR Code batch beras yang akan dikeluarkan. Sistem akan memeriksa urutan FIFO sebelum stok keluar disimpan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  height: 48,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/stockout/botscan.png'),
                      fit: BoxFit.fill,
                    ),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _showManualQrDialog,
                    icon: const Icon(Icons.keyboard,
                        color: Colors.white, size: 20),
                    label: const Text(
                      'Input QR Manual',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding:
                          const EdgeInsets.only(left: 24, right: 24, bottom: 6),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
            if (_isProcessing) _buildProcessingOverlay(),
          ],
        ),
      ),
    );
  }
}

class QRViewFinderOverlay extends StatelessWidget {
  const QRViewFinderOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    const double scanAreaSize = 250.0;
    const double borderRadius = 24.0;

    return Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.6),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: scanAreaSize,
                  height: scanAreaSize,
                  margin: const EdgeInsets.only(bottom: 107),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Container(
            width: scanAreaSize,
            height: scanAreaSize,
            margin: const EdgeInsets.only(bottom: 107),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.white.withOpacity(0.5), width: 1.5),
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
                CustomPaint(
                  size: const Size(scanAreaSize, scanAreaSize),
                  painter: ScannerCornerPainter(
                    color: const Color(0xFF84E977),
                    strokeWidth: 4.0,
                    cornerLength: 40.0,
                    radius: borderRadius,
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white.withOpacity(0.5),
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ScannerCornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;
  final double radius;

  ScannerCornerPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    path.moveTo(0, cornerLength);
    path.lineTo(0, radius);
    path.arcToPoint(Offset(radius, 0), radius: Radius.circular(radius));
    path.lineTo(cornerLength, 0);

    path.moveTo(size.width - cornerLength, 0);
    path.lineTo(size.width - radius, 0);
    path.arcToPoint(Offset(size.width, radius),
        radius: Radius.circular(radius));
    path.lineTo(size.width, cornerLength);

    path.moveTo(0, size.height - cornerLength);
    path.lineTo(0, size.height - radius);
    path.arcToPoint(Offset(radius, size.height),
        radius: Radius.circular(radius), clockwise: false);
    path.lineTo(cornerLength, size.height);

    path.moveTo(size.width - cornerLength, size.height);
    path.lineTo(size.width - radius, size.height);
    path.arcToPoint(Offset(size.width, size.height - radius),
        radius: Radius.circular(radius), clockwise: false);
    path.lineTo(size.width, size.height - cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
