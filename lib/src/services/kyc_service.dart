import 'dart:convert';
import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../models/kyc_config.dart';
import '../models/kyc_result.dart';
import '../models/kyc_api_models.dart';
import '../config/app_config.dart';
import 'kyc_state_provider.dart';
import 'error_handler_service.dart';

class KYCService {
  static const String _baseUrl = AppConfig.kycApiUrl;
  static const String _mlBaseUrl = AppConfig.mlApiUrl;

  KYCConfig? _config;
  KYCStateProvider? _stateProvider;
  bool _disposed = false;

  KYCStateProvider? get stateProvider => _stateProvider;

  /// Show a snackbar message
  void showSnackbar(String message) {
    if (!_disposed && _onShowSnackbar != null) {
      _onShowSnackbar!.call(message);
    }
  }

  // Global error handler callback
  Function(KYCResult data)? _onComplete;
  Function(String message)? _onShowSnackbar;

  /// Public method to call the onComplete callback
  void callOnComplete(KYCResult data) {
    if (!_disposed && _onComplete != null) {
      _onComplete!.call(data);
    }
  }

  /// Dispose the service to prevent memory leaks
  void dispose() {
    _onComplete = null;
    _onShowSnackbar = null;
    _stateProvider = null;
    _config = null;
    _disposed = true;
  }

  Future<void> initialize(
    KYCConfig config, {
    KYCStateProvider? stateProvider,
    Function(KYCResult data)? onComplete,
    Function(String message)? onShowSnackbar,
  }) async {
    _config = config;
    _stateProvider = stateProvider;
    _onComplete = onComplete;
    _onShowSnackbar = onShowSnackbar;

    // Save session token to global state
    if (_stateProvider != null) {
      await _stateProvider!.setSessionToken(config.token);
    }

    await _requestPermissions();

    // Fetch presigned URLs in background
    if (_stateProvider != null) {
      getPresignedUrls();
    }
  }

  Future<void> _requestPermissions() async {
    safePrint('Requesting camera and photo permissions...');

    try {
      final cameraStatus = await Permission.camera.request();
      safePrint('Camera permission status: $cameraStatus');

      final photosStatus = await Permission.photos.request();
      safePrint('Photos permission status: $photosStatus');
    } catch (e) {
      safePrint('Error requesting permissions: $e');
    }
  }

