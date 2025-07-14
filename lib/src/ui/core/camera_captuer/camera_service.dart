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

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../../../config/app_config.dart';
import '../../../models/kyc_api_models.dart';

/// Feedback state for UI overlays
class DetectionFeedback {
  final String message;
  final DetectionChecks checks;
  final bool analyzing;
  final bool connecting;
  final bool connected;
  final bool autoCaptured;
  final Rect? bbox;

  DetectionFeedback({
    required this.message,
    required this.checks,
    this.analyzing = false,
    this.connecting = false,
    this.connected = false,
    this.autoCaptured = false,
    this.bbox,
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
        other.bbox == bbox;
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

  // Adaptive configuration
  Duration _currentDetectionInterval = const Duration(milliseconds: 100);
  final Duration _minDetectionInterval = const Duration(milliseconds: 50);
  final Duration _maxDetectionInterval = const Duration(milliseconds: 200);
  double _currentImageQuality = 0.8;
  final double _minImageQuality = 0.5;
  final double _maxImageQuality = 1.0;

  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  Timer? _detectionTimer;
  Timer? _steadyTimer;
  Timer? _performanceTimer;
  Timer? _debounceTimer;

  bool _pendingRequest = false;
  bool _connected = false;
  bool _connecting = false;
  bool _disposed = false;
  int _reconnectAttempts = 0;
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
    this.steadyDelay = const Duration(milliseconds: 4000),
  }) {
    _startPerformanceMonitoring();
  }

  Stream<DetectionFeedback> get feedbackStream => _feedbackController.stream;
  Stream<XFile> get autoCaptureStream => _autoCaptureController.stream;

  void connect() {
    if (_disposed) return;

    _connecting = true;
    _emitFeedback(
      DetectionFeedback(
        message: 'Connecting…',
        checks: _lastChecks,
        connecting: true,
        connected: false,
        analyzing: false,
        autoCaptured: false,
      ),
    );
    _openSocket();
  }

  void _openSocket() {
    if (_disposed) return;

    developer.log(
      'Attempting to connect to WebSocket: ${AppConfig.mlSocketUrl}',
    );

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(AppConfig.mlSocketUrl),
        protocols: ['binary'], // Optimize for binary data
      );

      _wsSub = _channel!.stream.listen(
        _onWsMessage,
        onDone: _onWsDone,
        onError: _onWsError,
        cancelOnError: false,
      );

