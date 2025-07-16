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
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../models/kyc_api_models.dart';
import '../../../utils/image_cropper.dart';
import '../../../services/websocket_service.dart';

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
  final bool autoCaptured;
  final Rect? bbox;
  final FeedbackState feedbackState;

  DetectionFeedback({
    required this.message,
    required this.checks,
    this.analyzing = false,
    this.connecting = false,
    this.connected = false,
    this.autoCaptured = false,
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
        other.autoCaptured == autoCaptured &&
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
    autoCaptured,
    bbox,
    feedbackState,
  );
}

/// Performance metrics for adaptive quality
class _PerformanceMetrics {
  final List<int> _processingTimes = [];
  final int _maxSamples = 10;

  void addProcessingTime(int milliseconds) {
    _processingTimes.add(milliseconds);
    if (_processingTimes.length > _maxSamples) {
      _processingTimes.removeAt(0);
    }
  }

  double get averageProcessingTime {
    if (_processingTimes.isEmpty) return 0;
    return _processingTimes.reduce((a, b) => a + b) / _processingTimes.length;
  }

  bool get isPerformancePoor => averageProcessingTime > 200;
  bool get isPerformanceGood => averageProcessingTime < 100;
}

class CameraService {
  final CameraController cameraController;
  final Rect targetRect;
  final Duration steadyDelay;
  final void Function(DetectionChecks) onChecks;
  final Size screenSize; // Add screen size for coordinate transformation

  // Adaptive configuration
  Duration _currentDetectionInterval = const Duration(milliseconds: 100);
  final Duration _minDetectionInterval = const Duration(milliseconds: 50);
  final Duration _maxDetectionInterval = const Duration(milliseconds: 200);
  double _currentImageQuality = 0.8;
  final double _minImageQuality = 0.5;
  final double _maxImageQuality = 1.0;

  // WebSocket service
  late final WebSocketService _wsService;
  StreamSubscription? _wsStatusSub;
  StreamSubscription? _wsMessageSub;
  StreamSubscription? _wsErrorSub;

  Timer? _detectionTimer;
  Timer? _steadyTimer;
  Timer? _performanceTimer;
  Timer? _debounceTimer;

  bool _pendingRequest = false;
  bool _disposed = false;
  DateTime? _insideSince;
  DateTime? _lastFrameTime;

  DetectionChecks _lastChecks = const DetectionChecks();
  DetectionFeedback? _lastFeedback;
  Rect? _lastBbox;

  final _performanceMetrics = _PerformanceMetrics();
  final _feedbackController = StreamController<DetectionFeedback>.broadcast();
  final _autoCaptureController = StreamController<XFile>.broadcast();

  // Memory management
  final Queue<Uint8List> _imageBufferPool = Queue<Uint8List>();
  static const int _maxPoolSize = 3;

  CameraService({
    required this.cameraController,
    required this.targetRect,
    required this.onChecks,
    required this.screenSize, // Add required screen size parameter
    this.steadyDelay = const Duration(milliseconds: 3000), // Changed to 2s
  }) {
    _wsService = WebSocketService();
    _initWebSocketListeners();
    _startPerformanceMonitoring();
  }

  Stream<DetectionFeedback> get feedbackStream => _feedbackController.stream;
  Stream<XFile> get autoCaptureStream => _autoCaptureController.stream;

