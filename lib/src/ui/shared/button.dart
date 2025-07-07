import 'package:flutter/material.dart';
import 'app_color.dart';

/// Button variants for KYCButton.
enum KYCButtonVariant { fill, outline }

/// A customizable button for KYC flows.
///
/// - By default, fits its content.
/// - Use [block] for full-width.
/// - Use [disabled] to disable the button.
/// - Use [loading] for a loading spinner.
class KYCButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool loading;
  final bool disabled;
  final KYCButtonVariant variant;
  final double? width;
  final double height;
  final bool block;

  const KYCButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.disabled = false,
    this.variant = KYCButtonVariant.fill,
    this.width,
    this.height = 56,
    this.block = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOutline = variant == KYCButtonVariant.outline;
    final Color backgroundColor = isOutline ? Colors.white : AppColor.primary;
    final Color borderColor = isOutline ? AppColor.light : AppColor.dark;
    final Color textColor = isOutline ? AppColor.text : Colors.white;

    Color resolveBg(Set<WidgetState> states) =>
        states.contains(WidgetState.disabled)
        ? backgroundColor.withValues(alpha: 0.5)
        : backgroundColor;

    Color resolveFg(Set<WidgetState> states) =>
        states.contains(WidgetState.disabled)
        ? textColor.withValues(alpha: 0.8)
        : textColor;

    BorderSide resolveSide(Set<WidgetState> states) {
      final color = borderColor;
      final fadedColor = states.contains(WidgetState.disabled)
          ? color.withValues(alpha: 0.3)
          : color;
      return BorderSide(color: fadedColor, width: 1);
    }

    final ButtonStyle style = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(resolveBg),
      foregroundColor: WidgetStateProperty.resolveWith(resolveFg),
      surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
      side: WidgetStateProperty.resolveWith(resolveSide),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      minimumSize: WidgetStateProperty.all(
        Size(block ? double.infinity : 0, height),
      ),
      elevation: WidgetStateProperty.all(0),
    );

    final Widget child = loading
        ? Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0,
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  strokeWidth: 2.5,
                ),
              ),
            ],
          )
        : Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          );

    Widget buttonWidget = isOutline
        ? OutlinedButton(
            onPressed: (loading || disabled) ? null : onPressed,
            style: style,
            child: child,
          )
        : ElevatedButton(
            onPressed: (loading || disabled) ? null : onPressed,
            style: style,
            child: child,
          );

    if (width != null && !block) {
      buttonWidget = SizedBox(
        width: width,
        height: height,
        child: buttonWidget,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D101828),
            offset: Offset(0, 1),
            blurRadius: 2,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: buttonWidget,
    );
  }
}
