import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/button.dart';

class KYCFaceVerification extends StatelessWidget {
  const KYCFaceVerification({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        KYCButton(
          text: 'Go back',
          variant: KYCButtonVariant.outline,
          onPressed: () {},
        ),
        SizedBox(width: 16),

        Expanded(
          child: KYCButton(
            loading: true,
            text: 'Start liveness check',
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}
