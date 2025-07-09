import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const String kLocalLogoPath = 'assets/images/skaletek.png';

class KYCLogo extends StatelessWidget {
  final String? logoUrl;
  final double? width;
  final double? height;
  final String? fallbackText;

  const KYCLogo({
    super.key,
    this.logoUrl,
    this.width = 120,
    this.height = 30,
    this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    // If no custom logo URL provided, use local asset
    if (logoUrl == null || logoUrl!.isEmpty) {
      return _buildLocalLogo();
    }

    // Try to load custom logo from URL
    if (logoUrl!.toLowerCase().endsWith('.svg')) {
      return SizedBox(
        width: width,
        height: height,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SvgPicture.network(
            logoUrl!,
            fit: BoxFit.contain,
            placeholderBuilder: (context) => _buildLocalLogo(),
            width: width,
            height: height,
            errorBuilder: (context, error, stackTrace) => _buildLocalLogo(),
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,

      alignment: Alignment.centerLeft,
      child: Image.network(
        logoUrl!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildLocalLogo(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLocalLogo();
        },
      ),
    );
  }

  Widget _buildLocalLogo() {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.centerLeft,
      child: Image.asset(
        kLocalLogoPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildTextFallback(),
      ),
    );
  }

  Widget _buildTextFallback() {
    final displayText = fallbackText ?? 'Skaletek';
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Text(
          displayText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF126DD6),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
