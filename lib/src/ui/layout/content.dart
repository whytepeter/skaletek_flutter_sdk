import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_api_models.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_user_info.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/app_color.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/typography.dart';

class KYCContent extends StatelessWidget {
  final Widget? child;
  final Widget? footer;
  final KYCStep step;
  final KYCUserInfo? userInfo;

  const KYCContent({
    super.key,
    this.child,
    this.footer,
    required this.step,
    this.userInfo,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AppColor.lightBlue,
              boxShadow: [
                BoxShadow(
                  color: AppColor.lightBlue.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: Offset(0, 10),
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(children: [_buildHeader(), _buildContent()]),
          ),
          SizedBox(height: 16),
          footer ?? Container(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
            spreadRadius: 0,
          ),
        ],
      ),
      child: child ?? Container(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(14),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StyledTitle(
                step == KYCStep.document
                    ? _getGreetingText()
                    : 'Photosensitivity Warning',
              ),
              StyledText(
                step == KYCStep.document
                    ? 'Get ready to upload your ID'
                    : 'We will require you have a working camera.',
              ),
            ],
          ),
          Spacer(),
          Image.asset(
            step == KYCStep.document
                ? 'assets/images/fancy-arrow.png'
                : 'assets/images/fancy-arrow-2.png',
            width: 40,
          ),
        ],
      ),
    );
  }

  String _getGreetingText() {
    if (userInfo == null || userInfo!.firstName.isEmpty) {
      return 'Hey there!';
    }
    return 'Hey ${userInfo!.firstName} ${userInfo!.lastName}!';
  }
}
