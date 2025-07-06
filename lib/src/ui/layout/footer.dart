import 'package:flutter/material.dart';

class KYCFooter extends StatelessWidget {
  const KYCFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('© Skaletek', style: TextStyle(color: Colors.grey[600])),
          SizedBox(width: 10),
          Text('Privacy Policy', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
