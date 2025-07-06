import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const String kSkaletekLogoUrl =
    'https://kyc.dev.skaletek.io/assets/skaletek_mobile-BsaITLA5.svg';

class KYCLogo extends StatelessWidget {
  final String? logoUrl;
  final double? width;
  final double? height;
  final String? fallbackText;

  const KYCLogo({
    super.key,
    this.logoUrl,
    this.width = 120,
    this.height = 40,
    this.fallbackText,
  });

  bool get _isSvg => (logoUrl ?? '').toLowerCase().endsWith('.svg');

  @override
  Widget build(BuildContext context) {
    if (logoUrl == null || logoUrl!.isEmpty) {
      return _buildSkaletekLogo();
    }
    if (_isSvg) {
      return SizedBox(
        width: width,
        height: height,
        child: SvgPicture.network(
          logoUrl!,
          fit: BoxFit.contain,
          placeholderBuilder: (context) => _buildLoadingLogo(),
          width: width,
          height: height,
          // If SVG fails, show Skaletek logo
          errorBuilder: (context, error, stackTrace) => _buildSkaletekLogo(),
        ),
      );
    }
    return Container(
      width: width,
      height: height,
      child: Image.network(
        logoUrl!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildSkaletekLogo();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingLogo();
        },
      ),
    );
  }

  Widget _buildSkaletekLogo() {
    return SizedBox(
      width: width,
      height: height,
      child: SvgPicture.network(
        kSkaletekLogoUrl,
        fit: BoxFit.contain,
        placeholderBuilder: (context) => _buildLoadingLogo(),
        width: width,
        height: height,
      ),
    );
  }

  Widget _buildLoadingLogo() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF126DD6)),
          ),
        ),
      ),
    );
  }
}
