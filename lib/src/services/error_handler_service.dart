import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/kyc_api_models.dart' show SessionError;

/// Error types for better categorization
enum ErrorType { network, upload, session, validation, server, unknown }

/// Error severity levels
enum ErrorSeverity {
  info, // Informational messages
  warning, // Warnings that don't prevent operation
  error, // Errors that prevent operation
}

/// Error information model
class ErrorInfo {
  final String message;
  final ErrorType type;
  final ErrorSeverity severity;
  final String? code;
  final Map<String, dynamic>? data;

  const ErrorInfo({
    required this.message,
    required this.type,
    required this.severity,
    this.code,
    this.data,
  });

  @override
  String toString() =>
      'ErrorInfo(message: $message, type: $type, severity: $severity)';
}

/// Flutter-pattern error handling service
class ErrorHandlerService {
  static const String _tag = 'ErrorHandlerService';

  // Singleton pattern
  static final ErrorHandlerService _instance = ErrorHandlerService._internal();
  factory ErrorHandlerService() => _instance;
  ErrorHandlerService._internal();

  // Error message cache for efficiency
  final Map<String, ErrorInfo> _errorCache = {};

  /// Process any error and return structured ErrorInfo
  ErrorInfo processError(dynamic error, {String? context}) {
    final errorKey = '${error.runtimeType}_${error.toString()}';

    // Check cache first
    if (_errorCache.containsKey(errorKey)) {
      return _errorCache[errorKey]!;
    }

    ErrorInfo errorInfo;

    if (error is SessionError) {
      errorInfo = _processSessionError(error);
    } else if (error.toString().contains('SocketException') ||
        error.toString().contains('TimeoutException')) {
      errorInfo = _processNetworkError(error);
    } else if (error.toString().contains('FormatException')) {
      errorInfo = _processFormatError(error);
    } else {
      // Try to parse as JSON error response
      final jsonError = _processJsonError(error);
      errorInfo = jsonError ?? _processGenericError(error);
    }

    // Cache the result
    _errorCache[errorKey] = errorInfo;

    // Log for debugging
    _logError(context, error, errorInfo);

    return errorInfo;
  }

  /// Process upload-specific errors
  ErrorInfo processUploadError(String responseBody, int statusCode) {
    try {
      // Try JSON first
      final data = json.decode(responseBody);
      final message = data['message'] ?? data['error'] ?? 'Upload failed';

      return ErrorInfo(
        message: message,
        type: ErrorType.upload,
        severity: ErrorSeverity.error,
        code: data['error_code'],
        data: data,
      );
    } catch (jsonError) {
      // Handle XML responses
      return _processXmlError(responseBody, statusCode);
    }
  }

  /// Check if error requires specific action
  bool requiresSessionRefresh(ErrorInfo errorInfo) {
    return errorInfo.type == ErrorType.session ||
        errorInfo.message.contains('expired') ||
        errorInfo.message.contains('AccessDenied') ||
        errorInfo.message.contains('unauthorized');
  }

  bool requiresUserAction(ErrorInfo errorInfo) {
    return errorInfo.type == ErrorType.validation ||
        errorInfo.message.contains('Please select') ||
        errorInfo.message.contains('No front document');
  }

  /// Get user-friendly message
  String getUserMessage(ErrorInfo errorInfo) {
    switch (errorInfo.type) {
      case ErrorType.network:
        return 'Network error. Please check your connection and try again.';
      case ErrorType.session:
        return 'Session expired. Please try again.';
      case ErrorType.upload:
        return 'Upload failed. Please try again.';
      case ErrorType.validation:
        return 'Invalid input. Please check your information and try again.';
      case ErrorType.server:
        return 'Server error. Please try again later.';
      case ErrorType.unknown:
      default:
        return errorInfo.message.isNotEmpty
            ? errorInfo.message
            : 'An unexpected error occurred. Please try again.';
    }
  }

  // Private methods for error processing
  ErrorInfo _processSessionError(SessionError error) {
    return ErrorInfo(
      message: error.message,
      type: ErrorType.session,
      severity: ErrorSeverity.error,
      data: error.data,
    );
  }

  ErrorInfo _processNetworkError(dynamic error) {
    return ErrorInfo(
      message: 'Network connection error',
      type: ErrorType.network,
      severity: ErrorSeverity.error,
    );
  }

  ErrorInfo _processFormatError(dynamic error) {
    return ErrorInfo(
      message: 'Invalid data format',
      type: ErrorType.validation,
      severity: ErrorSeverity.error,
    );
  }

  ErrorInfo _processGenericError(dynamic error) {
    return ErrorInfo(
      message: error.toString(),
      type: ErrorType.unknown,
      severity: ErrorSeverity.error,
    );
  }

  ErrorInfo? _processJsonError(dynamic error) {
    try {
      if (error is String) {
        final data = json.decode(error);
        if (data is Map<String, dynamic>) {
          final message = data['message'] ?? data['error'] ?? error.toString();
          final code = data['error_code'];

          if (message.contains('expired') || message.contains('AccessDenied')) {
            return ErrorInfo(
              message: message,
              type: ErrorType.session,
              severity: ErrorSeverity.error,
              code: code,
              data: data,
            );
          }
        }
      } else if (error is Map<String, dynamic>) {
        final message = error['message'] ?? error['error'] ?? error.toString();
        final code = error['error_code'];

        if (message.contains('expired') || message.contains('AccessDenied')) {
          return ErrorInfo(
            message: message,
            type: ErrorType.session,
            severity: ErrorSeverity.error,
            code: code,
            data: error,
          );
        }
      }
    } catch (e) {
      // If JSON parsing fails, return null to fall back to generic error
    }
    return null;
  }

  ErrorInfo _processXmlError(String responseBody, int statusCode) {
    String message;
    ErrorType type = ErrorType.upload;

    if (responseBody.contains('Policy expired')) {
      message = 'Upload session expired';
      type = ErrorType.session;
    } else if (responseBody.contains('AccessDenied')) {
      message = 'Access denied';
      type = ErrorType.session;
    } else if (responseBody.contains('InvalidArgument')) {
      message = 'Invalid request';
      type = ErrorType.validation;
    } else if (responseBody.contains('NoSuchBucket')) {
      message = 'Storage bucket not found';
      type = ErrorType.server;
    } else if (responseBody.contains('SignatureDoesNotMatch')) {
      message = 'Authentication failed';
      type = ErrorType.session;
    } else {
      message = 'Server error';
      type = ErrorType.server;
    }

    return ErrorInfo(
      message: message,
      type: type,
      severity: ErrorSeverity.error,
      code: statusCode.toString(),
    );
  }

  void _logError(String? context, dynamic error, ErrorInfo errorInfo) {
    if (kDebugMode) {
      print('[$_tag] Error in ${context ?? 'unknown'}: ${errorInfo.message}');
      print('[$_tag] Type: ${errorInfo.type}, Severity: ${errorInfo.severity}');
      if (errorInfo.data != null) {
        print('[$_tag] Data: ${errorInfo.data}');
      }
    }
  }

  /// Clear error cache (useful for testing)
  void clearCache() {
    _errorCache.clear();
  }
}
