import 'package:flutter/material.dart';
import '../shared/logo.dart';

const String kDefaultLogoUrl =
    'https://kyc.dev.skaletek.io/assets/skaletek_mobile-BsaITLA5.svg';

class KYCHeader extends StatelessWidget implements PreferredSizeWidget {
  final String? logoUrl;
  final VoidCallback? onClose;
  final List<Widget>? actions;

  const KYCHeader({super.key, this.logoUrl, this.onClose, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.grey[100],
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          KYCLogo(logoUrl: logoUrl ?? kDefaultLogoUrl, width: 100, height: 30),
          const Spacer(),
        ],
      ),
      actions: [
        if (actions != null) ...actions!,
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF181A34), size: 28),
            onPressed: onClose ?? () => Navigator.of(context).maybePop(),
            splashRadius: 24,
            tooltip: 'Close',
          ),
        ),
      ],
    );
  }
}
