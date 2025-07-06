import 'package:flutter/material.dart';
import 'models/kyc_config.dart';
import 'models/kyc_result.dart';
import 'models/kyc_user_info.dart';
import 'models/kyc_customization.dart';
import 'services/kyc_service.dart';
import 'ui/kyc_verification_screen.dart';

class SkaletekKYC {
  static final SkaletekKYC _instance = SkaletekKYC._internal();
  factory SkaletekKYC() => _instance;
  SkaletekKYC._internal();

  static SkaletekKYC get instance => _instance;

  final KYCService _kycService = KYCService();

  /// Starts the KYC verification process
  ///
  /// [token] - Authentication token for the verification session
  /// [userInfo] - User information map containing first_name, last_name, document_type, issuing_country
  /// [customization] - UI customization options
  /// [onComplete] - Callback function called when verification completes
  Future<void> startVerification({
    required String token,
    required Map<String, String> userInfo,
    required Map<String, String> customization,
    required Function(bool success, Map<String, dynamic> data) onComplete,
  }) async {
    try {
      // Validate inputs
      _validateInputs(token, userInfo, customization);

      // Convert maps to model objects
      final kycUserInfo = KYCUserInfo.fromMap(userInfo);
      final kycCustomization = KYCCustomization.fromMap(customization);

      // Create config
      final config = KYCConfig(
        token: token,
        userInfo: kycUserInfo,
        customization: kycCustomization,
      );

      // Initialize the service
      await _kycService.initialize(config);

      // Navigate to verification screen
      final result = await Navigator.of(_getCurrentContext()).push<KYCResult>(
        MaterialPageRoute(
          builder: (context) => KYCVerificationScreen(config: config),
        ),
      );

      // Handle result
      if (result != null) {
        onComplete(result.success, result.toMap());
      } else {
        onComplete(false, {'error': 'Verification was cancelled'});
      }
    } catch (e) {
      onComplete(false, {'error': e.toString()});
    }
  }

  /// Alternative method using model objects directly
  Future<void> startVerificationWithModels({
    required String token,
    required KYCUserInfo userInfo,
    required KYCCustomization customization,
    required Function(bool success, Map<String, dynamic> data) onComplete,
  }) async {
    try {
      final config = KYCConfig(
        token: token,
        userInfo: userInfo,
        customization: customization,
      );

      await _kycService.initialize(config);

      final result = await Navigator.of(_getCurrentContext()).push<KYCResult>(
        MaterialPageRoute(
          builder: (context) => KYCVerificationScreen(config: config),
        ),
      );

      if (result != null) {
        onComplete(result.success, result.toMap());
      } else {
        onComplete(false, {'error': 'Verification was cancelled'});
      }
    } catch (e) {
      onComplete(false, {'error': e.toString()});
    }
  }

  void _validateInputs(
    String token,
    Map<String, String> userInfo,
    Map<String, String> customization,
  ) {
    if (token.isEmpty) {
      throw ArgumentError('Token cannot be empty');
    }

    final requiredUserFields = [
      'first_name',
      'last_name',
      'document_type',
      'issuing_country',
    ];
    for (final field in requiredUserFields) {
      if (!userInfo.containsKey(field) || userInfo[field]?.isEmpty == true) {
        throw ArgumentError('Missing required user info field: $field');
      }
    }

    if (!customization.containsKey('doc_src')) {
      throw ArgumentError('Missing required customization field: doc_src');
    }

    final validDocSrc = ['LIVE', 'FILE'];
    if (!validDocSrc.contains(customization['doc_src'])) {
      throw ArgumentError(
        'Invalid doc_src value. Must be either "LIVE" or "FILE"',
      );
    }
  }

  BuildContext _getCurrentContext() {
    // This is a simplified approach. In a real implementation,
    // you might want to use a more robust method to get the current context
    // For now, we'll use a global navigator key approach
    return navigatorKey.currentContext!;
  }

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}
