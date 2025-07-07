import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skaletek_kyc_flutter/skaletek_kyc_flutter.dart';
import 'package:skaletek_kyc_flutter/src/ui/core/kyc_document_upload.dart';
import 'package:skaletek_kyc_flutter/src/ui/core/kyc_face_verification.dart';
import 'package:skaletek_kyc_flutter/src/ui/layout/body.dart';
import 'layout/header.dart';
import 'layout/footer.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/app_color.dart';
import 'package:skaletek_kyc_flutter/src/services/kyc_state_provider.dart';
import 'package:skaletek_kyc_flutter/src/services/kyc_service.dart';

enum KYCStep { document, liveness }

class KYCVerificationScreen extends StatefulWidget {
  final KYCConfig config;

  const KYCVerificationScreen({super.key, required this.config});

  @override
  State<KYCVerificationScreen> createState() => _KYCVerificationScreenState();
}

class _KYCVerificationScreenState extends State<KYCVerificationScreen> {
  KYCStep currentStep = KYCStep.document;
  final KYCService _kycService = KYCService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeService();
    });
  }

  Future<void> _initializeService() async {
    try {
      // Get the state provider from context
      final stateProvider = Provider.of<KYCStateProvider>(
        context,
        listen: false,
      );

      // Initialize service with state provider
      await _kycService.initialize(widget.config, stateProvider: stateProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error initializing: $e')));
      }
    }
  }

  void _goToNextStep() {
    if (currentStep == KYCStep.document) {
      setState(() {
        currentStep = KYCStep.liveness;
      });
    }
  }

  void _goToPreviousStep() {
    if (currentStep == KYCStep.liveness) {
      setState(() {
        currentStep = KYCStep.document;
      });
    }
  }

  Widget _getCurrentStepWidget() {
    switch (currentStep) {
      case KYCStep.document:
        return KYCDocumentUpload(onNext: _goToNextStep);
      case KYCStep.liveness:
        return KYCFaceVerification(
          onBack: _goToPreviousStep,
          onNext: _goToNextStep,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColor.init(widget.config.customization);

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: KYCHeader(
        logoUrl: widget.config.customization.logoUrl,
        onClose: () => Navigator.of(context).maybePop(),
      ),
      body: KYCBody(child: _getCurrentStepWidget()),
      bottomNavigationBar: KYCFooter(),
    );
  }
}
