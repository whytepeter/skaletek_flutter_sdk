import 'package:flutter/material.dart';
import '../../models/kyc_customization.dart';

class AppColor {
  static Color primary = const Color(0xFF126DD6);
  static Color light = _lighten(const Color(0xFF126DD6), 0.25);
  static Color dark = _darken(const Color(0xFF126DD6), 0.05);
  static Color text = const Color(0xFF202939);
  static Color textLight = const Color(0xFF4B5565);
  static Color lightBlue = const Color(0xFFEEF2F6);

  static void init(KYCCustomization customization, {Color? fallback}) {
    final hex = customization.primaryColor;
    Color base;
    if (hex != null && hex.isNotEmpty) {
      try {
        base = Color(int.parse(hex.replaceAll('#', '0xFF')));
      } catch (_) {
        base = fallback ?? const Color(0xFF126DD6);
      }
    } else {
      base = fallback ?? const Color(0xFF126DD6);
    }
    primary = base;
    light = _lighten(base, 0.25);
    dark = _darken(base, 0.05);
  }

  static AppColor fromCustomization(
    KYCCustomization customization, {
    Color? fallback,
  }) {
    final hex = customization.primaryColor;
    Color base;
    if (hex != null && hex.isNotEmpty) {
      try {
        base = Color(int.parse(hex.replaceAll('#', '0xFF')));
      } catch (_) {
        base = fallback ?? const Color(0xFF126DD6);
      }
    } else {
      base = fallback ?? const Color(0xFF126DD6);
    }
    final appColor = AppColor._internal(base);
    return appColor;
  }

  final Color _primary;
  final Color _light;
  final Color _dark;

  AppColor._internal(Color base)
    : _primary = base,
      _light = _lighten(base, 0.25),
      _dark = _darken(base, 0.05);

  Color get getPrimary => _primary;
  Color get getLight => _light;
  Color get getDark => _dark;

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness(0.95);
    return hslLight.toColor();
  }

  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

extension AppColorExtension on KYCCustomization {
  AppColor get appColor => AppColor.fromCustomization(this);
}
