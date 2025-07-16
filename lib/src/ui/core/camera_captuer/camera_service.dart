/// CameraService
///
/// Handles real-time document detection for KYC using a WebSocket ML backend.
///
/// Optimizations:
/// - Frame rate limiting and adaptive quality
/// - Memory pooling for image processing
/// - Debounced feedback updates
/// - Enhanced error handling and connection management
/// - Performance monitoring and automatic quality adjustment
/// - PNG image encoding for consistent format

import 'dart:async';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../models/kyc_api_models.dart';
import '../../../utils/image_cropper.dart';
import '../../../services/websocket_service.dart';

// Detection timing constants
const Duration _kDefaultDetectionInterval = Duration(milliseconds: 100);
const Duration _kMinDetectionInterval = Duration(milliseconds: 50);
const Duration _kMaxDetectionInterval = Duration(milliseconds: 200);
const Duration _kSteadyDelay = Duration(milliseconds: 3000);

// Image quality constants
const double _kDefaultImageQuality = 0.8;
const double _kMinImageQuality = 0.3;
const double _kMaxImageQuality = 0.95;
const double _kDefaultImageScale = 1.0;
const double _kMinImageScale = 0.4;

// Performance monitoring constants
const int _kMaxPerformanceSamples = 10;
const double _kPoorPerformanceThreshold = 200.0; // milliseconds
const double _kGoodPerformanceThreshold = 100.0; // milliseconds
const double _kSlowNetworkThreshold = 800.0; // milliseconds
const double _kFastNetworkThreshold = 300.0; // milliseconds

// Feedback and detection constants
const double _kPositionTolerance = 40.0;
const double _kCropPadding = 10.0; // pixels
const double _kDetectionCropPadding = 0.25; // 25% vertical padding

/// Feedback state for UI overlays
enum FeedbackState { info, error, success }

/// Feedback message types for better organization
enum FeedbackMessage {
  default_('Fit ID card in the box'),
  good('Right spot! Hold steady'),
  tooLow('Too low — raise it a bit.'),
  tooHigh('Too high — lower it a bit.'),
  moveLeft('Move left slightly.'),
  moveRight('Move right slightly.'),
  goodPositionBadQuality('Good position! Improve lighting and focus'),
  connecting('Connecting…'),
  disconnected('Disconnected. Reconnecting…'),
  connectionError('Connection error. Reconnecting…'),
  processingError('Processing error occurred'),
  captured('Captured!');

  const FeedbackMessage(this.text);
  final String text;
}

class DetectionFeedback {
  final String message;
  final DetectionChecks checks;
  final bool analyzing;
  final bool connecting;
  final bool connected;
  final Rect? bbox;
  final FeedbackState feedbackState;

  DetectionFeedback({
    required this.message,
    required this.checks,
    this.analyzing = false,
    this.connecting = false,
    this.connected = false,
    this.bbox,
    this.feedbackState = FeedbackState.info,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DetectionFeedback &&
        other.message == message &&
        other.checks == checks &&
        other.analyzing == analyzing &&
        other.connecting == connecting &&
        other.connected == connected &&
        other.bbox == bbox &&
        other.feedbackState == feedbackState;
  }

  @override
  int get hashCode => Object.hash(
    message,
    checks,
    analyzing,
    connecting,
    connected,
    bbox,
    feedbackState,
  );
}

/// Performance metrics for adaptive quality and network optimization
class _PerformanceMetrics {
  final List<int> _processingTimes = [];
  final List<int> _networkResponseTimes = [];

  void addProcessingTime(int milliseconds) {
    _processingTimes.add(milliseconds);
    if (_processingTimes.length > _kMaxPerformanceSamples) {
      _processingTimes.removeAt(0);
    }
  }

  void addNetworkResponseTime(int milliseconds) {
    _networkResponseTimes.add(milliseconds);
    if (_networkResponseTimes.length > _kMaxPerformanceSamples) {
      _networkResponseTimes.removeAt(0);
    }
  }

  double get averageProcessingTime {
    if (_processingTimes.isEmpty) return 0;
    return _processingTimes.reduce((a, b) => a + b) / _processingTimes.length;
  }

  double get averageNetworkResponseTime {
    if (_networkResponseTimes.isEmpty) return 0;
    return _networkResponseTimes.reduce((a, b) => a + b) /
        _networkResponseTimes.length;
  }

  bool get isPerformancePoor =>
      averageProcessingTime > _kPoorPerformanceThreshold ||
      averageNetworkResponseTime > 1000;
  bool get isPerformanceGood =>
      averageProcessingTime < _kGoodPerformanceThreshold &&
      averageNetworkResponseTime < 500;
  bool get isNetworkSlow => averageNetworkResponseTime > _kSlowNetworkThreshold;
  bool get isNetworkFast => averageNetworkResponseTime < _kFastNetworkThreshold;
}

class CameraService {
  final CameraController cameraController;
  final Rect targetRect;
  final void Function(DetectionChecks) onChecks;
  final Size screenSize; // Add screen size for coordinate transformation

  // Adaptive configuration for network optimization
  Duration _currentDetectionInterval = _kDefaultDetectionInterval;

  // Dynamic image quality and compression settings
  double _currentImageQuality = _kDefaultImageQuality;
  double _currentImageScale = _kDefaultImageScale;

  // WebSocket service
  final WebSocketService _wsService;
  final bool
  _wsServiceProvided; // Track if WebSocket service was provided externally
  StreamSubscription? _wsStatusSub;
  StreamSubscription? _wsMessageSub;
  StreamSubscription? _wsErrorSub;

