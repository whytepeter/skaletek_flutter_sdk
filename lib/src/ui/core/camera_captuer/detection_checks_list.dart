import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_api_models.dart';

class DetectionChecksList extends StatelessWidget {
  final DetectionChecks detectionChecks;
  final double top;
  const DetectionChecksList({
    required this.detectionChecks,
    required this.top,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final checks = [
      ['darkness', detectionChecks.darkness],
      ['brightness', detectionChecks.brightness],
      ['blur', detectionChecks.blur],
      ['glare', detectionChecks.glare],
    ];
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: checks.map((entry) {
          final key = entry[0] as String;
          final value = entry[1] as DetectionCheckResult;
          String label;
          switch (value) {
            case DetectionCheckResult.fail:
              label = DetectionChecks.failLabels[key]!;
              break;
            case DetectionCheckResult.pass:
              label = DetectionChecks.labels[key]!;
              break;
            case DetectionCheckResult.none:
            default:
              label = DetectionChecks.labels[key]!;
              break;
          }
          return _DetectionCheckItem(label: label, result: value);
        }).toList(),
      ),
    );
  }
}

class _DetectionCheckItem extends StatelessWidget {
  final String label;
  final DetectionCheckResult result;
  const _DetectionCheckItem({required this.label, required this.result});

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.white.withValues(alpha: 0.85);
    Color textColor = const Color(0xFF222B45);
    Widget icon;
    switch (result) {
      case DetectionCheckResult.pass:
        icon = Icon(Icons.check_circle, color: Color(0xFF039754), size: 22);
        break;
      case DetectionCheckResult.fail:
        icon = Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFD92C20),
          size: 22,
        );
        break;
      case DetectionCheckResult.none:
      default:
        icon = Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Color(0xFFD9D9D9), width: 2),
          ),
        );
        break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
