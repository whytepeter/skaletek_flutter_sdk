import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/services/kyc_service.dart';
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
  });

  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final KYCService kycService;

  @override
  State<KYCFaceVerification> createState() => _KYCFaceVerificationState();
}

class _KYCFaceVerificationState extends State<KYCFaceVerification> {
  bool _isLoading = false;
  String _sessionId = '';
  final String _region = 'us-east-1';
  bool _showLivenessDetector = false;
  bool _showResults = false;
  Map<String, dynamic> _results = {};

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

  void _onLivenessComplete(Map<String, dynamic> results) {
    setState(() {
      _results = results;
      _showResults = true;
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

  Widget _buildResultsView() {
    final isVerified = _results['verified'] == true;

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          KYCContent(
            footer: _buildResultsFooter(),
            child: Container(
              height: 300,
              width: double.infinity,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isVerified
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      color: isVerified ? Colors.green : Colors.red,
                      size: 80,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isVerified
                          ? 'Face liveness verified!'
                          : 'Face liveness failed',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    if (_results.containsKey('confidence')) ...[
                      Text(
                        'Confidence: ${(_results['confidence'] * 100).toStringAsFixed(2)}%',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsFooter() {
    final isVerified = _results['verified'] == true;

    return Row(
      children: [
        KYCButton(
          text: 'Try Again',
          variant: KYCButtonVariant.outline,
          onPressed: () {
            setState(() {
              _showResults = false;
              _results = {};
              _sessionId = '';
            });
          },
        ),
        const SizedBox(width: 16),
        Expanded(
          child: KYCButton(
            text: isVerified ? 'Continue' : 'Go Back',
            block: true,
            onPressed: isVerified
                ? (widget.onNext ?? () {})
                : (widget.onBack ?? () {}),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showLivenessDetector) {
      return KYCFaceLivenessDetector(
        sessionId: _sessionId,
        region: _region,
        kycService: widget.kycService,
        onComplete: _onLivenessComplete,
        onError: _onLivenessError,
      );
    }

    if (_showResults) {
      return _buildResultsView();
    }

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          KYCContent(
            footer: _buildFooter(),
            child: Container(
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
