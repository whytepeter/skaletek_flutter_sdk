import 'dart:convert';
import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/kyc_config.dart';
import '../models/kyc_result.dart';
import '../models/kyc_api_models.dart';
import '../config/app_config.dart';
import 'kyc_state_provider.dart';
import 'error_handler_service.dart';
import 'package:flutter/foundation.dart';

class KYCService {
  static const String _baseUrl = AppConfig.kycApiUrl;
  static const String _mlBaseUrl = AppConfig.mlApiUrl;

  KYCConfig? _config;
  KYCStateProvider? _stateProvider;
  final ImagePicker _imagePicker = ImagePicker();

  KYCStateProvider? get stateProvider => _stateProvider;

  /// Show a snackbar message
  void showSnackbar(String message) {
    _onShowSnackbar?.call(message);
  }

  // Global error handler callback
  Function(bool success, Map<String, dynamic> data)? _onComplete;
  Function(String message)? _onShowSnackbar;

  /// Public method to call the onComplete callback
  void callOnComplete(bool success, Map<String, dynamic> data) {
    _onComplete?.call(success, data);
  }

  Future<void> initialize(
    KYCConfig config, {
    KYCStateProvider? stateProvider,
    Function(bool success, Map<String, dynamic> data)? onComplete,
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

      safePrint('Request URL: $uri');
      safePrint(
        'Request headers: Authorization: Bearer ${_config!.token.substring(0, 10)}...',
      );

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${_config!.token}',
          'Content-Type': 'application/json',
        },
      );

      safePrint('Liveness session response status: ${response.statusCode}');
      safePrint('Liveness session response body: ${response.body}');

      if (response.statusCode != 200) {
        safePrint('Error: HTTP ${response.statusCode} - ${response.body}');
        throw SessionError(
          'Failed to create liveness session: HTTP ${response.statusCode}',
        );
      }

      final data = json.decode(response.body);
      final livenessToken = data['liveness_token'];

      if (livenessToken == null || livenessToken.isEmpty) {
        safePrint('Error: No liveness token in response');
        throw SessionError('Could not get liveness token from response');
      }

      safePrint(
        'Successfully created liveness session with token: ${livenessToken.substring(0, 10)}...',
      );
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

      safePrint('Liveness result response: ${response.body}');

      final data = json.decode(response.body);
      final success = data['success'] ?? false;
      final redirectUrl = data['redirect_url'] ?? '';
      final remainingTries = data['remaining_tries'] ?? 0;

      if (data['type'] == 'validation_error' || data['message'] != null) {
        throw SessionError(data['message'] ?? 'Validation error');
      }

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

      safePrint('Verify identity response: ${response.body}');

      final data = json.decode(response.body);
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

    try {
      safePrint('Getting presigned URLs...');
      final uri = Uri.parse('$_baseUrl/presign');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${_config!.token}',
          'Content-Type': 'application/json',
        },
      );

      safePrint('Presigned URLs response: ${response.body}');

      final data = json.decode(response.body);

      if (data == null) {
        throw SessionError('Could not get presigned URLs');
      }

      PresignedUrl presignedUrl = PresignedUrl.fromMap(data);

      await _stateProvider!.setPresignedUrl(presignedUrl);
      return presignedUrl;
    } catch (e) {
      if (e is SessionError) rethrow;

      try {
        final errorData = json.decode(e.toString());
        final message =
            errorData['message'] ?? errorData['error'] ?? 'An error occurred';
        throw SessionError(message, redirectUrl: errorData['redirect_url']);
      } catch (_) {
        throw SessionError('An error occurred');
      }
    }
  }

  /// Detect document in image
  Future<List<double>?> detectDocument(File file) async {
    try {
      safePrint('Detecting document...');
      final uri = Uri.parse('$_mlBaseUrl/detection/document');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Content-Type'] = 'multipart/form-data'
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      safePrint('Document detection response: ${response.body}');

      final success = data['success'] ?? false;
      final bbox = data['bbox'];

      if (!success) {
        safePrint('Warning: Unable to detect ID');
        return null;
      }

      if (bbox != null && bbox is List && bbox.length == 4) {
        return bbox.map((e) => (e as num).toDouble()).toList();
      }

      return null;
    } catch (e) {
      try {
        final errorData = json.decode(e.toString());
        final message =
            errorData['message'] ??
            errorData['liveness_error'] ??
            'An error occurred';
        throw SessionError(message, redirectUrl: errorData['redirect_url']);
      } catch (_) {
        throw SessionError('An error occurred');
      }
    }
  }

  /// Upload front document using presigned URL
  Future<void> uploadFrontDocument(File file, PresignedUrl presignedUrl) async {
    await _uploadDocumentWithSignedUrl(file, presignedUrl.front);
  }

  /// Upload back document using presigned URL
  Future<void> uploadBackDocument(File file, PresignedUrl presignedUrl) async {
    await _uploadDocumentWithSignedUrl(file, presignedUrl.back);
  }

  /// Private method to upload a document using a SignedUrl (front or back)
  Future<void> _uploadDocumentWithSignedUrl(
    File file,
    SignedUrl signedUrl,
  ) async {
    safePrint('Uploading document to: ${signedUrl.url}');
    final request = http.MultipartRequest('POST', Uri.parse(signedUrl.url));

    // Add fields
    final fieldsMap = signedUrl.fields.toMap();
    request.fields.addAll(Map<String, String>.from(fieldsMap));

    // Add file
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      final responseBody = await response.stream.bytesToString();
      safePrint('Upload response status: ${response.statusCode}');
      safePrint('Upload response body: $responseBody');

      final errorHandler = ErrorHandlerService();
      final errorInfo = errorHandler.processUploadError(
        responseBody,
        response.statusCode,
      );
      final message = errorHandler.getUserMessage(errorInfo);
      throw SessionError(message);
    }
  }

  Future<KYCResult> getVerificationStatus(String verificationId) async {
    try {
      if (_config == null) {
        return KYCResult.failure(error: 'Service not initialized');
      }

      final uri = Uri.parse('$_baseUrl/status/$verificationId');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${_config!.token}',
          'Content-Type': 'application/json',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return KYCResult.success(status: data['status'], data: data);
      } else {
        return KYCResult.failure(
          error: data['error'] ?? 'Failed to get status',
          errorCode: data['error_code'],
          data: data,
        );
      }
    } catch (e) {
      return KYCResult.failure(error: 'Status check failed: $e');
    }
  }

  // Centralized error handler instance
  static final ErrorHandlerService _errorHandler = ErrorHandlerService();

  /// Global error handler for all API calls
  void _handleError(dynamic error, {String? context}) {
    final errorInfo = _errorHandler.processError(error, context: context);

    // Show user-friendly message
    final userMessage = _errorHandler.getUserMessage(errorInfo);
    _onShowSnackbar?.call(userMessage);

    // Re-throw the error so it can be caught by the calling method
    if (error is SessionError) {
      throw error;
    } else {
      throw SessionError(errorInfo.message);
    }
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
