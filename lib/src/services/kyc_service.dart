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
import 'package:flutter/foundation.dart';

class KYCService {
  static const String _baseUrl = AppConfig.kycApiUrl;
  static const String _mlBaseUrl = AppConfig.mlApiUrl;

  KYCConfig? _config;
  KYCStateProvider? _stateProvider;
  final ImagePicker _imagePicker = ImagePicker();

  KYCStateProvider? get stateProvider => _stateProvider;

  // Global error handler callback
  Function(bool success, Map<String, dynamic> data)? _onComplete;
  VoidCallback? _onError;
  Function(String message)? _onShowSnackbar;

  Future<void> initialize(
    KYCConfig config, {
    KYCStateProvider? stateProvider,
    Function(bool success, Map<String, dynamic> data)? onComplete,
    VoidCallback? onError,
    Function(String message)? onShowSnackbar,
  }) async {
    _config = config;
    _stateProvider = stateProvider;
    _onComplete = onComplete;
    _onError = onError;
    _onShowSnackbar = onShowSnackbar;

    // Save session token to global state
    if (_stateProvider != null) {
      await _stateProvider!.setSessionToken(config.token);
    }

    await _requestPermissions();

    // Fetch presigned URLs in background
    if (_stateProvider != null) {
      _fetchPresignedUrlInBackground();
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

  Future<PresignedUrl?> _fetchPresignedUrlInBackground() async {
    if (_stateProvider == null || _config == null) return null;

    return await _safeApiCall(() async {
      // Set loading state
      await _stateProvider!.setLoadingPresignedUrl(true);

      safePrint('Fetching presigned URLs...');

      // Fetch presigned URLs
      final presignedUrl = await getPresignedUrls(_config!.token);

      safePrint('Presigned URL response: ${presignedUrl.toMap()}');

      // Save to global state
      await _stateProvider!.setPresignedUrl(presignedUrl);
      return presignedUrl;
    }, context: 'fetchPresignedUrls');
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
  Future<GetResultResponse> getResult({
    required String livenessToken,
    required String sessionToken,
  }) async {
    try {
      safePrint('Getting liveness result...');
      final uri = Uri.parse('$_baseUrl/liveness/result');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $sessionToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'liveness_token': livenessToken}),
      );

      safePrint('Liveness result response: ${response.body}');

      final data = json.decode(response.body);
      final success = data['success'] ?? false;
      final redirectUrl = data['redirect_url'] ?? '';
      final remainingTries = data['remaining_tries'] ?? 0;

      return GetResultResponse(
        selfieName: livenessToken,
        isLive: success,
        redirectUrl: redirectUrl,
        remainingTries: remainingTries,
      );
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

  /// Verify identity
  Future<String> verifyIdentity({required String sessionToken}) async {
    try {
      safePrint('Verifying identity...');
      final uri = Uri.parse('$_baseUrl/verify/');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $sessionToken',
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

  /// Get presigned URLs for document upload
  Future<PresignedUrl> getPresignedUrls(String sessionToken) async {
    try {
      safePrint('Getting presigned URLs...');
      final uri = Uri.parse('$_baseUrl/presign');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $sessionToken',
          'Content-Type': 'application/json',
        },
      );

      safePrint('Presigned URLs response: ${response.body}');

      final data = json.decode(response.body);

      if (data == null) {
        throw SessionError('Could not get presigned URLs');
      }

      return PresignedUrl.fromMap(data);
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
  Future<Map<String, dynamic>?> detectDocument(File file) async {
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
      }

      return bbox;
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
    try {
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

        String message = 'Upload failed';
        String? redirectUrl;

        try {
          final data = json.decode(responseBody);
          message = data['message'] ?? data['error'] ?? 'Upload failed';
          redirectUrl = data['redirect_url'];
        } catch (jsonError) {
          // If response is not JSON (e.g., XML), use the raw response or status code
          if (responseBody.contains('<?xml')) {
            message = 'Server error: Invalid response format';
          } else {
            message = 'Upload failed: HTTP ${response.statusCode}';
          }
        }

        throw SessionError(message, redirectUrl: redirectUrl);
      }
    } catch (e) {
      if (e is SessionError) rethrow;
      throw SessionError('Upload failed: $e');
    }
  }

  // Legacy methods for backward compatibility
  Future<KYCResult> captureDocument() async {
    try {
      if (_config?.customization.docSrc == 'LIVE') {
        return await _captureFromCamera();
      } else {
        return await _pickFromGallery();
      }
    } catch (e) {
      return KYCResult.failure(error: 'Failed to capture document: $e');
    }
  }

  Future<KYCResult> _captureFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image == null) {
        return KYCResult.failure(error: 'No image captured');
      }

      return await _uploadDocument(File(image.path));
    } catch (e) {
      return KYCResult.failure(error: 'Camera capture failed: $e');
    }
  }

  Future<KYCResult> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) {
        return KYCResult.failure(error: 'No image selected');
      }

      return await _uploadDocument(File(image.path));
    } catch (e) {
      return KYCResult.failure(error: 'Gallery selection failed: $e');
    }
  }

  Future<KYCResult> _uploadDocument(File imageFile) async {
    try {
      if (_config == null) {
        return KYCResult.failure(error: 'Service not initialized');
      }

      final uri = Uri.parse('$_baseUrl/upload-document');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${_config!.token}'
        ..headers['Content-Type'] = 'multipart/form-data'
        ..fields.addAll({
          'first_name': _config!.userInfo.firstName,
          'last_name': _config!.userInfo.lastName,
          'document_type': _config!.userInfo.documentType,
          'issuing_country': _config!.userInfo.issuingCountry,
          ..._config!.customization.toMap(),
        })
        ..files.add(
          await http.MultipartFile.fromPath('document', imageFile.path),
        );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = json.decode(responseBody);

      if (response.statusCode == 200) {
        return KYCResult.success(status: data['status'], data: data);
      } else {
        return KYCResult.failure(
          error: data['error'] ?? 'Upload failed',
          errorCode: data['error_code'],
          data: data,
        );
      }
    } catch (e) {
      return KYCResult.failure(error: 'Upload failed: $e');
    }
  }

  Future<KYCResult> verifyFace() async {
    try {
      if (_config == null) {
        return KYCResult.failure(error: 'Service not initialized');
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image == null) {
        return KYCResult.failure(error: 'No face image captured');
      }

      final uri = Uri.parse('$_baseUrl/verify-face');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${_config!.token}'
        ..files.add(
          await http.MultipartFile.fromPath('face_image', image.path),
        );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = json.decode(responseBody);

      if (response.statusCode == 200) {
        return KYCResult.success(status: data['status'], data: data);
      } else {
        return KYCResult.failure(
          error: data['error'] ?? 'Face verification failed',
          errorCode: data['error_code'],
          data: data,
        );
      }
    } catch (e) {
      return KYCResult.failure(error: 'Face verification failed: $e');
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

  /// Global error handler for all API calls
  void _handleError(dynamic error, {String? context}) {
    safePrint('Error in $context: $error');

    if (error is SessionError) {
      // Handle SessionError with redirect URL
      if (error.redirectUrl != null) {
        safePrint('Redirecting to: ${error.redirectUrl}');
        _onComplete?.call(false, {
          'error': error.message,
          'redirectUrl': error.redirectUrl,
          'context': context,
        });
        // Call onError to close the app when there's a redirect URL
        _onError?.call();
      } else {
        // Show snackbar for errors without redirect URL
        _onShowSnackbar?.call(error.message);
      }
    } else {
      // Show snackbar for other errors
      _onShowSnackbar?.call(error.toString());
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
