import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:face_liveness_detector/face_liveness_detector.dart';
import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/config/app_config.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_api_models.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_user_info.dart';
import 'package:skaletek_kyc_flutter/src/services/kyc_service.dart';
import 'package:skaletek_kyc_flutter/src/ui/layout/content.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/button.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/spinner.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/kyc_progress.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_result.dart';

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
  bool _isVerifying = false;

  Future<void> _startLivenessCheck() async {
    setState(() {
      _isLoading = true;
    });

    // return _onLivenessComplete(); //this is for testing purposes

    try {
      final res = await widget.kycService.createSession();

      if (res != null) {
        safePrint(
          'Session created successfully, starting liveness detector...',
        );

        setState(() {
          _sessionId = res;
          _showLivenessDetector = true;
        });
      } else {
        safePrint('Session creation returned null');

        throw Exception('Failed to create liveness session');
      }
    } catch (e) {
      // Error will be handled by global error handler

      safePrint('Error creating session: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyIdentity() async {
    BuildContext? bottomSheetContext;
    // Show the progress bottom sheet
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bottomSheetContext = ctx;
        return KycProgress(onClose: () => Navigator.of(ctx).maybePop());
      },
    );

    try {
      String? result = await widget.kycService.verifyIdentity();
      if (result is! String) {
        throw Exception('Failed to verify identity, Please try again');
      }

      if (bottomSheetContext != null && bottomSheetContext!.mounted) {
        Navigator.of(bottomSheetContext!).pop(); // Close only the bottom sheet
      }
    } catch (e) {
      if (bottomSheetContext != null && bottomSheetContext!.mounted) {
        Navigator.of(
          bottomSheetContext!,
        ).pop(); // Close only the bottom sheet on error
      }
    }
  }

  void _onLivenessComplete() async {
    setState(() {
      _showLivenessDetector = false;
      _isVerifying = true;
    });

    // await _verifyIdentity();
    // widget.kycService.callOnComplete(
    //   KYCResult.success(status: KYCStatus.success),
    // );
    // return; //this is for testing purposes

    try {
      GetResultResponse result = await widget.kycService.getResult(_sessionId);
      if (result.isLive) {
        await _verifyIdentity();
        // Call the KYCService's onComplete callback after verification
        widget.kycService.callOnComplete(
          KYCResult.success(status: KYCStatus.success),
        );
      } else if (result.remainingTries > 0) {
        _startLivenessCheck();
      }
    } catch (e) {
      if (mounted) {
        // Check if the error has a redirect URL - only close flow if it does
        String? redirectUrl;
        if (e is SessionError) {
          redirectUrl = e.redirectUrl;
        }

        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          // Close the flow only if there's a redirect URL
          widget.kycService.callOnComplete(
            KYCResult.failure(status: KYCStatus.failure),
          );
        }
      }
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  void _onLivenessError(String error) {
    setState(() {
      _showLivenessDetector = false;
    });
    safePrint('Error: $error');
  }

  @override
  Widget build(BuildContext context) {
    if (_showLivenessDetector) {
      return SizedBox(
        height: MediaQuery.of(context).size.height - 120,
        child: FaceLivenessDetector(
          sessionId: _sessionId,
          region: AppConfig.region,
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
              child: _isLoading || _isVerifying
                  ? _buildLoading()
                  : _buildDefaultContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultContent() {
    return GestureDetector(
      onTap: _isLoading || _isVerifying ? () {} : () => _startLivenessCheck(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.face, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 10),
            Text(
              'Click to Start liveness check ',
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
          disabled: _isLoading || _isVerifying,
          onPressed: _isLoading || _isVerifying
              ? () {}
              : (widget.onBack ?? () {}),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: KYCButton(
            text: _isLoading ? 'Creating session...' : 'Start liveness check',
            block: true,
            loading: _isLoading || _isVerifying,
            onPressed: _isLoading || _isVerifying
                ? () {}
                : () => _startLivenessCheck(),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Center(
      child: KYCSpinner(
        size: 32,
        text: _isVerifying ? 'Verifying...' : 'Creating liveness session...',
      ),
    );
  }
}
