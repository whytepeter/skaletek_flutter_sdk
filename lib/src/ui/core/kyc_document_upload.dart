import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/button.dart';

class KYCDocumentUpload extends StatelessWidget {
  const KYCDocumentUpload({super.key, this.onNext});
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: KYCButton(
        loading: true,
        text: 'Start liveness check',
        onPressed: () {},
      ),
    );
  }
}
