import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/app_color.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/typography.dart';

class KycProgress extends StatelessWidget {
  final VoidCallback? onClose;
  final String title;
  final String message;

  const KycProgress({
    super.key,
    this.onClose,
    this.title = 'Progress',
    this.message = 'Verifying your identity...',
  });

  @override
  Widget build(BuildContext context) {
    Widget header() {
      return Padding(
        padding: EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColor.light),
                  ),
                ),
                icon: const Icon(Icons.close),
                onPressed: onClose ?? () => Navigator.of(context).maybePop(),
              ),
            ),
            Center(
              child: StyledTitle(title, style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 400),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColor.light, width: 1.5),
              ),
            ),
            child: header(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _AnimatedDots(),
                  SizedBox(height: 32),
                  StyledTitle(
                    'Verifying your identity...',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final List<Color> _dotColors = [
    AppColor.primary,
    AppColor.light,
    AppColor.dark,
    AppColor.primary,
    AppColor.light,
    AppColor.dark,
    AppColor.primary,
    AppColor.light,
    AppColor.dark,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 3x3 grid of animated dots cycling through primary, light, dark
    return SizedBox(
      width: 60,
      height: 60,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (j) {
                  final index = i * 3 + j;
                  final delay = index * 0.08;
                  final phase = ((t + delay) % 1.0);
                  Color color;
                  if (phase < 0.33) {
                    color = _dotColors[index];
                  } else if (phase < 0.66) {
                    color = _dotColors[(index + 1) % 9];
                  } else {
                    color = _dotColors[(index + 2) % 9];
                  }
                  return Container(
                    margin: const EdgeInsets.all(3),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              );
            }),
          );
        },
      ),
    );
  }
}
