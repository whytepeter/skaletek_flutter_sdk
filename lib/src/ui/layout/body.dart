import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/ui/layout/footer.dart';

class KYCBody extends StatelessWidget {
  const KYCBody({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        // make container fill the entire body
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/pattern.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Expanded(child: child ?? Container()),
            KYCFooter(),
          ],
        ),
      ),
    );
  }
}
