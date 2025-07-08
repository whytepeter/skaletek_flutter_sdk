import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/app_color.dart';

class KYCSpinner extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final String? text;

  const KYCSpinner({
    super.key,
    this.size = 24.0,
    this.strokeWidth = 2.5,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(AppColor.primary),
          ),
        ),
        if (text != null) ...[
          SizedBox(height: 12),
          Text(
            text!,
            style: TextStyle(
              fontSize: 14,
              color: AppColor.text.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
