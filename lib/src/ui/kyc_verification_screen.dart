import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skaletek_kyc_flutter/skaletek_kyc_flutter.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_api_models.dart';
import 'package:skaletek_kyc_flutter/src/ui/core/kyc_document_upload.dart';
import 'package:skaletek_kyc_flutter/src/ui/core/kyc_face_verification.dart';
import 'package:skaletek_kyc_flutter/src/ui/layout/body.dart';
import 'layout/header.dart';
import 'layout/footer.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/app_color.dart';
import 'package:skaletek_kyc_flutter/src/services/kyc_state_provider.dart';
import 'package:skaletek_kyc_flutter/src/services/kyc_service.dart';

class KYCVerificationScreen extends StatefulWidget {
  final KYCConfig config;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final Function(bool success, Map<String, dynamic> data)? onComplete;

  const KYCVerificationScreen({
    super.key,
    required this.config,
    this.onNext,
    this.onBack,
    this.onComplete,
  });

  @override
  State<KYCVerificationScreen> createState() => _KYCVerificationScreenState();
}

class _KYCVerificationScreenState extends State<KYCVerificationScreen> {
  KYCStep currentStep = KYCStep.document;
  final KYCService _kycService = KYCService();
  final ScrollController _scrollController = ScrollController();
  bool _showBlur = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeService();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final showBlur = _scrollController.offset > 0;
    if (showBlur != _showBlur) {
      setState(() {
        _showBlur = showBlur;
      });
    }
  }

  Future<void> _initializeService() async {
    try {
      // Get the state provider from context
      final stateProvider = Provider.of<KYCStateProvider>(
        context,
        listen: false,
      );

      // Initialize service with state provider and error handlers
      await _kycService.initialize(
        widget.config,
        stateProvider: stateProvider,
        onComplete: widget.onComplete,
        onError: () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
        onShowSnackbar: (String message) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  message,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                backgroundColor: AppColor.error,
                duration: Duration(seconds: 4),
              ),
            );
          }
        },
      );
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
        return KYCDocumentUpload(
          onNext: _goToNextStep,
          kycService: _kycService,
          userInfo: widget.config.userInfo,
        );
      case KYCStep.liveness:
        return KYCFaceVerification(
          onBack: _goToPreviousStep,
          onNext: _goToNextStep,
          kycService: _kycService,
          userInfo: widget.config.userInfo,
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
      body: KYCBody(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: _getCurrentStepWidget(),
        ),
      ),
      bottomNavigationBar: KYCFooter(),
    );
  }
}