  Timer? _detectionTimer;
  Timer? _steadyTimer;
  Timer? _performanceTimer;
  Timer? _debounceTimer;
  Timer? _periodicCaptureTimer;

  bool _pendingRequest = false;
  bool _disposed = false;
  DateTime? _lastFrameTime;
  DateTime? _requestStartTime; // Track network request timing

  DetectionChecks _lastChecks = const DetectionChecks();
  Rect? _lastBbox;

  final _performanceMetrics = _PerformanceMetrics();
  final _feedbackController = StreamController<DetectionFeedback>.broadcast();
  final _captureController = StreamController<XFile>.broadcast();

  CameraImage? _latestCameraImage;
  bool _isStreaming = false;
  DateTime? _steadyStartTime;
  Rect? _lastSteadyBbox;
  bool _captureTriggered = false;

  CameraService({
    required this.cameraController,
    required this.targetRect,
    required this.onChecks,
    required this.screenSize, // Add required screen size parameter
    WebSocketService? wsService, // Accept optional WebSocket service
  }) : _wsServiceProvided = wsService != null,
       _wsService = wsService ?? WebSocketService() {
    _initWebSocketListeners();
    _startPerformanceMonitoring();
  }

  Stream<DetectionFeedback> get feedbackStream => _feedbackController.stream;
  Stream<XFile> get captureStream => _captureController.stream;

  /// Initialize WebSocket event listeners
  void _initWebSocketListeners() {
    // Check initial status for externally provided services
    if (_wsServiceProvided) {
      _handleInitialWebSocketStatus();
    }

    // Listen to connection status changes
    _wsStatusSub = _wsService.statusStream.listen((status) {
      switch (status) {
        case WebSocketStatus.connecting:
          _emitFeedback(
            DetectionFeedback(
              message: FeedbackMessage.connecting.text,
              checks: _lastChecks,
              connecting: true,
              connected: false,
              analyzing: false,
              feedbackState: FeedbackState.info,
            ),
          );
          break;
        case WebSocketStatus.connected:
          _pendingRequest = false;
          _emitFeedback(
            DetectionFeedback(
              message: FeedbackMessage.default_.text,
              checks: _lastChecks,
              connecting: false,
              connected: true,
              analyzing: false,
              feedbackState: FeedbackState.info,
            ),
          );
          _startDetectionLoop();
          break;
        case WebSocketStatus.disconnected:
          _pendingRequest = false;
          _detectionTimer?.cancel();
          _emitFeedback(
            DetectionFeedback(
              message: FeedbackMessage.disconnected.text,
              checks: _lastChecks,
              connecting: true,
              connected: false,
              analyzing: false,
              feedbackState: FeedbackState.info,
            ),
          );
          break;
        case WebSocketStatus.error:
          _pendingRequest = false;
          _detectionTimer?.cancel();
          _emitFeedback(
            DetectionFeedback(
              message: FeedbackMessage.connectionError.text,
              checks: _lastChecks,
              connecting: true,
              connected: false,
              analyzing: false,
              feedbackState: FeedbackState.error,
            ),
          );
          break;
      }
    });

    // Listen to WebSocket messages
    _wsMessageSub = _wsService.messageStream.listen(_onWsMessage);

    // Listen to WebSocket errors
    _wsErrorSub = _wsService.errorStream.listen((error) {
      developer.log('WebSocket error: $error');
    });
  }

  /// Handle initial WebSocket status for externally provided services
  void _handleInitialWebSocketStatus() {
    final currentStatus = _wsService.status;

    switch (currentStatus) {
      case WebSocketStatus.connected:
        // Service is already connected, emit connected state immediately
        _pendingRequest = false;
        _emitFeedback(
          DetectionFeedback(
            message: FeedbackMessage.default_.text,
            checks: _lastChecks,
            connecting: false,
            connected: true,
            analyzing: false,
            feedbackState: FeedbackState.info,
          ),
        );
        _startDetectionLoop();
        break;
      case WebSocketStatus.connecting:
        // Service is connecting, show connecting state
        _emitFeedback(
          DetectionFeedback(
            message: FeedbackMessage.connecting.text,
            checks: _lastChecks,
            connecting: true,
            connected: false,
            analyzing: false,
            feedbackState: FeedbackState.info,
          ),
        );
        break;
      case WebSocketStatus.disconnected:
      case WebSocketStatus.error:
        // Service is disconnected/error, show appropriate state
        _emitFeedback(
          DetectionFeedback(
            message: FeedbackMessage.disconnected.text,
            checks: _lastChecks,
            connecting: false,
            connected: false,
            analyzing: false,
            feedbackState: FeedbackState.info,
          ),
        );
        break;
    }
  }

  void connect() {
    if (_disposed) return;

    // Only connect if we created the WebSocket service ourselves
    // If it was provided externally, it should already be connected and handled in initialization
    if (!_wsServiceProvided) {
      _wsService.connect();
    }

    //Start periodic capture check as additional fallback
    _startPeriodicCaptureCheck();
    // Note: For externally provided services, status is already handled in _handleInitialWebSocketStatus
  }

