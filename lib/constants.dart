import 'package:flutter/material.dart';

// === Brand Colors - CV Maju Bersama (Deep Blue Corporate) ===
const kPrimaryColor = Color(0xFF1E3A5F);       // Deep Navy Blue
const kPrimaryLightColor = Color(0xFFE8F0FB);  // Light Blue tint
const kAccentColor = Color(0xFF2979FF);        // Bright Blue accent
const kSuccessColor = Color(0xFF43A047);       // Green success
const kWarningColor = Color(0xFFFB8C00);       // Orange warning
const kDangerColor = Color(0xFFE53935);        // Red danger

const kPrimaryGradientColor = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1E3A5F), Color(0xFF2979FF)],
);

const kCardGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF2979FF), Color(0xFF1565C0)],
);

const kSecondaryColor = Color(0xFF6B7280);
const kTextColor = Color(0xFF1F2937);
const kSubtitleColor = Color(0xFF6B7280);
const kBackgroundColor = Color(0xFFF5F7FA);
const kCardColor = Colors.white;

const kAnimationDuration = Duration(milliseconds: 200);
const defaultDuration = Duration(milliseconds: 250);

// TextStyles
const headingStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: kTextColor,
  height: 1.5,
);

const subheadingStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: kTextColor,
);

const captionStyle = TextStyle(
  fontSize: 12,
  color: kSubtitleColor,
);

// Form
final RegExp emailValidatorRegExp =
    RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
const String kEmailNullError = "Harap masukkan email Anda";
const String kInvalidEmailError = "Email tidak valid";
const String kPassNullError = "Harap masukkan password Anda";
const String kShortPassError = "Password terlalu pendek";
const String kNamelNullError = "Harap masukkan nama Anda";
const String kPhoneNumberNullError = "Harap masukkan nomor HP";

OutlineInputBorder outlineInputBorder() {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
  );
}

OutlineInputBorder outlineInputBorderFocused() {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: kAccentColor, width: 2),
  );
}

// Legacy constants retained for backward compatibility with remaining old screens
const String kMatchPassError = "Passwords don't match";
const String kAddressNullError = "Harap masukkan alamat Anda";

final otpInputDecoration = InputDecoration(
  contentPadding: const EdgeInsets.symmetric(vertical: 16),
  border: outlineInputBorder(),
  focusedBorder: outlineInputBorder(),
  enabledBorder: outlineInputBorder(),
);
