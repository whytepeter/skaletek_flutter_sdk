import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/typography.dart';

class KYCFooter extends StatelessWidget {
  const KYCFooter({super.key});

  @override
  Widget build(BuildContext context) {
    Widget footer = Container(
      padding: const EdgeInsets.all(10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StyledText(
            '© Skaletek',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          SizedBox(width: 10),
          StyledText(
            'Privacy Policy',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );

    return footer;
  }
}
