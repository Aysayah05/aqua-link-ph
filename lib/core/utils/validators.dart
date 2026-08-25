class Validators {
  Validators._();

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final RegExp regex = RegExp(r'^[\w\.\-+]+@([\w\-]+\.)+[a-zA-Z]{2,}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Contact number is required';
    final RegExp regex = RegExp(r'^(09|\+639)\d{9}$');
    final String digits = value.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!regex.hasMatch(digits)) return 'Enter a valid PH mobile number (09XXXXXXXXX)';
    return null;
  }

  static String? positiveNumber(String? value, {String field = 'Amount'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    final double? parsed = double.tryParse(value.replaceAll(',', ''));
    if (parsed == null) return 'Enter a valid number';
    if (parsed <= 0) return '$field must be greater than zero';
    return null;
  }

  static String? nonNegativeInt(String? value, {String field = 'Quantity'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    final int? parsed = int.tryParse(value);
    if (parsed == null) return 'Enter a valid whole number';
    if (parsed < 0) return '$field cannot be negative';
    return null;
  }
}
