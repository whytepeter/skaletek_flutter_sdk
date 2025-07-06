import 'package:flutter/material.dart';

class KYCContent extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool isScrollable;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

  const KYCContent({
    super.key,
    required this.child,
    this.padding,
    this.isScrollable = true,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(24.0),
      child: child,
    );

    if (isScrollable) {
      return SingleChildScrollView(child: content);
    }

    return Expanded(child: content);
  }
}
