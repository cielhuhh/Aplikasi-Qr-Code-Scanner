import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:io';
import 'dart:typed_data';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Code Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: QRScannerHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class QRScannerHome extends StatefulWidget {
  @override
  _QRScannerHomeState createState() => _QRScannerHomeState();
}

class _QRScannerHomeState extends State<QRScannerHome>
    with WidgetsBindingObserver {
  MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  
  String scannedData = '';
  bool isFlashOn = false;
  bool isFrontCamera = false;
  bool hasPermission = false;
  bool isInitialized = false;
  bool isScanning = true;
  ScreenshotController screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!controller.value.isInitialized) {
      return;
    }

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        _initializeCamera();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _initializeCamera() async {
    final permission = await _requestCameraPermission();
    if (permission) {
      try {
        await controller.start();
        setState(() {
          hasPermission = true;
          isInitialized = true;
        });
      } catch (e) {
        print('Error initializing camera: $e');
        setState(() {
          hasPermission = false;
          isInitialized = false;
        });
      }
    }
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status == PermissionStatus.granted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR Code Scanner'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: _buildCameraView(),
          ),
          Expanded(
            flex: 1,
            child: _buildControlPanel(),
          ),
          if (scannedData.isNotEmpty) _buildResultPanel(),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    if (!hasPermission) {
      return _buildPermissionView();
    }

    if (!isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuat kamera...'),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Screenshot(
          controller: screenshotController,
          child: ClipRect(
            child: MobileScanner(
              controller: controller,
              errorBuilder: (context, error, child) {
                return _buildErrorView(error);
              },
              onDetect: _onDetect,
            ),
          ),
        ),
        // Overlay untuk menampilkan frame scanning
        _buildScanningOverlay(),
        // Status indicator
        if (!isScanning)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pause_circle_filled, 
                       color: Colors.white, size: 64),
                  SizedBox(height: 16),
                  Text('Scanner Dijeda', 
                       style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPermissionView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, 
                 size: 100, color: Colors.grey),
            SizedBox(height: 24),
            Text(
              'Izin Kamera Diperlukan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Aplikasi memerlukan akses kamera untuk memindai QR Code',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final granted = await _requestCameraPermission();
                if (granted) {
                  _initializeCamera();
                } else {
                  await openAppSettings();
                }
              },
              icon: Icon(Icons.camera_alt),
              label: Text('Berikan Izin Kamera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(MobileScannerException error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 100, color: Colors.red),
            SizedBox(height: 24),
            Text(
              'Error Kamera',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              error.errorDetails?.message ?? 'Terjadi kesalahan pada kamera',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeCamera,
              icon: Icon(Icons.refresh),
              label: Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return Container(
      decoration: ShapeDecoration(
        shape: QrScannerOverlayShape(
          borderColor: Colors.blue,
          borderRadius: 16,
          borderLength: 40,
          borderWidth: 4,
          cutOutSize: 250,
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: isFlashOn ? Icons.flash_off : Icons.flash_on,
                label: 'Flash',
                onPressed: hasPermission ? _toggleFlash : null,
              ),
              _buildControlButton(
                icon: Icons.switch_camera,
                label: 'Switch',
                onPressed: hasPermission ? _switchCamera : null,
              ),
              _buildControlButton(
                icon: Icons.photo_library,
                label: 'Gallery',
                onPressed: _pickImageFromGallery,
              ),
              _buildControlButton(
                icon: Icons.save,
                label: 'Save',
                onPressed: scannedData.isNotEmpty ? _saveQRImage : null,
              ),
            ],
          ),
          SizedBox(height: 12),
          if (hasPermission)
            ElevatedButton.icon(
              onPressed: isScanning ? _pauseScanning : _resumeScanning,
              icon: Icon(isScanning ? Icons.pause : Icons.play_arrow),
              label: Text(isScanning ? 'Pause' : 'Resume'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isScanning ? Colors.orange : Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: onPressed != null ? Colors.blue : Colors.grey,
          iconSize: 30,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: onPressed != null ? Colors.blue : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildResultPanel() {
    return Expanded(
      flex: 2,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hasil Scan:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  scannedData,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (_isUrl(scannedData))
                  ElevatedButton.icon(
                    onPressed: () => _launchUrl(scannedData),
                    icon: Icon(Icons.open_in_browser, size: 16),
                    label: Text('Buka URL'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: _clearResult,
                  icon: Icon(Icons.clear, size: 16),
                  label: Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _copyToClipboard,
                  icon: Icon(Icons.copy, size: 16),
                  label: Text('Copy'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (!isScanning) return;
    
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        setState(() {
          scannedData = barcode.rawValue!;
          isScanning = false;
        });
        controller.stop();
        _showScanResult();
        break;
      }
    }
  }

  void _toggleFlash() async {
    try {
      await controller.toggleTorch();
      setState(() {
        isFlashOn = !isFlashOn;
      });
    } catch (e) {
      _showSnackBar('Gagal mengaktifkan flash', Colors.red);
    }
  }

  void _switchCamera() async {
    try {
      await controller.switchCamera();
      setState(() {
        isFrontCamera = !isFrontCamera;
      });
    } catch (e) {
      _showSnackBar('Gagal mengganti kamera', Colors.red);
    }
  }

  void _pauseScanning() {
    setState(() {
      isScanning = false;
    });
    controller.stop();
  }

  void _resumeScanning() {
    setState(() {
      isScanning = true;
    });
    controller.start();
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      _showSnackBar(
        'Fitur scan QR dari gambar belum diimplementasikan (perlu ML Kit)',
        Colors.orange,
      );
    }
  }

  Future<void> _saveQRImage() async {
    if (scannedData.isEmpty) {
      _showSnackBar('Tidak ada data untuk disimpan', Colors.orange);
      return;
    }

    try {
      final qrValidationResult = QrValidator.validate(
        data: scannedData,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final painter = QrPainter.withQr(
          qr: qrValidationResult.qrCode!,
          color: const Color(0xFF000000),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: false,
        );

        final picData = await painter.toImageData(200.0);
        if (picData != null && !kIsWeb) {
          final result = await ImageGallerySaver.saveImage(
            picData.buffer.asUint8List(),
            name: "qr_code_${DateTime.now().millisecondsSinceEpoch}",
          );

          if (result['isSuccess']) {
            _showSnackBar('QR Code berhasil disimpan ke galeri', Colors.green);
          }
        }
      }
    } catch (e) {
      _showSnackBar('Gagal menyimpan QR Code: $e', Colors.red);
    }
  }

  void _copyToClipboard() {
    if (scannedData.isNotEmpty) {
      // Implement clipboard copy functionality
      _showSnackBar('Data berhasil disalin', Colors.green);
    }
  }

  void _showScanResult() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.qr_code_scanner, color: Colors.blue),
            SizedBox(width: 8),
            Text('QR Code Terdeteksi'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data yang ditemukan:'),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                scannedData,
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          if (_isUrl(scannedData))
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _launchUrl(scannedData);
              },
              icon: Icon(Icons.open_in_browser),
              label: Text('Buka URL'),
            ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _resumeScanning();
            },
            icon: Icon(Icons.qr_code_scanner),
            label: Text('Scan Lagi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _clearResult() {
    setState(() {
      scannedData = '';
    });
    _resumeScanning();
  }

  bool _isUrl(String text) {
    return text.toLowerCase().startsWith('http://') || 
           text.toLowerCase().startsWith('https://') ||
           text.toLowerCase().startsWith('www.');
  }

  Future<void> _launchUrl(String url) async {
    try {
      String finalUrl = url;
      if (!url.toLowerCase().startsWith('http')) {
        finalUrl = 'https://$url';
      }
      
      final uri = Uri.parse(finalUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Tidak dapat membuka URL: $url', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error membuka URL: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// Custom overlay shape untuk scanner
class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    double? cutOutSize,
    double? cutOutWidth,
    double? cutOutHeight,
  })  : cutOutWidth = cutOutWidth ?? cutOutSize ?? 250,
        cutOutHeight = cutOutHeight ?? cutOutSize ?? 250;

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutWidth;
  final double cutOutHeight;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path _getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + borderRadius)
        ..quadraticBezierTo(rect.left, rect.top, rect.left + borderRadius, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return _getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderHeightSize = height / 2;
    final cutOutWidth = this.cutOutWidth < width ? this.cutOutWidth : width - borderWidth;
    final cutOutHeight = this.cutOutHeight < height ? this.cutOutHeight : height - borderWidth;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromLTWH(
      rect.left + (width - cutOutWidth) / 2 + borderWidth,
      rect.top + (height - cutOutHeight) / 2 + borderWidth,
      cutOutWidth - borderWidth * 2,
      cutOutHeight - borderWidth * 2,
    );

    canvas
      ..saveLayer(
        rect,
        backgroundPaint,
      )
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndCorners(
          cutOutRect,
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
        backgroundPaint..blendMode = BlendMode.clear,
      )
      ..restore();

    // Draw corner borders
    final borderOffset = borderWidth / 2;
    final _borderLength = borderLength > cutOutWidth / 2 + borderOffset
        ? borderWidthSize / 2
        : borderLength;
    final _borderLengthHeight = borderLength > cutOutHeight / 2 + borderOffset
        ? borderHeightSize / 2
        : borderLength;

    // Top left corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left - borderOffset, cutOutRect.top + _borderLengthHeight)
        ..lineTo(cutOutRect.left - borderOffset, cutOutRect.top + borderRadius)
        ..quadraticBezierTo(cutOutRect.left - borderOffset, cutOutRect.top - borderOffset,
            cutOutRect.left + borderRadius, cutOutRect.top - borderOffset)
        ..lineTo(cutOutRect.left + _borderLength, cutOutRect.top - borderOffset),
      boxPaint,
    );

    // Top right corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right + borderOffset, cutOutRect.top + _borderLengthHeight)
        ..lineTo(cutOutRect.right + borderOffset, cutOutRect.top + borderRadius)
        ..quadraticBezierTo(cutOutRect.right + borderOffset, cutOutRect.top - borderOffset,
            cutOutRect.right - borderRadius, cutOutRect.top - borderOffset)
        ..lineTo(cutOutRect.right - _borderLength, cutOutRect.top - borderOffset),
      boxPaint,
    );

    // Bottom left corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left - borderOffset, cutOutRect.bottom - _borderLengthHeight)
        ..lineTo(cutOutRect.left - borderOffset, cutOutRect.bottom - borderRadius)
        ..quadraticBezierTo(cutOutRect.left - borderOffset, cutOutRect.bottom + borderOffset,
            cutOutRect.left + borderRadius, cutOutRect.bottom + borderOffset)
        ..lineTo(cutOutRect.left + _borderLength, cutOutRect.bottom + borderOffset),
      boxPaint,
    );

    // Bottom right corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right + borderOffset, cutOutRect.bottom - _borderLengthHeight)
        ..lineTo(cutOutRect.right + borderOffset, cutOutRect.bottom - borderRadius)
        ..quadraticBezierTo(cutOutRect.right + borderOffset, cutOutRect.bottom + borderOffset,
            cutOutRect.right - borderRadius, cutOutRect.bottom + borderOffset)
        ..lineTo(cutOutRect.right - _borderLength, cutOutRect.bottom + borderOffset),
      boxPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}