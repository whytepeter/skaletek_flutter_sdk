import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/app_color.dart';

class StyledText extends StatelessWidget {
  const StyledText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        textStyle: Theme.of(context).textTheme.bodyMedium,
        fontSize: 14,
        color: AppColor.textLight,
      ).merge(style),
    );
  }
}

class StyledTitle extends StatelessWidget {
  const StyledTitle(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        textStyle: Theme.of(context).textTheme.titleMedium,
        fontSize: 16,
        color: AppColor.text,
      ).merge(style),
    );
  }
}

class StyledHeading extends StatelessWidget {
  const StyledHeading(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.poppins(
        textStyle: Theme.of(context).textTheme.headlineMedium,
        fontSize: 18,
        color: AppColor.text,
        fontWeight: FontWeight.w600,
      ).merge(style),
    );
  }
}
