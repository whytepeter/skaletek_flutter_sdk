import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/kyc_api_models.dart';
import 'dart:convert';

class KYCStateProvider extends ChangeNotifier {
  static const String _hasSeenDocumentDemoKey = 'has_seen_document_demo';
  static const String _hasSeenDosAndDontsKey = 'has_seen_dos_and_donts';
  static const String _sessionTokenKey = 'session_token';
  static const String _presignedUrlKey = 'presigned_url';

  bool _hasSeenDocumentDemo = false;
  bool _hasSeenDosAndDonts = false;
  String? _sessionToken;
  PresignedUrl? _presignedUrl;
  bool _isLoadingPresignedUrl = false;

  bool get hasSeenDocumentDemo => _hasSeenDocumentDemo;
  bool get hasSeenDosAndDonts => _hasSeenDosAndDonts;
  String? get sessionToken => _sessionToken;
  PresignedUrl? get presignedUrl => _presignedUrl;
  bool get isLoadingPresignedUrl => _isLoadingPresignedUrl;

  KYCStateProvider() {
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasSeenDocumentDemo = prefs.getBool(_hasSeenDocumentDemoKey) ?? false;
      _hasSeenDosAndDonts = prefs.getBool(_hasSeenDosAndDontsKey) ?? false;
      _sessionToken = prefs.getString(_sessionTokenKey);

      // Load presigned URL from JSON string
      final presignedUrlJson = prefs.getString(_presignedUrlKey);
      if (presignedUrlJson != null) {
        try {
          final Map<String, dynamic> data = json.decode(presignedUrlJson);
          _presignedUrl = PresignedUrl.fromMap(data);
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing presigned URL: $e');
          }
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading KYC state: $e');
      }
    }
  }

  Future<void> setSessionToken(String token) async {
    _sessionToken = token;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionTokenKey, token);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving session token: $e');
      }
    }
  }

  Future<void> setPresignedUrl(PresignedUrl presignedUrl) async {
    _presignedUrl = presignedUrl;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final presignedUrlJson = json.encode(presignedUrl.toMap());
      await prefs.setString(_presignedUrlKey, presignedUrlJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving presigned URL: $e');
      }
    }
  }

  Future<void> setLoadingPresignedUrl(bool loading) async {
    _isLoadingPresignedUrl = loading;
    notifyListeners();
  }

  Future<void> markDocumentDemoAsSeen() async {
    if (_hasSeenDocumentDemo) return;

    _hasSeenDocumentDemo = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasSeenDocumentDemoKey, true);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving document demo state: $e');
      }
    }
  }

  Future<void> markDosAndDontsAsSeen() async {
    if (_hasSeenDosAndDonts) return;

    _hasSeenDosAndDonts = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasSeenDosAndDontsKey, true);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving dos and donts state: $e');
      }
    }
  }

  Future<void> resetState() async {
    _hasSeenDocumentDemo = false;
    _hasSeenDosAndDonts = false;
    _sessionToken = null;
    _presignedUrl = null;
    _isLoadingPresignedUrl = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_hasSeenDocumentDemoKey);
      await prefs.remove(_hasSeenDosAndDontsKey);
      await prefs.remove(_sessionTokenKey);
      await prefs.remove(_presignedUrlKey);
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting KYC state: $e');
      }
    }
  }
}
