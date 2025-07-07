import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/ui/layout/content.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/button.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/document_demo.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/dos_and_donts.dart';

class KYCDocumentUpload extends StatelessWidget {
  const KYCDocumentUpload({super.key, this.onNext});
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: KYCContent(
        footer: KYCButton(
          text: 'Continue',
          block: true,
          onPressed: onNext ?? () {},
        ),
        child: Column(
          children: [
            // Main content area
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Placeholder(
                    fallbackHeight: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_file,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Tap to upload your document',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