  void _onWsMessage(Map<String, dynamic> data) {
    if (_disposed) return;

    final processingStart = DateTime.now();

    // Track network response time for adaptive optimization
    if (_requestStartTime != null) {
      final networkResponseTime = processingStart
          .difference(_requestStartTime!)
          .inMilliseconds;
      _performanceMetrics.addNetworkResponseTime(networkResponseTime);
      developer.log('Network response time: ${networkResponseTime}ms');
    }

    _pendingRequest = false;

    try {
      developer.log('Received message: $data');

      // Handle error responses from the server
      if (data['success'] == false) {
        developer.log('Server returned error response: $data');
        _emitFeedback(
          DetectionFeedback(
            message: FeedbackMessage.default_.text,
            checks: const DetectionChecks(),
            connecting: false,
            connected: true,
            analyzing: false,
            feedbackState: FeedbackState.info,
            bbox: null,
          ),
        );
        return;
      }

      // Process successful detection results
      final checksData = data['checks'];
      final DetectionChecks checks;

      if (checksData is Map<String, dynamic>) {
        checks = DetectionChecks.fromMap(checksData);
      } else {
        // Use default checks if no valid checks data
        checks = const DetectionChecks();
      }

      onChecks(checks);
      _lastChecks = checks;

      final bboxList = data['bbox'];
      Rect? bbox;
      if (bboxList is List && bboxList.length == 4) {
        try {
          // Most ML services return bbox as [left, top, right, bottom] (LTRB format)
          final left = (bboxList[0] as num).toDouble();
          final top = (bboxList[1] as num).toDouble();
          final right = (bboxList[2] as num).toDouble();
          final bottom = (bboxList[3] as num).toDouble();

          final croppedBbox = Rect.fromLTRB(left, top, right, bottom);

          developer.log(
            'Parsed bbox from cropped image: left=$left, top=$top, right=$right, bottom=$bottom',
          );

          // Transform bbox from cropped image coordinates back to screen coordinates
          bbox = _transformBboxFromCroppedToScreen(croppedBbox);

          developer.log('Transformed bbox to screen coordinates: $bbox');
        } catch (e) {
          developer.log('Error parsing bbox: $e');
          bbox = null;
        }
      }
      _lastBbox = bbox;

      // Record performance metrics
      final processingTime = DateTime.now()
          .difference(processingStart)
          .inMilliseconds;
      _performanceMetrics.addProcessingTime(processingTime);

      _handleFeedback(bbox, checks);
    } catch (e, stackTrace) {
      developer.log('Error processing WebSocket message: $e');
      developer.log('Stack trace: $stackTrace');
      developer.log('Message content: $data');

      // Emit error feedback to user
      _emitFeedback(
        DetectionFeedback(
          message: FeedbackMessage.processingError.text,
          checks: _lastChecks,
          connecting: false,
          connected: true,
          analyzing: false,
          feedbackState: FeedbackState.error,
        ),
      );
    }
  }

  void _startDetectionLoop() {
    _detectionTimer?.cancel();
    _startImageStream(); // Start image stream for silent capture

    _detectionTimer = Timer.periodic(_currentDetectionInterval, (_) async {
      if (_disposed || !_wsService.isConnected || _pendingRequest) return;

      // Frame rate limiting
      final now = DateTime.now();
      if (_lastFrameTime != null &&
          now.difference(_lastFrameTime!).inMilliseconds <
              _currentDetectionInterval.inMilliseconds) {
        return;
      }
      _lastFrameTime = now;

      _pendingRequest = true;
      _requestStartTime = DateTime.now(); // Track request start time

      try {
        if (_latestCameraImage != null) {
          final arrayBuffer = await _processCameraImage(_latestCameraImage!);
          if (arrayBuffer != null && !_disposed) {
            developer.log(
              'Sending optimized image data: ${arrayBuffer.length} bytes',
            );
            _wsService.send(arrayBuffer);
          } else {
            _pendingRequest = false;
          }
        } else {
          _pendingRequest = false;
        }
      } catch (e) {
        _pendingRequest = false;
        developer.log('Error processing camera image: $e');
      }
    });
  }

  /// Start camera image stream for silent frame capture
  void _startImageStream() async {
    if (_isStreaming || _disposed) return;

    try {
      await cameraController.startImageStream((image) {
        _latestCameraImage = image;
      });
      _isStreaming = true;
      developer.log('Image stream started');
    } catch (e) {
      developer.log('Error starting image stream: $e');
    }
  }

  /// Stop camera image stream
  void _stopImageStream() {
    if (!_isStreaming) return;

    try {
      cameraController.stopImageStream();
      _isStreaming = false;
      _latestCameraImage = null;
      developer.log('Image stream stopped');
    } catch (e) {
      developer.log('Error stopping image stream: $e');
    }
  }

  /// Process camera image for detection
  Future<Uint8List?> _processCameraImage(CameraImage image) async {
    try {
      // Convert CameraImage to PNG bytes
      final pngBytes = await _convertCameraImageToPng(image);
      final croppedBytes = await _cropImageForDetection(pngBytes);
      final optimizedBytes = await _applyAdaptiveImageOptimization(
        croppedBytes,
      );

      return optimizedBytes;
    } catch (e) {
      developer.log('Error processing camera image: $e');
      return null;
    }
  }