      _connected = false;
      _connecting = true;
      _pendingRequest = false;
      _startDetectionLoop();
    } catch (e) {
      developer.log('Error creating WebSocket connection: $e');
      _onWsError(e);
    }
  }

  void _onWsMessage(dynamic message) {
    if (_disposed) return;

    final processingStart = DateTime.now();

    // First message received means we're connected
    if (_connecting) {
      _connecting = false;
      _connected = true;
      _reconnectAttempts = 0;
      developer.log('WebSocket connection established');
    }

    _pendingRequest = false;

    try {
      developer.log(message);

      // Parse the JSON message (handle double-encoded JSON)
      dynamic jsonData;
      if (message is String) {
        jsonData = jsonDecode(message);
      } else if (message is List<int> || message is Uint8List) {
        jsonData = jsonDecode(utf8.decode(message));
      } else {
        developer.log('Unexpected message type: ${message.runtimeType}');
        return;
      }

      // Handle double-encoded JSON (JSON string within JSON)
      if (jsonData is String) {
        try {
          jsonData = jsonDecode(jsonData);
        } catch (e) {
          developer.log('Error parsing double-encoded JSON: $e');
          return;
        }
      }

      // Ensure we have a valid Map
      if (jsonData is! Map<String, dynamic>) {
        developer.log(
          'Invalid JSON structure: expected Map<String, dynamic>, got ${jsonData.runtimeType}',
        );
        developer.log('Raw data: $jsonData');
        return;
      }

      final data = jsonData as Map<String, dynamic>;

      // Handle error responses from the server
      if (data['success'] == false) {
        developer.log('Server returned error response: $data');
        _emitFeedback(
          DetectionFeedback(
            message: 'Fit ID card in the box',
            checks: _lastChecks,
            connecting: false,
            connected: true,
            analyzing: false,
            autoCaptured: false,
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
          bbox = Rect.fromLTWH(
            (bboxList[0] as num).toDouble(),
            (bboxList[1] as num).toDouble(),
            (bboxList[2] as num).toDouble(),
            (bboxList[3] as num).toDouble(),
          );
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
      developer.log('Message content: $message');

      // Emit error feedback to user
      _emitFeedback(
        DetectionFeedback(
          message: 'Processing error occurred',
          checks: _lastChecks,
          connecting: false,
          connected: true,
          analyzing: false,
          autoCaptured: false,
        ),
      );
    }
  }

  void _onWsDone() {
    if (_disposed) return;

    _connected = false;
    _connecting = false;
    _pendingRequest = false;
    _detectionTimer?.cancel();

    _emitFeedback(
      DetectionFeedback(
        message: 'Disconnected. Reconnecting…',
        checks: _lastChecks,
        connecting: true,
        connected: false,
        analyzing: false,
        autoCaptured: false,
      ),
    );
    _reconnectWithBackoff();
  }

  void _onWsError(error) {
    if (_disposed) return;

    _connected = false;
    _connecting = false;
    _pendingRequest = false;
    _detectionTimer?.cancel();

    developer.log('WebSocket error occurred: $error');
    _emitFeedback(
      DetectionFeedback(
        message: 'Connection error. Reconnecting…',
        checks: _lastChecks,
        connecting: true,
        connected: false,
        analyzing: false,
        autoCaptured: false,
      ),
    );
    _reconnectWithBackoff();
  }

  void _reconnectWithBackoff() {
    if (_disposed) return;

    _reconnectAttempts++;
    final delay = Duration(
      milliseconds: (500 * (1 << (_reconnectAttempts.clamp(0, 5)))).clamp(
        500,
        30000,
      ),
    );

    Timer(delay, () {
      if (!_disposed && !_connected && !_connecting) {
        _openSocket();
      }
    });
  }

  void _startDetectionLoop() {
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(_currentDetectionInterval, (_) async {
      if (_disposed || (!_connected && !_connecting) || _pendingRequest) return;

      // Frame rate limiting
      final now = DateTime.now();
      if (_lastFrameTime != null &&
          now.difference(_lastFrameTime!).inMilliseconds <
              _currentDetectionInterval.inMilliseconds) {
        return;
      }
      _lastFrameTime = now;

      _pendingRequest = true;

      // Only show "Analyzing..." if we're actually connected
      if (_connected) {
        _emitFeedback(
          DetectionFeedback(
            message: 'Fit ID card in the box',
            checks: _lastChecks,
            connecting: false,
            connected: true,
            analyzing: true,
            autoCaptured: false,
            bbox: _lastBbox,
          ),
        );
      }

      try {
        final bytes = await _captureOptimizedImage();
        if (bytes != null && !_disposed) {
          _channel?.sink.add(bytes);
        }
      } catch (e) {
        _pendingRequest = false;
        developer.log('Error capturing image: $e');
      }
    });
  }

  Future<Uint8List?> _captureOptimizedImage() async {
    try {
      final XFile file = await cameraController.takePicture();
      final bytes = await file.readAsBytes();

      // If performance is poor, reduce image quality
      if (_performanceMetrics.isPerformancePoor &&
          _currentImageQuality > _minImageQuality) {
        return await _compressImage(bytes);
      }

      return bytes;
    } catch (e) {
      developer.log('Error in _captureOptimizedImage: $e');
      return null;
    }
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Reduce image size for better performance
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

    if (bbox == null) {
      _insideSince = null;
      _steadyTimer?.cancel();
      _emitFeedback(
        DetectionFeedback(
          message: 'Fit ID card in the box',
          checks: checks,
          connecting: false,
          connected: true,
          analyzing: false,
          autoCaptured: false,
          bbox: null,
        ),
      );
      return;
    }

    final feedback = _bboxFeedback(bbox);
    final isInRightSpot = feedback == 'Right spot! Hold steady';

    if (isInRightSpot) {
      if (_insideSince == null) {
        _insideSince = DateTime.now();
        _steadyTimer?.cancel();
        _steadyTimer = Timer(steadyDelay, _autoCapture);
      }
    } else {
      _insideSince = null;
      _steadyTimer?.cancel();
    }

    _emitFeedback(
      DetectionFeedback(
        message: feedback,
        checks: checks,
        connecting: false,
        connected: true,
        analyzing: false,
        autoCaptured: false,
        bbox: bbox,
      ),
    );
  }

  void _emitFeedback(DetectionFeedback feedback) {
    if (_disposed) return;

    // Debounce feedback updates to prevent UI flickering
    if (_lastFeedback == feedback) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 16), () {
      if (!_disposed) {
        _lastFeedback = feedback;
        _feedbackController.add(feedback);
      }
    });
  }

  String _bboxFeedback(Rect bbox) {
    // Use contains check with some tolerance for better UX
    const tolerance = 20.0;
    final adjustedTargetRect = Rect.fromLTRB(
      targetRect.left - tolerance,
      targetRect.top - tolerance,
      targetRect.right + tolerance,
      targetRect.bottom + tolerance,
    );

    if (adjustedTargetRect.contains(bbox.topLeft) &&
        adjustedTargetRect.contains(bbox.bottomRight)) {
      return 'Right spot! Hold steady';
    }

    if (bbox.top > targetRect.bottom) return 'Too low — raise it a bit.';
    if (bbox.bottom < targetRect.top) return 'Too high — lower it a bit.';
    if (bbox.left > targetRect.right) return 'Move left slightly.';
    if (bbox.right < targetRect.left) return 'Move right slightly.';
    return 'Fit ID card in the box';
  }

  void _autoCapture() async {
    if (_disposed || !_connected) return;

    try {
      final XFile file = await cameraController.takePicture();
      _autoCaptureController.add(file);
      _emitFeedback(
        DetectionFeedback(
          message: 'Captured!',
          checks: _lastChecks,
          connecting: false,
          connected: true,
          analyzing: false,
          autoCaptured: true,
          bbox: _lastBbox,
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
    _wsSub?.cancel();
    _channel?.sink.close(ws_status.goingAway);
    _connected = false;
    _connecting = false;
    _pendingRequest = false;
  }

  void dispose() {
    _disposed = true;
    _performanceTimer?.cancel();
    disconnect();
    _feedbackController.close();
    _autoCaptureController.close();
    _imageBufferPool.clear();
  }
}
