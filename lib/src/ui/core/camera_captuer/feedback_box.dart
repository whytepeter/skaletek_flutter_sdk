import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/ui/core/camera_captuer/camera_service.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/typography.dart';

class FeedbackBox extends StatelessWidget {
  final FeedbackState feedbackState;
  final String feedbackText;
  const FeedbackBox({
    required this.feedbackState,
    required this.feedbackText,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    switch (feedbackState) {
      case FeedbackState.error:
        bgColor = const Color(0xFFFEF3F2); // light red
        textColor = const Color(0xFFD92C20); // red
        break;
      case FeedbackState.success:
        bgColor = const Color(0xFFECFDF3); // light green
        textColor = const Color(0xFF039754); // green
        break;
      case FeedbackState.info:
      default:
        bgColor = Colors.white;
        textColor = Color(0xFF126DD6);
        break;
    }
    return Positioned(
      top: 100,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: StyledText(
          feedbackText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
