import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'stop_trip_picker.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _scanned = false;
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _scanned = true);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => StopTripPickerPage(stopId: rawValue)),
    );
  }

  void _showManualEntry() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enter Stop Code', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Type the stop number shown on the QR card at the stop.', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. 101',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.maroon,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final stopId = textController.text.trim();
              if (stopId.isEmpty) return;
              Navigator.pop(ctx);
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => StopTripPickerPage(stopId: stopId)),
                );
              }
            },
            child: const Text('Find Buses', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppTheme.maroon,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Scan Stop QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            tooltip: 'Toggle Flash',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Dark overlay with cutout
          ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.55), BlendMode.srcOut),
            child: Stack(
              children: [
                Container(decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut)),
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scan frame corners
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                children: [
                  // Top-left
                  Positioned(top: 0, left: 0, child: _corner(topLeft: true)),
                  // Top-right
                  Positioned(top: 0, right: 0, child: _corner(topRight: true)),
                  // Bottom-left
                  Positioned(bottom: 0, left: 0, child: _corner(bottomLeft: true)),
                  // Bottom-right
                  Positioned(bottom: 0, right: 0, child: _corner(bottomRight: true)),
                ],
              ),
            ),
          ),

          // Bottom instructions
          Positioned(
            bottom: 50,
            left: 24,
            right: 24,
            child: Column(
              children: [
                const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
                const SizedBox(height: 12),
                const Text(
                  'Point at the QR code at the bus stop',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _showManualEntry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.keyboard, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text('Enter stop code manually', style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _corner({bool topLeft = false, bool topRight = false, bool bottomLeft = false, bool bottomRight = false}) {
    return CustomPaint(
      size: const Size(30, 30),
      painter: _CornerPainter(
        topLeft: topLeft, topRight: topRight,
        bottomLeft: bottomLeft, bottomRight: bottomRight,
        color: AppTheme.maroon,
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool topLeft, topRight, bottomLeft, bottomRight;
  final Color color;
  const _CornerPainter({
    required this.color,
    this.topLeft = false, this.topRight = false,
    this.bottomLeft = false, this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 4..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path();
    if (topLeft) { path.moveTo(0, 20); path.lineTo(0, 0); path.lineTo(20, 0); }
    if (topRight) { path.moveTo(size.width - 20, 0); path.lineTo(size.width, 0); path.lineTo(size.width, 20); }
    if (bottomLeft) { path.moveTo(0, size.height - 20); path.lineTo(0, size.height); path.lineTo(20, size.height); }
    if (bottomRight) { path.moveTo(size.width - 20, size.height); path.lineTo(size.width, size.height); path.lineTo(size.width, size.height - 20); }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
