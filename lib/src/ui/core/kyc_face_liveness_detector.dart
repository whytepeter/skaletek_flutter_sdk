import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/services/kyc_service.dart';
import 'package:face_liveness_detector/face_liveness_detector.dart';

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
  final VoidCallback onComplete;
  final Function(String error) onError;

  @override
  State<KYCFaceLivenessDetector> createState() =>
      _KYCFaceLivenessDetectorState();
}

class _KYCFaceLivenessDetectorState extends State<KYCFaceLivenessDetector> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: FaceLivenessDetector(
        sessionId: widget.sessionId,
        region: widget.region,
        onComplete: widget.onComplete,
        onError: widget.onError,
      ),
    );
  }
}
