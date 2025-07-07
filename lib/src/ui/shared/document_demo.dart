import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skaletek_kyc_flutter/src/services/kyc_state_provider.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/app_color.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/button.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/typography.dart';

class KYCDocumentDemo extends StatelessWidget {
  final VoidCallback? onContinue;

  const KYCDocumentDemo({super.key, this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Consumer<KYCStateProvider>(
      builder: (context, stateProvider, child) {
        // Don't show if user has already seen it
        if (stateProvider.hasSeenDocumentDemo) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColor.lightBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColor.lightBlue.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: AppColor.primary, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StyledText(
                      'Document Upload Demo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColor.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StyledText(
                'This is a demo of how to upload your documents. Make sure your document is:\n'
                '• Clear and well-lit\n'
                '• Not blurry or damaged\n'
                '• Fully visible in the frame\n'
                '• Original document (not a copy)',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColor.text.withValues(alpha: 0.8),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: KYCButton(
                      text: 'Got it!',
                      onPressed: () async {
                        await stateProvider.markDocumentDemoAsSeen();
                        onContinue?.call();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
