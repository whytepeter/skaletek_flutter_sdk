import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/ui/layout/content.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/button.dart';

class KYCFaceVerification extends StatelessWidget {
  const KYCFaceVerification({super.key, this.onBack, this.onNext});

  final VoidCallback? onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          KYCContent(
            footer: Row(
              children: [
                KYCButton(
                  text: 'Go Back',
                  variant: KYCButtonVariant.outline,
                  onPressed: onBack ?? () {},
                ),
                SizedBox(width: 16),
                Expanded(
                  child: KYCButton(
                    text: 'Start liveness check',
                    block: true,
                    onPressed: onNext ?? () {},
                  ),
                ),
              ],
            ),
            child: SizedBox(height: 300, width: double.infinity),
          ),
        ],
      ),
    );
  }
}
