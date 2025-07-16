/// WebSocketService
///
/// Handles WebSocket connection management for the KYC ML backend.
/// Provides robust connection handling with automatic reconnection,
/// status tracking, and message streaming capabilities.
///
/// This service manages the WebSocket lifecycle independently from the
/// camera service, allowing for better separation of concerns and
/// improved testability and maintainability.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../config/app_config.dart';

/// WebSocket connection status
enum WebSocketStatus { disconnected, connecting, connected, error }

/// WebSocket service for handling ML backend communication
class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;

  bool _disposed = false;
  int _reconnectAttempts = 0;
  WebSocketStatus _status = WebSocketStatus.disconnected;

  // Stream controllers
  final _statusController = StreamController<WebSocketStatus>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Stream of connection status changes
  Stream<WebSocketStatus> get statusStream => _statusController.stream;

  /// Stream of parsed messages from the WebSocket
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Stream of error messages
  Stream<String> get errorStream => _errorController.stream;

  /// Current connection status
  WebSocketStatus get status => _status;

  /// Whether the service is currently connected
  bool get isConnected => _status == WebSocketStatus.connected;

  /// Whether the service is currently connecting
  bool get isConnecting => _status == WebSocketStatus.connecting;

  /// Connect to the WebSocket server
  void connect() {
    if (_disposed || _status == WebSocketStatus.connecting) return;

    _updateStatus(WebSocketStatus.connecting);
    _openSocket();
  }

  /// Disconnect from the WebSocket server
  void disconnect() {
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _channel?.sink.close(ws_status.goingAway);
    _updateStatus(WebSocketStatus.disconnected);
  }

  /// Send data through the WebSocket
  void send(Uint8List data) {
    if (_status != WebSocketStatus.connected || _channel == null) {
      developer.log('WebSocketService: Cannot send data - not connected');
      return;
    }

    try {
      _channel!.sink.add(data);
      developer.log('WebSocketService: Sent ${data.length} bytes');
    } catch (e) {
      developer.log('WebSocketService: Error sending data: $e');
      _handleError('Failed to send data: $e');
    }
  }

  /// Open the WebSocket connection
  void _openSocket() {
    if (_disposed) return;

    developer.log('WebSocketService: Connecting to ${AppConfig.mlSocketUrl}');

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(AppConfig.mlSocketUrl),
        protocols: ['binary'], // Optimize for binary data
      );

      _wsSub = _channel!.stream.listen(
        _onMessage,
        onDone: _onDone,
        onError: _onError,
        cancelOnError: false,
      );

      // Connection established
      _updateStatus(WebSocketStatus.connected);
      _reconnectAttempts = 0;

      developer.log('WebSocketService: Connection established');
    } catch (e) {
      developer.log('WebSocketService: Connection failed: $e');
      _handleError('Connection failed: $e');
      _scheduleReconnect();
    }
  }

  /// Handle incoming WebSocket messages
  void _onMessage(dynamic message) {
    if (_disposed) return;

    try {
      developer.log('WebSocketService: Received message');

      // Parse the JSON message (handle double-encoded JSON)
      dynamic jsonData;
      if (message is String) {
        jsonData = jsonDecode(message);
      } else if (message is List<int> || message is Uint8List) {
        jsonData = jsonDecode(utf8.decode(message));
      } else {
        developer.log(
          'WebSocketService: Unexpected message type: ${message.runtimeType}',
        );
        return;
      }

      // Handle double-encoded JSON (JSON string within JSON)
      if (jsonData is String) {
        try {
          jsonData = jsonDecode(jsonData);
        } catch (e) {
          developer.log(
            'WebSocketService: Error parsing double-encoded JSON: $e',
          );
          return;
        }
      }

      // Ensure we have a valid Map
      if (jsonData is! Map<String, dynamic>) {
        developer.log(
          'WebSocketService: Invalid JSON structure: expected Map<String, dynamic>, got ${jsonData.runtimeType}',
        );
        return;
      }

      // Emit the parsed message
      _messageController.add(jsonData);
    } catch (e, stackTrace) {
      developer.log('WebSocketService: Error processing message: $e');
      developer.log('WebSocketService: Stack trace: $stackTrace');
      _handleError('Message processing error: $e');
    }
  }

  /// Handle WebSocket connection close
  void _onDone() {
    if (_disposed) return;

    developer.log('WebSocketService: Connection closed');
    _updateStatus(WebSocketStatus.disconnected);
    _scheduleReconnect();
  }

  /// Handle WebSocket errors
  void _onError(error) {
    if (_disposed) return;

    developer.log('WebSocketService: Connection error: $error');
    _handleError('Connection error: $error');
    _updateStatus(WebSocketStatus.error);
    _scheduleReconnect();
  }

  /// Update connection status and notify listeners
  void _updateStatus(WebSocketStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      if (!_disposed) {
        _statusController.add(_status);
      }
    }
  }

  /// Handle errors and emit to error stream
  void _handleError(String error) {
    if (!_disposed) {
      _errorController.add(error);
    }
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    if (_disposed) return;

    _reconnectAttempts++;
    final delay = Duration(
      milliseconds: (500 * (1 << (_reconnectAttempts.clamp(0, 5)))).clamp(
        500,
        30000, // Max 30 seconds
      ),
    );

    developer.log(
      'WebSocketService: Scheduling reconnect in ${delay.inMilliseconds}ms (attempt $_reconnectAttempts)',
    );

    _reconnectTimer = Timer(delay, () {
      if (!_disposed && _status != WebSocketStatus.connected) {
        _updateStatus(WebSocketStatus.connecting);
        _openSocket();
      }
    });
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _reconnectTimer?.cancel();
    disconnect();

    _statusController.close();
    _messageController.close();
    _errorController.close();

    developer.log('WebSocketService: Disposed');
  }
}
