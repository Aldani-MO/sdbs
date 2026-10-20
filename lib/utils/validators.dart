/// Centralized input validation for the SDBS application.
/// Replaces inline RegExp checks scattered across signup / login / admin forms.
class Validators {
  Validators._(); // prevent instantiation

  /// Validates that a field is not empty.
  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates a well-formed email address.
  static String? email(String? value) {
    final base = required(value, 'Email');
    if (base != null) return base;
    if (!RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$')
        .hasMatch(value!.trim())) {
      return 'Invalid email address';
    }
    return null;
  }

  /// Validates a Jordan mobile number (07X or +9627X format).
  static String? jordanPhone(String? value) {
    final base = required(value, 'Phone');
    if (base != null) return base;
    if (!RegExp(r'^(07[5789]\d{7}|\+9627[5789]\d{7})$')
        .hasMatch(value!.trim())) {
      return 'Invalid Jordan mobile number';
    }
    return null;
  }

  /// Validates password strength:
  /// - Minimum 8 characters
  /// - At least one uppercase letter
  /// - At least one digit
  /// - At least one special character
  static String? password(String? value) {
    final base = required(value, 'Password');
    if (base != null) return base;
    if (value!.length < 8) return 'Minimum 8 characters';
    if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
      return 'At least one capital letter';
    }
    if (!RegExp(r'(?=.*[0-9])').hasMatch(value)) {
      return 'At least one digit';
    }
    if (!RegExp(r'(?=.*[!@#$%^&*(),.?":{}|<>])').hasMatch(value)) {
      return 'At least one special character';
    }
    return null;
  }

  /// Validates that two password fields match.
  static String? confirmPassword(String? value, String original) {
    if (value != original) return 'Passwords do not match';
    return null;
  }

  /// Validates a numeric value (used for thresholds, coordinates, etc.).
  static String? numeric(String? value, [String fieldName = 'This field']) {
    final base = required(value, fieldName);
    if (base != null) return base;
    if (double.tryParse(value!.trim()) == null) {
      return '$fieldName must be a number';
    }
    return null;
  }

  /// Validates a positive integer ≥ 1 (used for thresholds, capacities).
  static String? positiveInt(String? value, [String fieldName = 'This field']) {
    final base = required(value, fieldName);
    if (base != null) return base;
    final parsed = int.tryParse(value!.trim());
    if (parsed == null) return '$fieldName must be a whole number';
    if (parsed < 1) return '$fieldName must be at least 1';
    return null;
  }

  /// Validates latitude (-90 to 90).
  static String? latitude(String? value) {
    final base = numeric(value, 'Latitude');
    if (base != null) return base;
    final lat = double.parse(value!.trim());
    if (lat < -90 || lat > 90) return 'Latitude must be between -90 and 90';
    return null;
  }

  /// Validates longitude (-180 to 180).
  static String? longitude(String? value) {
    final base = numeric(value, 'Longitude');
    if (base != null) return base;
    final lng = double.parse(value!.trim());
    if (lng < -180 || lng > 180) return 'Longitude must be between -180 and 180';
    return null;
  }
}
