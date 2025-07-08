import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/app_color.dart';

class KYCContent extends StatelessWidget {
  final Widget? child;
  final Widget? footer;

  const KYCContent({super.key, this.child, this.footer});

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
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

    Widget header = Padding(
      padding: EdgeInsets.all(14),
      child: Row(children: [Text('Hey David Omale!')]),
    );

    return SizedBox(
      child: Expanded(
        child: SingleChildScrollView(
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
                child: Column(children: [header, content]),
              ),
              SizedBox(height: 16),
              footer ?? Container(),
            ],
          ),
        ),
      ),
    );
  }
}
