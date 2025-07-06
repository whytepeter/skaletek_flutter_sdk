import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/typography.dart';

class KYCAlert extends StatelessWidget {
  final String title;
  final String description;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const KYCAlert({
    super.key,
    required this.title,
    required this.description,
    this.confirmText = 'OK',
    this.cancelText = 'Cancel',
    this.onConfirm,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: StyledHeading(title),
      content: StyledText(description),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.of(context).pop(false),
          child: StyledTitle(cancelText, style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
          child: StyledTitle(
            confirmText,
            style: TextStyle(color: Colors.red[700]),
          ),
        ),
      ],
    );
  }
}
