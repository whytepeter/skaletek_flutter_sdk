import 'kyc_user_info.dart';
import 'kyc_customization.dart';

class KYCConfig {
  final String token;
  final KYCUserInfo userInfo;
  final KYCCustomization customization;

  const KYCConfig({
    required this.token,
    required this.userInfo,
    required this.customization,
  });

  Map<String, dynamic> toMap() {
    return {
      'token': token,
      'userInfo': userInfo.toMap(),
      'customization': customization.toMap(),
    };
  }

  factory KYCConfig.fromMap(Map<String, dynamic> map) {
    return KYCConfig(
      token: map['token'] ?? '',
      userInfo: KYCUserInfo.fromMap(map['userInfo'] ?? {}),
      customization: KYCCustomization.fromMap(map['customization'] ?? {}),
    );
  }

  @override
  String toString() {
    return 'KYCConfig(token: $token, userInfo: $userInfo, customization: $customization)';
  }
}
