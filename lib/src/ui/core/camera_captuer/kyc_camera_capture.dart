/// KYC Camera Capture Widget
///
/// A specialized camera interface for Know Your Customer (KYC) document verification.
/// This widget provides real-time document detection, positioning feedback, and automatic
/// capture capabilities using machine learning backend services.
///
/// ## Features
/// - Real-time camera preview with document detection overlay
/// - WebSocket-based ML backend integration for document analysis
/// - Visual feedback system with detection quality checks
/// - Automatic image capture when document is properly positioned
/// - Manual capture capability with precise cropping to target area
/// - Adaptive performance optimization based on network conditions
/// - Comprehensive error handling and connection management
///
/// ## Usage
/// ```dart
/// KYCCameraCapture(
///   onCapture: (XFile file) {
///     // Handle captured and cropped document image
///   },
///   wsService: myWebSocketService, // Optional: provide existing service
/// )
/// ```
///
/// ## Architecture
/// The widget coordinates several components:
/// - CameraController: Manages device camera access and image capture
/// - CameraService: Handles real-time detection and WebSocket communication
/// - UI Overlays: Provides visual feedback and positioning guides
/// - Detection System: Real-time quality and position analysis
///
/// ## Performance Optimizations
/// - Frame rate limiting to prevent excessive CPU usage
/// - UI rebuild throttling to maintain smooth performance
/// - Snackbar spam prevention for better UX
/// - Image format optimization (JPEG for capture, PNG for processing)
/// - Lifecycle-aware connection management
///
/// ## Image Processing Flow
/// 1. Camera captures frames in JPEG format for efficiency
/// 2. Real-time detection uses cropped regions for faster processing
/// 3. Final capture converts to PNG and crops to exact target rectangle
/// 4. Coordinate transformation accounts for camera orientation and scaling
///
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_api_models.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/app_color.dart';
import 'dart:developer' as developer;
import 'detection_checks_list.dart';
import 'feedback_box.dart';
import 'camera_service.dart';
import '../../../services/websocket_service.dart';

/// KYC Camera Capture Widget
///
/// A stateful widget that provides real-time document detection and capture
/// functionality for KYC verification processes. Integrates with ML backend
/// services via WebSocket for live feedback and automatic capture.
///
/// ## Parameters
/// - [onCapture]: Callback function called when an image is successfully captured
///   and cropped. Receives an [XFile] containing the processed document image.
/// - [wsService]: Optional WebSocket service instance. If not provided, the widget
///   will create and manage its own service instance.
///
/// ## Behavior
/// - Automatically initializes camera with high resolution
/// - Establishes WebSocket connection for real-time detection
/// - Provides visual overlay for document positioning
/// - Shows real-time feedback for image quality and positioning
/// - Triggers automatic capture when document is properly positioned
/// - Allows manual capture via capture button
/// - Handles app lifecycle changes for optimal battery usage
class KYCCameraCapture extends StatefulWidget {
  /// Callback function invoked when a document image is successfully captured and processed
  final void Function(XFile file)? onCapture;

  /// Optional WebSocket service for ML backend communication
  /// If null, the widget creates and manages its own service instance
  final WebSocketService? wsService;

  const KYCCameraCapture({super.key, this.onCapture, this.wsService});

  @override
  State<KYCCameraCapture> createState() => _KYCCameraCaptureState();
}

/// State class for KYCCameraCapture widget
///
/// Manages camera lifecycle, WebSocket connections, and UI state.
/// Implements performance optimizations including:
/// - UI rebuild throttling to maintain 60fps
/// - Snackbar spam prevention
/// - Lifecycle-aware connection management
/// - Cached layout calculations for smooth animations