  /// Initialize WebSocket event listeners
  void _initWebSocketListeners() {
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
              autoCaptured: false,
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
              autoCaptured: false,
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
              autoCaptured: false,
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
              autoCaptured: false,
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

  void connect() {
    if (_disposed) return;
    _wsService.connect();
  }

  void _onWsMessage(Map<String, dynamic> data) {
    if (_disposed) return;

    final processingStart = DateTime.now();
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
            autoCaptured: false,
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

          bbox = Rect.fromLTRB(left, top, right, bottom);

          developer.log(
            'Parsed bbox LTRB: left=$left, top=$top, right=$right, bottom=$bottom',
          );
          developer.log('Converted to Rect: $bbox');
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
          autoCaptured: false,
          feedbackState: FeedbackState.error,
        ),
      );
    }
  }

  void _startDetectionLoop() {
    _detectionTimer?.cancel();
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

      try {
        final arrayBuffer = await _captureOptimizedImageAsArrayBuffer();
        if (arrayBuffer != null && !_disposed) {
          developer.log('Sending image data: ${arrayBuffer.length} bytes');
          _wsService.send(arrayBuffer);
        }
      } catch (e) {
        _pendingRequest = false;
        developer.log('Error capturing image: $e');
      }
    });
  }

  /// Converts image to ArrayBuffer format to match web implementation
  Future<Uint8List?> _captureOptimizedImageAsArrayBuffer() async {
    try {
      // Ensure flash is off and camera is muted before taking picture
      if (cameraController.value.flashMode != FlashMode.off) {
        await cameraController.setFlashMode(FlashMode.off);
      }

      final XFile file = await cameraController.takePicture();
      final bytes = await file.readAsBytes();

      // Convert JPEG to PNG for consistent format
      final pngBytes = await ImageCropper.convertToPng(bytes);

      // Convert to base64 data URL format (similar to web implementation)
      String base64Image = base64Encode(pngBytes);
      String dataURL = 'data:image/png;base64,$base64Image';

      developer.log('Created PNG data URL with length: ${dataURL.length}');

      // Convert data URL to ArrayBuffer (matching web implementation)
      return _dataURLToArrayBuffer(dataURL);
    } catch (e) {
      developer.log('Error in _captureOptimizedImageAsArrayBuffer: $e');
      return null;
    }
  }

  /// Converts data URL to ArrayBuffer (matches web implementation)
  Uint8List _dataURLToArrayBuffer(String dataURL) {
    // Split the data URL at the comma
    final parts = dataURL.split(',');
    if (parts.length != 2) {
      throw Exception('Invalid data URL.');
    }

    // The second part is the Base64 encoded string
    final base64String = parts[1];

    // Decode the Base64 string to bytes
    final bytes = base64Decode(base64String);

    developer.log('Converted to ArrayBuffer: ${bytes.length} bytes');

    return bytes;
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Reduce image size for better performance and ensure PNG format
      final resizedImage = await _resizeImage(image, 0.8);
      final byteData = await resizedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      return byteData!.buffer.asUint8List();
    } catch (e) {
      developer.log('Error compressing image: $e');
      return bytes; // Return original if compression fails
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
    if (_performanceMetrics.isPerformancePoor) {
      // Reduce performance demands
      if (_currentDetectionInterval < _maxDetectionInterval) {
        _currentDetectionInterval = Duration(
          milliseconds: (_currentDetectionInterval.inMilliseconds * 1.2)
              .round(),
        );
        _restartDetectionLoop();
      }

      if (_currentImageQuality > _minImageQuality) {
        _currentImageQuality = (_currentImageQuality * 0.9).clamp(
          _minImageQuality,
          _maxImageQuality,
        );
      }

      developer.log(
        'Performance poor, reducing quality: interval=${_currentDetectionInterval.inMilliseconds}ms, quality=$_currentImageQuality',
      );
    } else if (_performanceMetrics.isPerformanceGood) {
      // Increase performance if possible
      if (_currentDetectionInterval > _minDetectionInterval) {
        _currentDetectionInterval = Duration(
          milliseconds: (_currentDetectionInterval.inMilliseconds * 0.9)
              .round(),
        );
        _restartDetectionLoop();
      }

      if (_currentImageQuality < _maxImageQuality) {
        _currentImageQuality = (_currentImageQuality * 1.1).clamp(
          _minImageQuality,
          _maxImageQuality,
        );
      }
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
          autoCaptured: false,
          bbox: null,
          feedbackState: FeedbackState.info,
        ),
      );
      return;
    }

    _lastBbox = bbox; // Always update last bbox if not null

    // Transform bbox from image coordinates to screen coordinates for proper comparison
    final screenBbox = _transformBboxToScreenCoordinates(bbox);

    developer.log('Original bbox (image coords): $bbox');
    developer.log('Transformed bbox (screen coords): $screenBbox');
    developer.log('Target rect (screen coords): $targetRect');

    final feedback = _bboxFeedback(screenBbox);
    final isInside = feedback == FeedbackMessage.good.text;
    final passAllChecks = _areAllDetectionChecksPassed();

    developer.log('Feedback message: $feedback');
    developer.log('Is inside: $isInside, Pass all checks: $passAllChecks');

    // Match web logic: if (isInside && bbox && passAllChecks)
    if (isInside && passAllChecks) {
      // Only start timer if one isn't already running
      if (_steadyTimer == null || !_steadyTimer!.isActive) return;
      _steadyTimer = Timer(steadyDelay, () {
        developer.log('Auto-capture timer completed - triggering capture');
        _autoCapture();
      });
      developer.log(
        'Started timer - waiting ${steadyDelay.inMilliseconds}ms for auto-capture',
      );
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
        autoCaptured: false,
        bbox: bbox,
        feedbackState: _getFeedbackStateFromMessage(feedback),
      ),
    );
  }

  /// Reset steady state - matches web resetSteadyState()
  void _resetSteadyState() {
    _steadyTimer?.cancel();
    _steadyTimer = null;
    _insideSince = null;
    developer.log('Reset steady state');
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

  /// Transform bbox coordinates from image space to screen space
  Rect _transformBboxToScreenCoordinates(Rect imageBbox) {
    try {
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

      // Determine if bbox coordinates are normalized (0-1) or absolute pixels
      Rect normalizedBbox;
      if (imageBbox.left <= 1.0 &&
          imageBbox.top <= 1.0 &&
          imageBbox.right <= 1.0 &&
          imageBbox.bottom <= 1.0) {
        // Coordinates are normalized (0-1), convert to camera pixel coordinates
        normalizedBbox = Rect.fromLTWH(
          imageBbox.left * cameraWidth,
          imageBbox.top * cameraHeight,
          (imageBbox.right - imageBbox.left) * cameraWidth,
          (imageBbox.bottom - imageBbox.top) * cameraHeight,
        );
        developer.log(
          'Detected normalized coordinates, converted to: $normalizedBbox',
        );
      } else {
        // Coordinates are already in pixel space (camera coordinates)
        normalizedBbox = imageBbox;
        developer.log('Using absolute pixel coordinates: $normalizedBbox');
      }

      // Transform: camera coordinates → screen coordinates

      // Step 1: Scale from camera coordinates to screen preview coordinates
      final previewRect = Rect.fromLTWH(
        normalizedBbox.left * previewScale,
        normalizedBbox.top * previewScale,
        normalizedBbox.width * previewScale,
        normalizedBbox.height * previewScale,
      );

      // Step 2: Adjust for center-crop offset to get final screen coordinates
      final screenRect = Rect.fromLTWH(
        previewRect.left - cropOffsetX,
        previewRect.top,
        previewRect.width,
        previewRect.height,
      );

      developer.log('Camera dimensions: ${cameraWidth}x${cameraHeight}');
      developer.log('Screen dimensions: ${screenWidth}x${screenHeight}');
      developer.log('Preview scale: $previewScale');
      developer.log('Scaled preview width: $scaledPreviewWidth');
      developer.log('Crop offset X: $cropOffsetX');
      developer.log('Preview rect: $previewRect');
      developer.log('Final screen rect: $screenRect');

      return screenRect;
    } catch (e) {
      developer.log('Error transforming bbox coordinates: $e');
      // Return original bbox if transformation fails
      return imageBbox;
    }
  }

  void _emitFeedback(DetectionFeedback feedback) {
    if (_disposed) return;

    // Always emit feedback for debugging - no filtering
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 16), () {
      if (!_disposed) {
        _lastFeedback = feedback;
        _feedbackController.add(feedback);
      }
    });
  }

  String _bboxFeedback(Rect bbox) {
    // Check if bbox is reasonably positioned within target area with forgiveness
    const forgiveness =
        30; // 30px forgiveness - bbox can extend outside target area

    // Calculate how much the bbox extends outside the target area
    final overlapLeft = bbox.left < targetRect.left
        ? targetRect.left - bbox.left
        : 0.0;
    final overlapTop = bbox.top < targetRect.top
        ? targetRect.top - bbox.top
        : 0.0;
    final overlapRight = bbox.right > targetRect.right
        ? bbox.right - targetRect.right
        : 0.0;
    final overlapBottom = bbox.bottom > targetRect.bottom
        ? bbox.bottom - targetRect.bottom
        : 0.0;

    final maxOverlap = [
      overlapLeft,
      overlapTop,
      overlapRight,
      overlapBottom,
    ].reduce((a, b) => a > b ? a : b);

    // Check if bbox is reasonably positioned (within forgiveness)
    bool isInGoodPosition = maxOverlap <= forgiveness;

    // Check if all detection checks are PASS
    bool allChecksPassed = _areAllDetectionChecksPassed();

    if (isInGoodPosition && allChecksPassed) {
      return FeedbackMessage.good.text;
    }

    // If position is good but checks failed, give specific quality feedback
    if (isInGoodPosition && !allChecksPassed) {
      return FeedbackMessage.goodPositionBadQuality.text;
    }

    // Provide specific directional feedback based on where the bbox is relative to target
    String result;

    // Check vertical position first (priority)
    if (bbox.bottom < targetRect.top) {
      // Bbox is above target area
      result = FeedbackMessage.tooHigh.text;
    } else if (bbox.top > targetRect.bottom) {
      // Bbox is below target area
      result = FeedbackMessage.tooLow.text;
    }
    // Check horizontal position
    else if (bbox.right < targetRect.left) {
      // Bbox is to the left of target area
      result = FeedbackMessage.moveRight.text;
    } else if (bbox.left > targetRect.right) {
      // Bbox is to the right of target area
      result = FeedbackMessage.moveLeft.text;
    }
    // Partial overlap cases - give most relevant direction
    else if (bbox.left < targetRect.left) {
      // Bbox extends too far left
      result = FeedbackMessage.moveRight.text;
    } else if (bbox.right > targetRect.right) {
      // Bbox extends too far right
      result = FeedbackMessage.moveLeft.text;
    } else if (bbox.top < targetRect.top) {
      // Bbox extends too far up
      result = FeedbackMessage.tooLow.text;
    } else if (bbox.bottom > targetRect.bottom) {
      // Bbox extends too far down
      result = FeedbackMessage.tooHigh.text;
    } else {
      // Fallback case
      result = FeedbackMessage.default_.text;
    }

    return result;
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

  void _autoCapture() async {
    if (_disposed) return;

    try {
      // Ensure flash is off and camera is muted before taking picture
      if (cameraController.value.flashMode != FlashMode.off) {
        await cameraController.setFlashMode(FlashMode.off);
      }

      final XFile file = await cameraController.takePicture();
      final originalBytes = await file.readAsBytes();

      // Convert to PNG format
      final pngBytes = await ImageCropper.convertToPng(originalBytes);

      XFile resultFile = file;

      // If bbox is available, crop the image with 10px padding
      if (_lastBbox != null) {
        // Add 10px padding to all sides of the bbox
        const padding = 10.0;
        final paddedBbox = Rect.fromLTRB(
          _lastBbox!.left - padding, // Left: -10px
          _lastBbox!.top - padding, // Top: -10px
          _lastBbox!.right + padding, // Right: +10px
          _lastBbox!.bottom + padding, // Bottom: +10px
        );

        developer.log('Original bbox: $_lastBbox');
        developer.log('Padded bbox (10px): $paddedBbox');

        // Uses the padded bbox for cropping
        final bboxList = [
          paddedBbox.left,
          paddedBbox.top,
          paddedBbox.right,
          paddedBbox.bottom,
        ];
        final croppedBytes = await ImageCropper.cropImage(pngBytes, bboxList);
        final croppedPath = await ImageCropper.saveCroppedImage(
          croppedBytes,
          file.path.replaceAll('.jpg', '.png'),
        );
        resultFile = XFile(croppedPath);
      } else {
        // Save PNG version even without cropping
        final pngPath = await ImageCropper.saveCroppedImage(
          pngBytes,
          file.path.replaceAll('.jpg', '.png'),
        );
        resultFile = XFile(pngPath);
      }

      _autoCaptureController.add(resultFile);

      _emitFeedback(
        DetectionFeedback(
          message: FeedbackMessage.captured.text,
          checks: _lastChecks,
          connecting: false,
          connected: true,
          analyzing: false,
          autoCaptured: true,
          bbox: _lastBbox,
          feedbackState: FeedbackState.success,
        ),
      );
    } catch (e) {
      developer.log('Error during auto-capture: $e');
    }
  }

  void disconnect() {
    _detectionTimer?.cancel();
    _steadyTimer?.cancel();
    _debounceTimer?.cancel();
    _wsService.disconnect();
  }

  void dispose() {
    _disposed = true;
    _performanceTimer?.cancel();
    _wsStatusSub?.cancel();
    _wsMessageSub?.cancel();
    _wsErrorSub?.cancel();
    disconnect();
    _wsService.dispose();
    _feedbackController.close();
    _autoCaptureController.close();
    _imageBufferPool.clear();
  }
}
