import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_api_models.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_user_info.dart';
import 'package:skaletek_kyc_flutter/src/services/kyc_service.dart';
import 'package:skaletek_kyc_flutter/src/config/app_config.dart';
import 'package:skaletek_kyc_flutter/src/ui/core/kyc_face_liveness_detector.dart';
import 'package:skaletek_kyc_flutter/src/ui/layout/content.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/button.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/spinner.dart';

class KYCFaceVerification extends StatefulWidget {
  const KYCFaceVerification({
    super.key,
    this.onBack,
    this.onNext,
    required this.kycService,
    this.userInfo,
  });

  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final KYCService kycService;
  final KYCUserInfo? userInfo;

  @override
  State<KYCFaceVerification> createState() => _KYCFaceVerificationState();
}

class _KYCFaceVerificationState extends State<KYCFaceVerification> {
  bool _isLoading = false;
  String _sessionId = '';
  bool _showLivenessDetector = false;

  Future<void> _startLivenessCheck() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final res = await widget.kycService.createSession();
      if (res != null) {
        setState(() {
          _sessionId = res;
          _showLivenessDetector = true;
        });
      }
    } catch (e) {
      // Error will be handled by global error handler
      if (kDebugMode) {
        print('Error creating session: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onLivenessComplete() {
    setState(() {
      _showLivenessDetector = false;
    });
  }

  void _onLivenessError(String error) {
    setState(() {
      _showLivenessDetector = false;
    });

    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    if (_showLivenessDetector) {
      return Container(
        height: MediaQuery.of(context).size.height - 120,
        color: Colors.red,
        padding: const EdgeInsets.all(16),
        child: KYCFaceLivenessDetector(
          sessionId: _sessionId,
          kycService: widget.kycService,
          onComplete: _onLivenessComplete,
          onError: _onLivenessError,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          KYCContent(
            step: KYCStep.liveness,
            userInfo: widget.userInfo,
            footer: _buildFooter(),
            child: SizedBox(
              height: 300,
              width: double.infinity,
              child: _isLoading ? _buildLoading() : _buildDefaultContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultContent() {
    return GestureDetector(
      onTap: _isLoading ? () {} : () => _startLivenessCheck(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.face, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 10),
            Text(
              'Click to Start liveness check',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        KYCButton(
          text: 'Go Back',
          variant: KYCButtonVariant.outline,
          onPressed: _isLoading ? () {} : (widget.onBack ?? () {}),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: KYCButton(
            text: _isLoading ? 'Creating session...' : 'Start liveness check',
            block: true,
            loading: _isLoading,
            onPressed: _isLoading ? () {} : () => _startLivenessCheck(),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Center(
      child: KYCSpinner(size: 32, text: 'Creating liveness session...'),
    );
  }
}