  /// Convert CameraImage to PNG format
  Future<Uint8List> _convertCameraImageToPng(CameraImage image) async {
    try {
      ui.Image convertedImage;
      if (image.format.group == ImageFormatGroup.yuv420) {
        convertedImage = await _convertYUV420ToImage(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        convertedImage = await _convertBGRA8888ToImage(image);
      } else {
        throw Exception('Unsupported image format: ${image.format}');
      }

      final byteData = await convertedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData!.buffer.asUint8List();
    } catch (e) {
      developer.log('Error converting camera image: $e');
      rethrow;
    }
  }

  /// Convert YUV420 format to PNG
  Future<ui.Image> _convertYUV420ToImage(CameraImage image) async {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final yStride = yPlane.bytesPerRow;
    final uStride = uPlane.bytesPerRow;
    final vStride = vPlane.bytesPerRow;

    final rgbaBuffer = Uint8List(width * height * 4);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final uvIndex = (x ~/ 2) + (y ~/ 2) * (uStride ~/ 2);
        final yIndex = x + y * yStride;

        final yValue = yBuffer[yIndex];
        final uValue = uBuffer[uvIndex];
        final vValue = vBuffer[uvIndex];

        // YUV to RGB conversion
        final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final g =
            (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
                .clamp(0, 255)
                .toInt();
        final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        final index = (x + y * width) * 4;
        rgbaBuffer[index] = r;
        rgbaBuffer[index + 1] = g;
        rgbaBuffer[index + 2] = b;
        rgbaBuffer[index + 3] = 255; // Alpha
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgbaBuffer,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (result) {
        completer.complete(result);
      },
    );

    return completer.future;
  }

  /// Convert BGRA8888 format to PNG
  Future<ui.Image> _convertBGRA8888ToImage(CameraImage image) async {
    final width = image.width;
    final height = image.height;
    final plane = image.planes[0];
    final bytes = plane.bytes;
    final bytesPerRow = plane.bytesPerRow;

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(bytes, width, height, ui.PixelFormat.bgra8888, (
      result,
    ) {
      completer.complete(result);
    }, rowBytes: bytesPerRow);

    return completer.future;
  }

  /// Crops image using same logic as manual capture but with full width and 25% vertical padding
  /// Matches the coordinate transformation used in manual capture for consistency
  Future<Uint8List> _cropImageForDetection(Uint8List originalBytes) async {
    try {
      // Convert to PNG and get actual image dimensions (same as manual capture)
      final pngBytes = await ImageCropper.convertToPng(originalBytes);
      final codec = await ui.instantiateImageCodec(pngBytes);
      final frame = await codec.getNextFrame();
      final actualImage = frame.image;
      final imageWidth = actualImage.width.toDouble();
      final imageHeight = actualImage.height.toDouble();

      // Get camera preview size (note: in portrait mode, width/height are swapped)
      final previewSize = cameraController.value.previewSize!;
      final cameraWidth = previewSize.height
          .toDouble(); // Actual camera width in portrait
      final cameraHeight = previewSize.width
          .toDouble(); // Actual camera height in portrait

      // Calculate how the camera preview is displayed on screen
      final screenWidth = screenSize.width;
      final screenHeight = screenSize.height;

      // Camera preview is typically scaled to fill the screen height and center-cropped for width
      final previewScale = screenHeight / cameraHeight;
      final scaledPreviewWidth = cameraWidth * previewScale;

      // If scaled preview is wider than screen, it gets center-cropped
      final cropOffsetX = (scaledPreviewWidth - screenWidth) / 2;

      // Calculate the actual scaling from screen coordinates to image coordinates
      final scaleX = imageWidth / cameraWidth;
      final scaleY = imageHeight / cameraHeight;

      developer.log(
        'Detection crop - Image: ${imageWidth}x${imageHeight}, Camera: ${cameraWidth}x${cameraHeight}',
      );
      developer.log(
        'Detection crop - Screen: ${screenWidth}x${screenHeight}, Scale: $previewScale, OffsetX: $cropOffsetX',
      );

      // Create extended target rectangle: full width, target height + padding top/bottom
      final targetHeight = targetRect.height;
      final verticalPadding = targetHeight * _kDetectionCropPadding;

      final extendedTargetRect = Rect.fromLTWH(
        0, // Full width - start from screen left
        targetRect.top - verticalPadding, // 25% more above target
        screenWidth, // Full screen width
        targetRect.height +
            (2 * verticalPadding), // Target height + 25% top + 25% bottom
      );

      // Transform extended target rectangle from screen coordinates to camera coordinates
      final cameraTargetRect = Rect.fromLTWH(
        (extendedTargetRect.left + cropOffsetX) / previewScale,
        extendedTargetRect.top / previewScale,
        extendedTargetRect.width / previewScale,
        extendedTargetRect.height / previewScale,
      );

      // Then scale from camera coordinates to actual image coordinates
      final imageTargetRect = Rect.fromLTWH(
        cameraTargetRect.left * scaleX,
        cameraTargetRect.top * scaleY,
        cameraTargetRect.width * scaleX,
        cameraTargetRect.height * scaleY,
      );

      // Clamp to image bounds to prevent cropping outside image
      final finalCropRect = Rect.fromLTRB(
        imageTargetRect.left.clamp(0.0, imageWidth),
        imageTargetRect.top.clamp(0.0, imageHeight),
        imageTargetRect.right.clamp(0.0, imageWidth),
        imageTargetRect.bottom.clamp(0.0, imageHeight),
      );

      developer.log('Detection crop - Extended target: $extendedTargetRect');
      developer.log('Detection crop - Camera target: $cameraTargetRect');
      developer.log('Detection crop - Image target: $imageTargetRect');
      developer.log('Detection crop - Final clamped: $finalCropRect');

      // Convert to bbox format for cropping (same as manual capture)
      final targetBboxList = [
        finalCropRect.left,
        finalCropRect.top,
        finalCropRect.right,
        finalCropRect.bottom,
      ];

      // Use ImageCropper.cropImage (same as manual capture)
      final croppedBytes = await ImageCropper.cropImage(
        pngBytes,
        targetBboxList,
      );

      developer.log(
        'Detection crop completed: ${originalBytes.length} → ${croppedBytes.length} bytes '
        '(${((croppedBytes.length / originalBytes.length) * 100).toStringAsFixed(1)}% of original)',
      );

      return croppedBytes;
    } catch (e) {
      developer.log('Error cropping image for detection: $e');
      return originalBytes; // Return original if cropping fails
    }
  }

  /// Transforms bbox coordinates from cropped image space back to screen coordinates
  /// This accounts for the cropping we did before sending to the server
  Rect _transformBboxFromCroppedToScreen(Rect croppedBbox) {
    try {
      // Calculate the cropping offset we used (same as in _cropImageForDetection)
      final targetHeight = targetRect.height;
      final verticalPadding = targetHeight * _kDetectionCropPadding;

      // The server's bbox is relative to the cropped image, so we need to transform it back
      // to the original screen coordinate system by adding back the crop offsets

      final cropOffsetX = 0.0; // No horizontal offset (full width)
      final cropOffsetY = targetRect.top - verticalPadding; // Vertical offset

      // Transform bbox from cropped image coordinates to screen coordinates
      // Simply add back the crop offsets (no scaling needed since coordinates are in same space)
      final screenBbox = Rect.fromLTWH(
        croppedBbox.left + cropOffsetX, // Add horizontal crop offset (0)
        croppedBbox.top + cropOffsetY, // Add vertical crop offset
        croppedBbox.width, // Width unchanged
        croppedBbox.height, // Height unchanged
      );

      developer.log('Bbox transformation:');
      developer.log('  Server bbox (cropped image): $croppedBbox');
      developer.log('  Crop offset: X=$cropOffsetX, Y=$cropOffsetY');
      developer.log('  Transformed bbox (screen): $screenBbox');
      developer.log('  Target rect (screen): $targetRect');

      return screenBbox;
    } catch (e) {
      developer.log('Error transforming bbox coordinates: $e');
      return croppedBbox; // Return original if transformation fails
    }
  }

  /// Applies adaptive image optimization based on current network performance
  Future<Uint8List> _applyAdaptiveImageOptimization(
    Uint8List originalBytes,
  ) async {
    try {
      final codec = await ui.instantiateImageCodec(originalBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Apply scaling if needed for poor connections
      ui.Image processedImage = image;
      if (_currentImageScale < 1.0) {
        processedImage = await _resizeImage(image, _currentImageScale);
        developer.log(
          'Resized image by ${(_currentImageScale * 100).toStringAsFixed(0)}%',
        );
      }

      // Always use PNG format with adaptive quality and scaling
      final byteData = await processedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final optimizedBytes = byteData!.buffer.asUint8List();

      developer.log(
        'Using PNG format with ${(_currentImageQuality * 100).toStringAsFixed(0)}% quality, '
        '${(_currentImageScale * 100).toStringAsFixed(0)}% scale',
      );

      return optimizedBytes;
    } catch (e) {
      developer.log('Error in adaptive optimization: $e');
      // Fallback to original bytes if optimization fails
      return originalBytes;
    }
  }

  Future<ui.Image> _resizeImage(ui.Image image, double scale) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final newWidth = (image.width * scale).round();
    final newHeight = (image.height * scale).round();

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
      Paint(),
    );

    final picture = recorder.endRecording();
    return await picture.toImage(newWidth, newHeight);
  }