class _KYCCameraCaptureState extends State<KYCCameraCapture>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Camera controller for device camera access and image capture
  CameraController? _controller;

  /// Service that handles real-time detection and WebSocket communication
  CameraService? _cameraService;

  /// Current detection feedback state displayed to the user
  DetectionFeedback _feedback = DetectionFeedback(
    message: 'Initializing...',
    checks: const DetectionChecks(),
    connecting: true,
    feedbackState: FeedbackState.info,
  );

  // Cache layout calculations for performance optimization
  /// Screen size cached to avoid repeated MediaQuery calls
  late Size _screenSize;

  /// Width of the document target rectangle (90% of screen width)
  late double _rectWidth;

  /// Height of the document target rectangle (fixed 220px)
  late double _rectHeight;

  /// Vertical offset to position rectangle above center
  late double _rectYOffset;

  /// Top position of the target rectangle on screen
  late double _rectTop;

  /// Complete target rectangle for document positioning
  late Rect _targetRect;

  // Performance optimization controls
  /// Flag to track if widget is active and should process updates
  bool _isActive = true;

  /// Timestamp of last UI rebuild to throttle updates
  DateTime? _lastRebuildTime;

  /// Minimum interval between UI rebuilds to maintain 60fps
  static const _minRebuildInterval = Duration(milliseconds: 16);

  // Snackbar spam prevention
  /// Timestamp of last snackbar shown to prevent spam
  DateTime? _lastSnackbarTime;

  /// Minimum interval between snackbars to prevent UI spam
  static const _minSnackbarInterval = Duration(milliseconds: 500);

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

  /// Caches layout calculations to avoid repeated MediaQuery calls
  ///
  /// Calculates and stores:
  /// - Screen dimensions
  /// - Target rectangle dimensions and position
  /// - Document positioning area
  ///
  /// Called during [didChangeDependencies] to handle orientation changes
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

  /// Initializes the device camera with optimal settings for document capture
  ///
  /// - Selects the first available camera (typically rear camera)
  /// - Configures high resolution for quality capture
  /// - Disables audio recording
  /// - Uses JPEG format for efficient capture and processing
  /// - Automatically proceeds to initialize camera service on success
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

  /// Initializes the camera service for real-time document detection
  ///
  /// Sets up:
  /// - CameraService with WebSocket communication
  /// - Real-time feedback stream with UI throttling
  /// - Automatic capture stream handling
  /// - WebSocket connection management
  ///
  /// The service handles ML backend communication for document detection,
  /// quality analysis, and automatic capture triggering.
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

  /// Displays detection feedback via snackbar with spam prevention
  ///
  /// Shows real-time feedback information including:
  /// - Detection message and guidance
  /// - Bounding box coordinates for debugging
  /// - Connection status indicators
  /// - Color-coded feedback based on detection state
  ///
  /// Features:
  /// - Throttled to prevent UI spam (500ms minimum interval)
  /// - Positioned above capture button for optimal UX
  /// - Color-coded background based on feedback type
  /// - Automatic clearing of previous snackbars
  /// TODO: remove this function before publishing
  void _showFeedbackSnackbar(DetectionFeedback feedback) {
    return;
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

/// Optimized rectangle overlay that creates a darkened background with document cutout
///
/// Creates a semi-transparent overlay with a rectangular cutout for document positioning.
/// The overlay helps users visualize where to place their document for optimal capture.
///
/// Features:
/// - Wrapped in RepaintBoundary for optimal performance
/// - Cached painting to minimize GPU operations
/// - Rounded corners matching the target rectangle
/// - Configurable dimensions and positioning
///
/// ## Parameters
/// - [rectWidth]: Width of the document target area
/// - [rectHeight]: Height of the document target area
/// - [rectYOffset]: Vertical offset from center for optimal positioning
class _RectangleOverlay extends StatelessWidget {
  /// Width of the document cutout rectangle
  final double rectWidth;

  /// Height of the document cutout rectangle
  final double rectHeight;

  /// Vertical offset from center to position the cutout optimally
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

/// Custom painter that renders the overlay with document cutout
///
/// Efficiently paints a semi-transparent overlay with a rectangular cutout
/// using path operations to create the desired visual effect.
///
/// ## Implementation Details
/// - Uses path difference operation to create cutout effect
/// - Applies rounded corners to match target rectangle styling
/// - Optimized shouldRepaint logic to minimize unnecessary redraws
/// - Implements proper equality and hashCode for widget optimization
///
/// ## Parameters
/// - [rect]: The rectangular area to cut out from the overlay
class _RectangleOverlayPainter extends CustomPainter {
  /// The rectangular area that will be cut out from the overlay
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
