/// Utility class for sanitizing user inputs to prevent XSS, script injection,
/// and improper formatting across the application.
class InputSanitizer {
  // Regex to match HTML and script tags
  static final RegExp _htmlTagsRegex = RegExp(r'<[^>]*>', multiLine: true);
  static final RegExp _scriptBlockRegex = RegExp(
    r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>',
    caseSensitive: false,
    multiLine: true,
  );
  static final RegExp _javascriptUriRegex = RegExp(
    r'javascript:',
    caseSensitive: false,
  );

  /// Sanitizes generic text input by trimming whitespace, stripping script blocks,
  /// removing HTML tags, and removing non-printable/null control characters.
  static String sanitize(String? input) {
    if (input == null) return '';
    String result = input;

    // 1. Remove script tags and contents
    result = result.replaceAll(_scriptBlockRegex, '');

    // 2. Remove javascript: pseudo-protocols
    result = result.replaceAll(_javascriptUriRegex, '');

    // 3. Remove all other HTML tags
    result = result.replaceAll(_htmlTagsRegex, '');

    // 4. Remove null bytes and non-standard control characters (keep \n and \t)
    result = result.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // 5. Trim leading/trailing whitespace
    return result.trim();
  }

  /// Sanitizes email inputs: trims whitespace, removes control chars, and converts to lowercase.
  static String sanitizeEmail(String? input) {
    if (input == null) return '';
    return sanitize(input).toLowerCase();
  }

  /// Sanitizes phone numbers: removes spaces, dashes, brackets, but retains leading + and digits.
  static String sanitizePhone(String? input) {
    if (input == null) return '';
    final trimmed = input.trim();
    final hasPlus = trimmed.startsWith('+');
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    return hasPlus ? '+$digitsOnly' : digitsOnly;
  }

  /// Sanitizes numeric strings: keeps only digits and at most one decimal point.
  static String sanitizeNumeric(String? input) {
    if (input == null) return '';
    final trimmed = input.trim();
    // Allow digits and single decimal dot
    final cleaned = trimmed.replaceAll(RegExp(r'[^\d.]'), '');
    final parts = cleaned.split('.');
    if (parts.length > 2) {
      return '${parts[0]}.${parts.sublist(1).join()}';
    }
    return cleaned;
  }
}