  void _startPerformanceMonitoring() {
    _performanceTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_disposed) return;

      _adjustPerformanceSettings();
    });
  }

  void _adjustPerformanceSettings() {
    final metrics = _performanceMetrics;

    if (metrics.isPerformancePoor || metrics.isNetworkSlow) {
      // Aggressive optimization for poor connections
      _reduceQualityForPoorConnection();

      developer.log(
        'Poor performance detected - Network: ${metrics.averageNetworkResponseTime.toStringAsFixed(0)}ms, '
        'Processing: ${metrics.averageProcessingTime.toStringAsFixed(0)}ms',
      );
    } else if (metrics.isPerformanceGood && metrics.isNetworkFast) {
      // Increase quality for good connections
      _increaseQualityForGoodConnection();

      developer.log(
        'Good performance detected - Network: ${metrics.averageNetworkResponseTime.toStringAsFixed(0)}ms, '
        'Processing: ${metrics.averageProcessingTime.toStringAsFixed(0)}ms',
      );
    }

    developer.log(
      'Current settings: interval=${_currentDetectionInterval.inMilliseconds}ms, '
      'quality=${(_currentImageQuality * 100).toStringAsFixed(0)}%, '
      'scale=${(_currentImageScale * 100).toStringAsFixed(0)}% (PNG format)',
    );
  }

  void _reduceQualityForPoorConnection() {
    bool settingsChanged = false;

    // Increase detection interval to reduce network load
    if (_currentDetectionInterval < _kMaxDetectionInterval) {
      _currentDetectionInterval = Duration(
        milliseconds: (_currentDetectionInterval.inMilliseconds * 1.3).round(),
      );
      _restartDetectionLoop();
      settingsChanged = true;
    }

    // Reduce image quality
    if (_currentImageQuality > _kMinImageQuality) {
      _currentImageQuality = (_currentImageQuality * 0.85).clamp(
        _kMinImageQuality,
        _kMaxImageQuality,
      );
      settingsChanged = true;
    }

    // Reduce image scale for very poor connections
    if (_performanceMetrics.averageNetworkResponseTime > 1500 &&
        _currentImageScale > _kMinImageScale) {
      _currentImageScale = (_currentImageScale * 0.9).clamp(
        _kMinImageScale,
        1.0,
      );
      settingsChanged = true;
    }

    // Note: Always using PNG format as requested

    if (settingsChanged) {
      developer.log('Reduced quality for poor connection');
    }
  }

  void _increaseQualityForGoodConnection() {
    bool settingsChanged = false;

    // Decrease detection interval for faster response
    if (_currentDetectionInterval > _kMinDetectionInterval) {
      _currentDetectionInterval = Duration(
        milliseconds: (_currentDetectionInterval.inMilliseconds * 0.9).round(),
      );
      _restartDetectionLoop();
      settingsChanged = true;
    }

    // Increase image quality
    if (_currentImageQuality < _kMaxImageQuality) {
      _currentImageQuality = (_currentImageQuality * 1.1).clamp(
        _kMinImageQuality,
        _kMaxImageQuality,
      );
      settingsChanged = true;
    }

    // Restore full image scale
    if (_currentImageScale < 1.0) {
      _currentImageScale = (_currentImageScale * 1.1).clamp(
        _kMinImageScale,
        1.0,
      );
      settingsChanged = true;
    }

    // Note: Always using PNG format as requested

    if (settingsChanged) {
      developer.log('Increased quality for good connection');
    }
  }

  void _restartDetectionLoop() {
    if (_disposed) return;
    _detectionTimer?.cancel();
    _startDetectionLoop();
  }

  void _handleFeedback(Rect? bbox, DetectionChecks checks) {
    if (_disposed) return;

    // Always update _lastChecks
    _lastChecks = checks;

    if (bbox == null) {
      _lastBbox = null;
      _resetSteadyState();
      developer.log('No bbox detected');
      _emitFeedback(
        DetectionFeedback(
          message: FeedbackMessage.default_.text,
          checks: const DetectionChecks(),
          connecting: false,
          connected: true,
          analyzing: false,
          bbox: null,
          feedbackState: FeedbackState.info,
        ),
      );
      return;
    }

    _lastBbox = bbox;

    // The bbox from _transformBboxFromCroppedToScreen is in screen coordinates
    final screenBbox = bbox;

    final feedback = _bboxFeedback(screenBbox);
    final isInside = feedback == FeedbackMessage.good.text;
    final passAllChecks = _areAllDetectionChecksPassed();

    if (isInside && passAllChecks) {
      if (_steadyStartTime == null) {
        // Start steady period
        _steadyStartTime = DateTime.now();
        developer.log(
          'Steady period started - periodic check will handle capture',
        );
      }
    } else {
      _resetSteadyState();
    }

    _emitFeedback(
      DetectionFeedback(
        message: feedback,
        checks: checks,
        connecting: _wsService.isConnecting,
        connected: _wsService.isConnected,
        analyzing: false,
        bbox: bbox,
        feedbackState: _getFeedbackStateFromMessage(feedback),
      ),
    );
  }

  void _startPeriodicCaptureCheck() {
    // Cancel any existing timer
    _periodicCaptureTimer?.cancel();

    _periodicCaptureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }

      // Independent capture check based on current state
      if (_steadyStartTime != null && !_captureTriggered) {
        final steadyDuration = DateTime.now().difference(_steadyStartTime!);

        if (steadyDuration >= _kSteadyDelay) {
          // Check current state without waiting for server
          if (_lastBbox != null) {
            final currentFeedback = _bboxFeedback(_lastBbox!);
            final isCurrentStateGood =
                currentFeedback == FeedbackMessage.good.text;
            final currentChecksGood = _areAllDetectionChecksPassed();

            if (isCurrentStateGood && currentChecksGood) {
              _captureTriggered = true;
              capture();
            }
          }
        }
      }
    });
  }

  void _resetSteadyState() {
    _steadyStartTime = null;
    _captureTriggered = false;
    developer.log('Steady state reset');
  }

  /// Determine feedback state based on message content
  FeedbackState _getFeedbackStateFromMessage(String message) {
    if (message == FeedbackMessage.good.text) {
      return FeedbackState.success;
    } else if (message == FeedbackMessage.default_.text) {
      return FeedbackState.info;
    } else if (message == FeedbackMessage.goodPositionBadQuality.text) {
      return FeedbackState.error; // Orange/red to indicate quality issue
    } else if (message == FeedbackMessage.processingError.text ||
        message == FeedbackMessage.connectionError.text) {
      return FeedbackState.error;
    } else {
      // Directional feedback (move left, right, up, down)
      return FeedbackState.error;
    }
  }

  void _emitFeedback(DetectionFeedback feedback) {
    if (_disposed) return;

    // Always emit feedback for debugging - no filtering
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 16), () {
      if (!_disposed) {
        _feedbackController.add(feedback);
      }
    });
  }

  String _bboxFeedbackOld(Rect bbox) {
    // Check if detection quality is good
    final qualityGood = _areAllDetectionChecksPassed();

    // Calculate bbox center
    final bboxCenter = bbox.center;
    final targetCenter = targetRect.center;

    // Calculate offsets
    final centerOffsetX = bboxCenter.dx - targetCenter.dx;
    final centerOffsetY = bboxCenter.dy - targetCenter.dy;

    // Calculate how much we need to move horizontally and vertically
    final horizontalMove = centerOffsetX.abs();
    final verticalMove = centerOffsetY.abs();

    // 1. Center alignment check (most important)
    final centered =
        horizontalMove <= _kPositionTolerance &&
        verticalMove <= _kPositionTolerance;

    // 2. IMPROVED: Overlap check instead of full containment
    // Check if there's significant overlap between bbox and target
    final overlapRect = bbox.intersect(targetRect);
    final overlapArea = overlapRect.width * overlapRect.height;
    final bboxArea = bbox.width * bbox.height;
    final targetArea = targetRect.width * targetRect.height;

    // Require at least 70% of bbox to be inside target, OR
    // at least 70% of target to be covered by bbox
    final overlapRatio = overlapArea / bboxArea;
    final coverageRatio = overlapArea / targetArea;
    final sufficientOverlap = overlapRatio >= 0.7 || coverageRatio >= 0.7;

    // 3. Size appropriateness check - be more lenient
    final sizeRatio = bbox.width / targetRect.width;
    final properSize =
        sizeRatio >= 0.6 && sizeRatio <= 1.4; // More lenient range

    // Combine all position requirements
    final positionGood = centered && sufficientOverlap && properSize;

    if (positionGood && qualityGood) {
      return FeedbackMessage.good.text;
    }

    if (positionGood && !qualityGood) {
      return FeedbackMessage.goodPositionBadQuality.text;
    }

    // Directional feedback - only suggest one direction at a time
    if (verticalMove > horizontalMove) {
      // Vertical movement needed
      if (centerOffsetY > _kPositionTolerance) {
        return FeedbackMessage.tooLow.text;
      } else if (centerOffsetY < -_kPositionTolerance) {
        return FeedbackMessage.tooHigh.text;
      }
    }

    if (horizontalMove > verticalMove) {
      // Horizontal movement needed
      if (centerOffsetX > _kPositionTolerance) {
        return FeedbackMessage.moveLeft.text;
      } else if (centerOffsetX < -_kPositionTolerance) {
        return FeedbackMessage.moveRight.text;
      }
    }

    // If we get here, the position is close but not perfect
    // Check the most significant deviation
    if (verticalMove >= horizontalMove) {
      if (centerOffsetY > 0) {
        return FeedbackMessage.tooLow.text;
      } else {
        return FeedbackMessage.tooHigh.text;
      }
    } else {
      if (centerOffsetX > 0) {
        return FeedbackMessage.moveLeft.text;
      } else {
        return FeedbackMessage.moveRight.text;
      }
    }
  }

  String _bboxFeedback(Rect bbox) {
    // Check if detection quality is good
    final qualityGood = _areAllDetectionChecksPassed();

    // Calculate bbox center
    final bboxCenter = bbox.center;
    final targetCenter = targetRect.center;

    // Calculate offsets
    final centerOffsetX = bboxCenter.dx - targetCenter.dx;
    final centerOffsetY = bboxCenter.dy - targetCenter.dy;

    // Calculate how much we need to move horizontally and vertically
    final horizontalMove = centerOffsetX.abs();
    final verticalMove = centerOffsetY.abs();

    // 2. Overlap check - more practical thresholds
    final overlapRect = bbox.intersect(targetRect);
    final overlapArea = overlapRect.width * overlapRect.height;
    final bboxArea = bbox.width * bbox.height;
    final targetArea = targetRect.width * targetRect.height;

    // More lenient overlap requirements
    final overlapRatio = overlapArea / bboxArea;
    final coverageRatio = overlapArea / targetArea;
    final goodOverlap = overlapRatio >= 0.5 || coverageRatio >= 0.5;

    // 3. Size check - very lenient
    final sizeRatio = bbox.width / targetRect.width;
    final reasonableSize = sizeRatio >= 0.4 && sizeRatio <= 2.0;

    // Position is good if we have reasonable overlap AND reasonable size
    // Don't require perfect centering - overlap is more important
    final positionGood = goodOverlap && reasonableSize;

    if (positionGood && qualityGood) {
      return FeedbackMessage.good.text;
    }

    if (positionGood && !qualityGood) {
      return FeedbackMessage.goodPositionBadQuality.text;
    }

    // Directional feedback - only suggest one direction at a time
    if (verticalMove > horizontalMove) {
      // Vertical movement needed
      if (centerOffsetY > _kPositionTolerance) {
        return FeedbackMessage.tooHigh.text; // bbox is below target, move up
      } else if (centerOffsetY < -_kPositionTolerance) {
        return FeedbackMessage.tooLow.text; // bbox is above target, move down
      }
    }

    if (horizontalMove > verticalMove) {
      // Horizontal movement needed
      if (centerOffsetX > _kPositionTolerance) {
        return FeedbackMessage
            .moveRight
            .text; // bbox is right of target, move right
      } else if (centerOffsetX < -_kPositionTolerance) {
        return FeedbackMessage
            .moveLeft
            .text; // bbox is left of target, move left
      }
    }

    // If we get here, the position is close but not perfect
    // Check the most significant deviation
    if (verticalMove >= horizontalMove) {
      if (centerOffsetY > 0) {
        return FeedbackMessage.tooHigh.text; // bbox is below target, move up
      } else {
        return FeedbackMessage.tooLow.text; // bbox is above target, move down
      }
    } else {
      if (centerOffsetX > 0) {
        return FeedbackMessage
            .moveRight
            .text; // bbox is right of target, move right
      } else {
        return FeedbackMessage
            .moveLeft
            .text; // bbox is left of target, move left
      }
    }
  }

  /// Check if all detection checks have passed
  bool _areAllDetectionChecksPassed() {
    // Check the most important quality indicators
    bool darknessOk =
        _lastChecks.darkness == DetectionCheckResult.pass ||
        _lastChecks.darkness == DetectionCheckResult.none;
    bool brightnessOk =
        _lastChecks.brightness == DetectionCheckResult.pass ||
        _lastChecks.brightness == DetectionCheckResult.none;
    bool blurOk =
        _lastChecks.blur == DetectionCheckResult.pass ||
        _lastChecks.blur == DetectionCheckResult.none;
    bool glareOk =
        _lastChecks.glare == DetectionCheckResult.pass ||
        _lastChecks.glare == DetectionCheckResult.none;

    return darknessOk && brightnessOk && blurOk && glareOk;
  }

  // Manual capture method - captures and crops image to target rectangle
  Future<void> capture() async {
    if (_disposed) return;

    try {
      // Ensure flash is off before taking picture
      if (cameraController.value.flashMode != FlashMode.off) {
        await cameraController.setFlashMode(FlashMode.off);
      }

      final XFile file = await cameraController.takePicture();
      final originalBytes = await file.readAsBytes();

      // Convert to PNG format
      final pngBytes = await ImageCropper.convertToPng(originalBytes);

      // Get actual image dimensions
      final codec = await ui.instantiateImageCodec(pngBytes);
      final frame = await codec.getNextFrame();
      final actualImage = frame.image;
      final imageWidth = actualImage.width.toDouble();
      final imageHeight = actualImage.height.toDouble();

      // Get camera preview size (note: in portrait mode, width/height are swapped)
      final previewSize = cameraController.value.previewSize!;
      final cameraWidth = previewSize.height
          .toDouble(); // Actual camera width in portrait
      final cameraHeight = previewSize.width
          .toDouble(); // Actual camera height in portrait

      // Calculate how the camera preview is displayed on screen
      final screenWidth = screenSize.width;
      final screenHeight = screenSize.height;

      // Camera preview is typically scaled to fill the screen height and center-cropped for width
      final previewScale = screenHeight / cameraHeight;
      final scaledPreviewWidth = cameraWidth * previewScale;

      // If scaled preview is wider than screen, it gets center-cropped
      final cropOffsetX = (scaledPreviewWidth - screenWidth) / 2;

      // Calculate the actual scaling from screen coordinates to image coordinates
      final scaleX = imageWidth / cameraWidth;
      final scaleY = imageHeight / cameraHeight;

      developer.log('Manual capture - Image: ${imageWidth}x${imageHeight}');
      developer.log('Manual capture - Camera: ${cameraWidth}x${cameraHeight}');
      developer.log('Manual capture - Screen: ${screenWidth}x${screenHeight}');
      developer.log('Manual capture - Preview scale: $previewScale');
      developer.log(
        'Manual capture - Scaled preview width: $scaledPreviewWidth',
      );
      developer.log('Manual capture - Crop offset X: $cropOffsetX');
      developer.log(
        'Manual capture - Image scale factors: scaleX=$scaleX, scaleY=$scaleY',
      );

      // Transform target rectangle from screen coordinates to camera coordinates
      final cameraTargetRect = Rect.fromLTWH(
        (targetRect.left + cropOffsetX) / previewScale,
        targetRect.top / previewScale,
        targetRect.width / previewScale,
        targetRect.height / previewScale,
      );

      // Then scale from camera coordinates to actual image coordinates
      final imageTargetRect = Rect.fromLTWH(
        cameraTargetRect.left * scaleX,
        cameraTargetRect.top * scaleY,
        cameraTargetRect.width * scaleX,
        cameraTargetRect.height * scaleY,
      );

      // Add padding to the target area for better cropping
      final paddedImageRect = Rect.fromLTRB(
        imageTargetRect.left - _kCropPadding,
        imageTargetRect.top - _kCropPadding,
        imageTargetRect.right + _kCropPadding,
        imageTargetRect.bottom + _kCropPadding,
      );

      // Clamp to image bounds to prevent cropping outside image
      final clampedRect = Rect.fromLTRB(
        paddedImageRect.left.clamp(0.0, imageWidth),
        paddedImageRect.top.clamp(0.0, imageHeight),
        paddedImageRect.right.clamp(0.0, imageWidth),
        paddedImageRect.bottom.clamp(0.0, imageHeight),
      );

      developer.log('Manual capture - Original target rect: $targetRect');
      developer.log('Manual capture - Camera target rect: $cameraTargetRect');
      developer.log('Manual capture - Image target rect: $imageTargetRect');
      developer.log(
        'Manual capture - Padded image rect (10px): $paddedImageRect',
      );
      developer.log('Manual capture - Clamped rect: $clampedRect');

      // Convert to bbox format for cropping
      final targetBboxList = [
        clampedRect.left,
        clampedRect.top,
        clampedRect.right,
        clampedRect.bottom,
      ];

      final croppedBytes = await ImageCropper.cropImage(
        pngBytes,
        targetBboxList,
      );
      final croppedPath = await ImageCropper.saveCroppedImage(
        croppedBytes,
        file.path.replaceAll('.jpg', '.png'),
      );

      final croppedFile = XFile(croppedPath);
      _captureController.add(croppedFile);

      developer.log(
        'Manual capture completed with proper coordinate transformation',
      );
    } catch (e) {
      developer.log('Error during manual capture: $e');
    }
  }

  void disconnect() {
    _detectionTimer?.cancel();
    _steadyTimer?.cancel();
    _debounceTimer?.cancel();
    _stopImageStream(); // Stop image stream

    // Only disconnect if we created the WebSocket service ourselves
    if (!_wsServiceProvided) {
      _wsService.disconnect();
    }
  }

  void dispose() {
    _disposed = true;
    _performanceTimer?.cancel();
    _wsStatusSub?.cancel();
    _wsMessageSub?.cancel();
    _wsErrorSub?.cancel();
    _periodicCaptureTimer?.cancel();
    _stopImageStream(); // Ensure stream is stopped
    disconnect();

    // Only dispose WebSocket service if we created it ourselves
    if (!_wsServiceProvided) {
      _wsService.dispose();
    }

    _feedbackController.close();
    _captureController.close();
  }
}
