import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/services/kyc_service.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/spinner.dart';
// import 'package:face_liveness_detector/face_liveness_detector.dart';

class KYCFaceLivenessDetector extends StatefulWidget {
  const KYCFaceLivenessDetector({
    super.key,
    required this.sessionId,
    required this.region,
    required this.kycService,
    required this.onComplete,
    required this.onError,
  });

  final String sessionId;
  final String region;
  final KYCService kycService;
  final Function(Map<String, dynamic> results) onComplete;
  final Function(String error) onError;

  @override
  State<KYCFaceLivenessDetector> createState() =>
      _KYCFaceLivenessDetectorState();
}

class _KYCFaceLivenessDetectorState extends State<KYCFaceLivenessDetector> {
  bool _isLoading = false;
  bool _showResults = false;
  Map<String, dynamic> _results = {};

  @override
  Widget build(BuildContext context) {
    if (_showResults) {
      return _buildResultsView();
    }

    if (_isLoading) {
      return _buildLoadingView();
    }

    return _buildLivenessDetectorView();
  }

  Widget _buildLivenessDetectorView() {
    return Center(child: Container(child: Text('Liveness detector')));

    // return SizedBox(
    //   width: double.infinity,
    //   height: double.infinity,
    //   child: FaceLivenessDetector(
    //     sessionId: widget.sessionId,
    //     region: widget.region,
    //     onComplete: _onLivenessComplete,
    //     onError: _onLivenessError,
    //   ),
    // );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [KYCSpinner(size: 32, text: 'Fetching liveness results...')],
      ),
    );
  }

  Widget _buildResultsView() {
    final isVerified = _results['verified'] == true;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isVerified ? Icons.check_circle_outline : Icons.error_outline,
            color: isVerified ? Colors.green : Colors.red,
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            isVerified ? 'Face liveness verified!' : 'Face liveness failed',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 40),
          if (_results.containsKey('confidence')) ...[
            Text(
              'Confidence: ${(_results['confidence'] * 100).toStringAsFixed(2)}%',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 10),
          ],
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showResults = false;
                _results = {};
              });
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Future<void> _onLivenessComplete() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the session token from the KYC service
      final sessionToken = await widget.kycService.getSessionToken();
      if (sessionToken == null) {
        throw Exception('No session token available');
      }

      // Fetch liveness results using the KYC service
      final result = await widget.kycService.getResult(
        livenessToken: widget.sessionId,
        sessionToken: sessionToken,
      );

      final results = {
        'verified': result.isLive,
        'confidence':
            0.95, // Default confidence since KYC service doesn't provide it
        'redirectUrl': result.redirectUrl,
        'remainingTries': result.remainingTries,
        'selfieName': result.selfieName,
      };

      setState(() {
        _results = results;
        _showResults = true;
        _isLoading = false;
      });

      // Call the onComplete callback
      widget.onComplete(results);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      widget.onError('Failed to fetch liveness results: $e');
    }
  }

  void _onLivenessError(String code) {
    widget.onError('Liveness check failed: $code');
  }
}
