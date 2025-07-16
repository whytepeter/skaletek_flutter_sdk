import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_api_models.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/app_color.dart';
import 'dart:developer' as developer;
import 'detection_checks_list.dart';
import 'feedback_box.dart';
import 'camera_service.dart';
import '../../../services/websocket_service.dart';

class KYCCameraCapture extends StatefulWidget {
  final void Function(XFile file)? onCapture;
  final WebSocketService? wsService;
  const KYCCameraCapture({super.key, this.onCapture, this.wsService});

  @override
  State<KYCCameraCapture> createState() => _KYCCameraCaptureState();
}

class _KYCCameraCaptureState extends State<KYCCameraCapture>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _controller;
  CameraService? _cameraService;
  DetectionFeedback _feedback = DetectionFeedback(
    message: 'Initializing...',
    checks: const DetectionChecks(),
    connecting: true,
    feedbackState: FeedbackState.info,
  );

  // Cache layout calculations
  late Size _screenSize;
  late double _rectWidth;
  late double _rectHeight;
  late double _rectYOffset;
  late double _rectTop;
  late Rect _targetRect;

  // Performance optimization
  bool _isActive = true;
  DateTime? _lastRebuildTime;
  static const _minRebuildInterval = Duration(milliseconds: 16); // 60fps limit

  // Snackbar control
  DateTime? _lastSnackbarTime;
  static const _minSnackbarInterval = Duration(
    milliseconds: 500,
  ); // Prevent spam

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cacheLayoutCalculations();
  }

  void _cacheLayoutCalculations() {
    _screenSize = MediaQuery.of(context).size;
    _rectWidth = _screenSize.width * 0.9;
    _rectHeight = 220.0;
    _rectYOffset = 100.0;
    _rectTop = (_screenSize.height - _rectHeight) / 2 - _rectYOffset;

    _targetRect = Rect.fromLTWH(
      (_screenSize.width - _rectWidth) / 2,
      _rectTop,
      _rectWidth,
      _rectHeight,
    );
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        developer.log('No cameras available');
        return;
      }

      _controller = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg, // More efficient than default
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {});
        _initCameraService();
      }
    } catch (e) {
      developer.log('Error initializing camera: $e');
    }
  }

  void _initCameraService() {
    if (_controller == null || !mounted) return;

    _cameraService = CameraService(
      cameraController: _controller!,
      targetRect: _targetRect,
      screenSize: _screenSize, // Add screen size parameter
      wsService: widget.wsService, // Pass WebSocket service from widget
      onChecks: (checks) {
        // Detection checks callback - could be used for additional logic
      },
    );

    // Listen to feedback stream with throttling
    _cameraService!.feedbackStream.listen((feedback) {
      if (!mounted || !_isActive) return;

      // Show snackbar for testing purposes
      _showFeedbackSnackbar(feedback);

      // Throttle UI updates to prevent excessive rebuilds
      final now = DateTime.now();
      if (_lastRebuildTime != null &&
          now.difference(_lastRebuildTime!).inMilliseconds <
              _minRebuildInterval.inMilliseconds) {
        return;
      }
      _lastRebuildTime = now;

      if (feedback != _feedback) {
        setState(() {
          _feedback = feedback;
        });
      }
    });

    // Listen to capture stream
    _cameraService!.captureStream.listen((file) {
      if (mounted && _isActive) {
        widget.onCapture?.call(file);
      }
    });

    // Connect the service
    _cameraService!.connect();
  }

  void _showFeedbackSnackbar(DetectionFeedback feedback) {
    // Throttle snackbar to prevent spam
    final now = DateTime.now();
    if (_lastSnackbarTime != null &&
        now.difference(_lastSnackbarTime!).inMilliseconds <
            _minSnackbarInterval.inMilliseconds) {
      return;
    }
    _lastSnackbarTime = now;

    // Extract bbox information from feedback
    String bboxInfo = 'No bbox data';

    // Check if feedback has bbox information
    // This assumes your DetectionFeedback model has bbox data
    // You may need to adjust this based on your actual model structure
    if (feedback.bbox != null) {
      final bbox = feedback.bbox;
      bboxInfo =
          'BBox: (${bbox!.left.toStringAsFixed(1)}, ${bbox.top.toStringAsFixed(1)}, ${bbox.right.toStringAsFixed(1)}, ${bbox.bottom.toStringAsFixed(1)})';
    } else {
      bboxInfo = 'BBox: null';
    }

    // Create snackbar content
    final snackbarContent = '${feedback.message}\n$bboxInfo';

    // Determine snackbar color based on feedback state
    Color backgroundColor;
    if (feedback.connecting) {
      backgroundColor = Colors.blue;
    } else if (feedback.message.contains('error') ||
        feedback.message.contains('Error')) {
      backgroundColor = Colors.red;
    } else {
      backgroundColor = Colors.orange;
    }

    // Clear any existing snackbars
    ScaffoldMessenger.of(context).clearSnackBars();

    // Show new snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          snackbarContent,
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: 120, // Position above capture button
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    // Log for debugging
    developer.log('Feedback: ${feedback.message}, BBox: $bboxInfo');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _isActive = false;
        _cameraService?.disconnect();
        break;
      case AppLifecycleState.resumed:
        _isActive = true;
        _cameraService?.connect();
        break;
      case AppLifecycleState.detached:
        _isActive = false;
        break;
      case AppLifecycleState.hidden:
        _isActive = false;
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isActive = false;
    _cameraService?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Camera preview
            if (_controller != null && _controller!.value.isInitialized)
              Positioned.fill(child: CameraPreview(_controller!)),

            // Overlay with cutout
            if (_controller != null && _controller!.value.isInitialized)
              Positioned.fill(
                child: _RectangleOverlay(
                  rectWidth: _rectWidth,
                  rectHeight: _rectHeight,
                  rectYOffset: _rectYOffset,
                ),
              ),

            // Rectangle border (cutout)
            Positioned(
              left: (_screenSize.width - _rectWidth) / 2,
              top: _rectTop,
              width: _rectWidth,
              height: _rectHeight,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Detection checks list
            DetectionChecksList(
              detectionChecks: _feedback.checks,
              top: _rectTop + _rectHeight + 24,
            ),

            // Feedback box
            FeedbackBox(
              feedbackState: _feedback.feedbackState,
              feedbackText: _feedback.message,
            ),

            // Connecting overlay
            if (_feedback.connecting) _buildConnectingOverlay(),

            // UI controls
            _buildCloseButton(),
            if (_feedback.connected) _buildCaptureButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Connecting...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () => _cameraService?.capture(),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColor.light, width: 1),
            ),
            child: Icon(Icons.camera_alt, color: AppColor.primary, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Positioned(
      top: 32,
      right: 5,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
                side: BorderSide(color: AppColor.light),
              ),
            ),
            icon: Icon(Icons.close, color: Colors.grey[700], size: 24),
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 24,
            tooltip: 'Close',
          ),
        ),
      ),
    );
  }
}

/// Optimized rectangle overlay painter with caching
class _RectangleOverlay extends StatelessWidget {
  final double rectWidth;
  final double rectHeight;
  final double rectYOffset;

  const _RectangleOverlay({
    required this.rectWidth,
    required this.rectHeight,
    required this.rectYOffset,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - rectYOffset),
      width: rectWidth,
      height: rectHeight,
    );
    return RepaintBoundary(
      child: CustomPaint(
        size: size,
        painter: _RectangleOverlayPainter(rect: rect),
      ),
    );
  }
}

class _RectangleOverlayPainter extends CustomPainter {
  final Rect rect;

  _RectangleOverlayPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Create overlay with cutout
    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutout = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(10)));
    final finalPath = Path.combine(PathOperation.difference, overlay, cutout);

    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(_RectangleOverlayPainter oldDelegate) =>
      oldDelegate.rect != rect;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _RectangleOverlayPainter && other.rect == rect;
  }

  @override
  int get hashCode => rect.hashCode;
}
