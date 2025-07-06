import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/skaletek_kyc_flutter.dart';
import 'layout/header.dart';
import 'layout/content.dart';
import 'layout/footer.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/app_color.dart';

class KYCVerificationScreen extends StatefulWidget {
  final KYCConfig config;

  const KYCVerificationScreen({super.key, required this.config});

  @override
  State<KYCVerificationScreen> createState() => _KYCVerificationScreenState();
}

class _KYCVerificationScreenState extends State<KYCVerificationScreen> {
  @override
  Widget build(BuildContext context) {
    AppColor.init(widget.config.customization);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: KYCHeader(
        logoUrl: widget.config.customization.logoUrl,
        onClose: () => Navigator.of(context).maybePop(),
      ),
      body: SingleChildScrollView(child: Placeholder()),
      bottomNavigationBar: KYCFooter(),
    );
  }
}
