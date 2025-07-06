import 'package:flutter/material.dart';

class KYCDocumentScanner extends StatelessWidget {
  final String? logoUrl;
  final String? partnerName;
  final String? partnerPhone;
  final String? partnerEmail;
  final String? helpUrl;
  final VoidCallback? onBack;
  final VoidCallback? onDocumentDetected;
  final VoidCallback? onManualCapture;
  final bool isScanning;
  final String? documentType;

  const KYCDocumentScanner({
    super.key,
    this.logoUrl,
    this.partnerName,
    this.partnerPhone,
    this.partnerEmail,
    this.helpUrl,
    this.onBack,
    this.onDocumentDetected,
    this.onManualCapture,
    this.isScanning = false,
    this.documentType,
  });

  @override
  Widget build(BuildContext context) {
    return Placeholder();
  }
}
