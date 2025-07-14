import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/kyc_config.dart';
import 'models/kyc_result.dart';
import 'models/kyc_user_info.dart';
import 'models/kyc_customization.dart';
import 'services/kyc_state_provider.dart';
import 'ui/kyc_verification_screen.dart';

/// Singleton for starting the KYC verification process using model objects.
class SkaletekKYC {
  SkaletekKYC._internal();
  static final SkaletekKYC _instance = SkaletekKYC._internal();
  static SkaletekKYC get instance => _instance;

  /// Global navigator key for navigation
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Starts the KYC verification process using model objects.
  ///
  /// [token] - Authentication token for the verification session
  /// [userInfo] - User information model
  /// [customization] - UI customization model
  /// [onComplete] - Callback called with the result as a Map
  Future<void> startVerification({
    required String token,
    required KYCUserInfo userInfo,
    required KYCCustomization customization,
    required Function(Map<String, dynamic> result) onComplete,
  }) async {
    try {
      final config = KYCConfig(
        token: token,
        userInfo: userInfo,
        customization: customization,
      );
      await resetKYCState();
      final result = await Navigator.of(_getCurrentContext()).push<KYCResult>(
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider(
            create: (_) => KYCStateProvider(),
            child: KYCVerificationScreen(config: config),
          ),
        ),
      );
      if (result != null) {
        onComplete(result.toMap());
      } else {
        onComplete(KYCResult.failure(status: KYCStatus.failure).toMap());
      }
    } catch (e) {
      onComplete(KYCResult.failure(status: KYCStatus.failure).toMap());
    }
  }

  /// Resets the KYC state (useful for testing or new sessions).
  Future<void> resetKYCState() async {
    await KYCStateProvider().resetState();
  }

  BuildContext _getCurrentContext() {
    final context = navigatorKey.currentContext;
    if (context == null) {
      throw StateError('No navigator context available.');
    }
    return context;
  }
}