  /// Create a liveness session
  Future<String?> createSession() async {
    safePrint('config: $_config');
    if (_config?.token.isEmpty ?? true) return null;

    return await _safeApiCall(() async {
      safePrint('Creating liveness session...');
      final uri = Uri.parse('$_baseUrl/liveness');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${_config!.token}',
          'Content-Type': 'application/json',
        },
      );

      // Use helper method to check for errors
      final data = _checkResponseForErrors(response, context: 'createSession');

      final livenessToken = data['liveness_token'];

      if (livenessToken == null || livenessToken.isEmpty) {
        throw SessionError('Could not get liveness token from response');
      }

      return livenessToken;
    }, context: 'createSession');
  }

  /// Get the current session token
  Future<String?> getSessionToken() async {
    if (_stateProvider != null) {
      return _stateProvider!.sessionToken;
    }
    return _config?.token;
  }

  /// Get liveness result
  Future<GetResultResponse> getResult(String livenessToken) async {
    if (_stateProvider == null || _config == null) {
      throw SessionError('Service not initialized');
    }

    final result = await _safeApiCall(() async {
      safePrint('Getting liveness result...');
      final uri = Uri.parse('$_baseUrl/liveness/result');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${_config!.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'liveness_token': livenessToken}),
      );

      // Use helper method to check for errors
      final data = _checkResponseForErrors(response, context: 'getResult');

      final success = data['success'] ?? false;
      final redirectUrl = data['redirect_url'] ?? '';
      final remainingTries = data['remaining_tries'] ?? 0;

      return GetResultResponse(
        selfieName: livenessToken,
        isLive: success,
        redirectUrl: redirectUrl,
        remainingTries: remainingTries,
      );
    }, context: 'getResult');
    if (result == null) {
      throw SessionError('Failed to get liveness result');
    }
    return result;
  }

  /// Verify identity
  Future<String> verifyIdentity() async {
    if (_stateProvider == null || _config == null) {
      throw SessionError('Service not initialized');
    }

    return await _safeApiCall(() async {
      safePrint('Verifying identity...');
      final uri = Uri.parse('$_baseUrl/verify/');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${_config!.token}',
          'Content-Type': 'application/json',
        },
      );

      // Use helper method to check for errors
      final data = _checkResponseForErrors(response, context: 'verifyIdentity');

      final redirectUrl = data['redirect_url'];

      if (redirectUrl == null) {
        throw SessionError('No redirect URL received');
      }

      return redirectUrl;
    }, context: 'verifyIdentity');
  }

  /// Get presigned URLs for document upload
  Future<PresignedUrl> getPresignedUrls() async {
    if (_stateProvider == null || _config == null) {
      throw SessionError('Service not initialized');
    }

    final result = await _safeApiCall(() async {
      safePrint('Getting presigned URLs...');
      final uri = Uri.parse('$_baseUrl/presign');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${_config!.token}',
          'Content-Type': 'application/json',
        },
      );

      // Use helper method to check for errors
      final data = _checkResponseForErrors(
        response,
        context: 'getPresignedUrls',
      );

      PresignedUrl presignedUrl = PresignedUrl.fromMap(data);

      await _stateProvider!.setPresignedUrl(presignedUrl);
      return presignedUrl;
    }, context: 'getPresignedUrls');

    if (result == null) {
      throw SessionError('Failed to get presigned URLs');
    }
    return result;
  }

  /// Detect document in image
  Future<List<double>?> detectDocument(File file) async {
    final result = await _safeApiCall(() async {
      safePrint('Detecting document...');
      final uri = Uri.parse('$_mlBaseUrl/detection/document');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Content-Type'] = 'multipart/form-data'
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Use helper method to check for errors
      final data = _checkResponseForErrors(response, context: 'detectDocument');

      final success = data['success'] ?? false;
      final bbox = data['bbox'];

      if (!success) {
        safePrint('Warning: Unable to detect ID');
        return <double>[]; // Return empty list instead of null
      }

      if (bbox != null && bbox is List && bbox.length == 4) {
        return bbox.map((e) => (e as num).toDouble()).toList();
      }

      return <double>[]; // Return empty list instead of null
    }, context: 'detectDocument');

    // Convert empty list back to null for the public API
    if (result != null && result.isEmpty) {
      return null;
    }
    return result;
  }

  /// Upload front document using presigned URL
  Future<void> uploadFrontDocument(File file, PresignedUrl presignedUrl) async {
    await _uploadDocumentWithSignedUrl(file, presignedUrl.front);
  }

  /// Upload back document using presigned URL
  Future<void> uploadBackDocument(File file, PresignedUrl presignedUrl) async {
    await _uploadDocumentWithSignedUrl(file, presignedUrl.back);
  }

  /// Helper method to check multipart upload response for errors
  Future<void> _checkMultipartResponseForErrors(
    http.StreamedResponse response, {
    String? context,
  }) async {
    if (response.statusCode == 200 ||
        response.statusCode == 201 ||
        response.statusCode == 204) {
      return; // Success
    }

    final responseBody = await response.stream.bytesToString();

    // Try to extract actual error message from response body
    try {
      final errorData = json.decode(responseBody);
      final message =
          errorData['message']?.toString() ??
          errorData['error']?.toString() ??
          'Upload failed with status ${response.statusCode}';
      throw SessionError(message, redirectUrl: errorData['redirect_url']);
    } catch (jsonError) {
      // If JSON parsing fails, use the error handler service
      final errorHandler = ErrorHandlerService();
      final errorInfo = errorHandler.processUploadError(
        responseBody,
        response.statusCode,
      );
      final message = errorHandler.getUserMessage(errorInfo);
      throw SessionError(message);
    }
  }

  /// Private method to upload a document using a SignedUrl (front or back)
  Future<void> _uploadDocumentWithSignedUrl(
    File file,
    SignedUrl signedUrl,
  ) async {
    // Validate the signed URL before proceeding
    if (signedUrl.url.isEmpty) {
      safePrint('Error: Signed URL is empty');
      throw SessionError('Invalid upload URL: URL is empty');
    }

    safePrint('Uploading document to: ${signedUrl.url}');
    final request = http.MultipartRequest('POST', Uri.parse(signedUrl.url));

    // Add fields
    final fieldsMap = signedUrl.fields.toMap();
    request.fields.addAll(Map<String, String>.from(fieldsMap));

    // Add file
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();

    // Check for errors using specialized helper for multipart uploads
    await _checkMultipartResponseForErrors(response, context: 'uploadDocument');
  }

  // Centralized error handler instance
  static final ErrorHandlerService _errorHandler = ErrorHandlerService();

  /// Global error handler for all API calls
  void _handleError(dynamic error, {String? context}) {
    safePrint('error: $error');
    final errorInfo = _errorHandler.processError(error, context: context);

    // Check if service has been disposed
    if (_disposed) {
      safePrint('Service has been disposed, skipping error handling');
      return;
    }

    // Show user-friendly message
    final userMessage = _errorHandler.getUserMessage(errorInfo);
    if (_onShowSnackbar != null) {
      _onShowSnackbar!.call(userMessage);
    }

    // Check for session expiration
    if (errorInfo.message.contains('session expired') ||
        errorInfo.message.contains('session expired or complete')) {
      // Check if onComplete callback is still valid before calling it
      if (_onComplete != null) {
        _onComplete!.call(KYCResult.failure(status: KYCStatus.failure));
      }
      return;
    }

    // Re-throw the error so it can be caught by the calling method
    if (error is SessionError) {
      throw error;
    } else {
      // Use the actual message from the error info, not a generic one
      throw SessionError(errorInfo.message);
    }
  }

  /// Helper method to check response for errors and extract data
  Map<String, dynamic> _checkResponseForErrors(
    http.Response response, {
    String? context,
  }) {
    final responseBody = response.body;
    safePrint('${context ?? 'API'} response: $responseBody');

    Map<String, dynamic> data;
    try {
      data = json.decode(responseBody);
    } catch (e) {
      throw SessionError('Invalid response format: $responseBody');
    }

    // Check for error messages in response body (regardless of HTTP status)
    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString() ?? '';
      if (message.isNotEmpty) {
        throw SessionError(message, redirectUrl: data['redirect_url']);
      }
    }

    // Check HTTP status code
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          data['message']?.toString() ??
          data['error']?.toString() ??
          'HTTP ${response.statusCode} error';
      throw SessionError(message, redirectUrl: data['redirect_url']);
    }

    return data;
  }

  /// Safe API call wrapper
  Future<T?> _safeApiCall<T>(
    Future<T> Function() apiCall, {
    String? context,
  }) async {
    try {
      return await apiCall();
    } catch (e) {
      _handleError(e, context: context);
      return null;
    }
  }
}
