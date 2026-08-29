import 'input_sanitizer.dart';

/// Centralized validator utility for form inputs across the application.
class FormValidators {
  static final RegExp _emailRegex = RegExp(
    r'^(?!.*\.\.)[a-zA-Z0-9._%+-]+@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$',
  );

  static final RegExp _ghanaPhoneRegex = RegExp(
    r'^(?:\+233|0)[235][0-9]{8}$',
  );

  /// Validates email address format.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter valid email';
    }
    final trimmed = value.trim();
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Enter valid email';
    }
    return null;
  }

  /// Validates Ghanaian mobile phone numbers (+233 or local 02X/03X/05X prefixes).
  static String? validateGhanaPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter phone number';
    }
    final sanitized = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!_ghanaPhoneRegex.hasMatch(sanitized)) {
      return 'Enter valid Ghana phone (e.g. +233 24 123 4567 or 0241234567)';
    }
    return null;
  }

  /// Validates pay rate amounts (positive numeric values within realistic limits).
  static String? validatePayRate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter pay';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed.isNaN || !parsed.isFinite) {
      return 'Enter a valid numeric amount';
    }
    if (parsed <= 0) {
      return 'Pay amount must be greater than 0';
    }
    if (parsed > 100000) {
      return 'Pay amount exceeds maximum allowable limit';
    }
    return null;
  }

  /// Validates that a required field is not empty and satisfies length constraints.
  static String? validateRequired(
    String? value,
    String fieldName, {
    int minLength = 1,
    int maxLength = 1000,
  }) {
    if (value == null || value.trim().isEmpty) {
      final lower = fieldName.toLowerCase();
      if (lower.contains('title')) {
        return 'Please enter a title';
      }
      if (lower.contains('description')) {
        return 'Please enter job description';
      }
      if (lower.contains('location')) {
        return 'Please specify location';
      }
      if (lower.contains('name')) {
        return 'Enter full name';
      }
      return '$fieldName is required';
    }

    final trimmed = value.trim();
    if (trimmed.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    if (trimmed.length > maxLength) {
      return '$fieldName must not exceed $maxLength characters';
    }
    return null;
  }

  /// Validates user password length and non-whitespace constraints.
  static String? validatePassword(String? value) {
    if (value == null || value.length < 6) {
      return 'Password must be at least 6 chars';
    }
    if (value.trim().isEmpty) {
      return 'Password cannot be only whitespace';
    }
    if (value.length > 128) {
      return 'Password must not exceed 128 characters';
    }
    return null;
  }

  /// Convenience wrapper around [InputSanitizer.sanitize].
  static String sanitizeText(String text) {
    return InputSanitizer.sanitize(text);
  }
}
