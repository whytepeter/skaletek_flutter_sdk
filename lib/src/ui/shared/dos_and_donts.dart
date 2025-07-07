import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skaletek_kyc_flutter/src/services/kyc_state_provider.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/app_color.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/button.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/typography.dart';

class KYCDosAndDonts extends StatelessWidget {
  final List<String> dos;
  final List<String> donts;
  final String? title;
  final VoidCallback? onContinue;

  const KYCDosAndDonts({
    super.key,
    required this.dos,
    required this.donts,
    this.title,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<KYCStateProvider>(
      builder: (context, stateProvider, child) {
        // Don't show if user has already seen it
        if (stateProvider.hasSeenDosAndDonts) {
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
              if (title != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: AppColor.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StyledText(
                        title!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColor.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildSection(
                      title: 'Do',
                      items: dos,
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSection(
                      title: "Don't",
                      items: donts,
                      icon: Icons.cancel,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: KYCButton(
                      text: 'Got it!',
                      onPressed: () async {
                        await stateProvider.markDosAndDontsAsSeen();
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

  Widget _buildSection({
    required String title,
    required List<String> items,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            StyledText(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon == Icons.check_circle ? Icons.check : Icons.close,
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StyledText(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColor.text.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
