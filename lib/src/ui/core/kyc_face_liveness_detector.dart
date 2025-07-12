import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:skaletek_kyc_flutter/src/services/kyc_service.dart';
import 'package:skaletek_kyc_flutter/src/config/app_config.dart';
import 'package:face_liveness_detector/face_liveness_detector.dart';

class KYCFaceLivenessDetector extends StatefulWidget {
  const KYCFaceLivenessDetector({
    super.key,
    required this.sessionId,
    required this.kycService,
    required this.onComplete,
    required this.onError,
  });

  final String sessionId;
  final KYCService kycService;
  final VoidCallback onComplete;
  final Function(String error) onError;

  @override
  State<KYCFaceLivenessDetector> createState() =>
      _KYCFaceLivenessDetectorState();
}

class _KYCFaceLivenessDetectorState extends State<KYCFaceLivenessDetector> {
  bool _isInitialized = false;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    _initializeLivenessDetector();
  }

  Future<void> _initializeLivenessDetector() async {
    try {
      if (kDebugMode) {
        print('🚀 Initializing face liveness detector...');
      }

      // Add a small delay to ensure widget is fully built
      await Future.delayed(const Duration(milliseconds: 100));

      setState(() {
        _isInitialized = true;
      });

      if (kDebugMode) {
        print('✅ Face liveness detector initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing face liveness detector: $e');
      }
      setState(() {
        _initializationError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return _buildErrorWidget(_initializationError!);
    }

    if (!_isInitialized) {
      return _buildLoadingWidget();
    }

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: FaceLivenessDetector(
        sessionId: widget.sessionId,
        region: AppConfig.region,
        onComplete: () {
          if (kDebugMode) {
            print('✅ Face Liveness completed successfully');
          }
          widget.onComplete();
        },
        onError: widget.onError,
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Initializing face liveness detector...'),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Failed to initialize face liveness detector'),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _initializationError = null;
                _isInitialized = false;
              });
              _initializeLivenessDetector();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
