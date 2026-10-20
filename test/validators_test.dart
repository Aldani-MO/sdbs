import 'package:flutter_test/flutter_test.dart';
import 'package:sdbs/utils/validators.dart';

/// Unit tests for the Validators utility class
/// Tests email, phone, password, and numeric validation logic
/// Imports the REAL Validators class from the project

void main() {
  group('Validators - Required Field', () {
    test('Should return error when value is null', () {
      expect(Validators.required(null, 'Name'), equals('Name is required'));
    });

    test('Should return error when value is empty', () {
      expect(Validators.required('', 'Name'), equals('Name is required'));
    });

    test('Should return error when value is whitespace only', () {
      expect(Validators.required('   ', 'Name'), equals('Name is required'));
    });

    test('Should return null for valid input', () {
      expect(Validators.required('John', 'Name'), isNull);
    });
  });

  group('Validators - Email', () {
    test('Should return error for null email', () {
      expect(Validators.email(null), isNotNull);
    });

    test('Should return error for empty email', () {
      expect(Validators.email(''), equals('Email is required'));
    });

    test('Should return error for email without @', () {
      expect(Validators.email('userexample.com'), equals('Invalid email address'));
    });

    test('Should return error for email without domain', () {
      expect(Validators.email('user@'), equals('Invalid email address'));
    });

    test('Should return error for email with spaces', () {
      expect(Validators.email('user @example.com'), equals('Invalid email address'));
    });

    test('Should accept valid email', () {
      expect(Validators.email('user@example.com'), isNull);
    });

    test('Should accept email with dots', () {
      expect(Validators.email('first.last@example.com'), isNull);
    });

    test('Should accept email with subdomain', () {
      expect(Validators.email('user@mail.example.com'), isNull);
    });
  });

  group('Validators - Jordan Phone Number', () {
    test('Should return error for null phone', () {
      expect(Validators.jordanPhone(null), isNotNull);
    });

    test('Should return error for empty phone', () {
      expect(Validators.jordanPhone(''), isNotNull);
    });

    test('Should accept valid 079 number', () {
      expect(Validators.jordanPhone('0791234567'), isNull);
    });

    test('Should accept valid 078 number', () {
      expect(Validators.jordanPhone('0781234567'), isNull);
    });

    test('Should accept valid 077 number', () {
      expect(Validators.jordanPhone('0771234567'), isNull);
    });

    test('Should accept valid 075 number', () {
      expect(Validators.jordanPhone('0751234567'), isNull);
    });

    test('Should reject 076 number (invalid prefix)', () {
      expect(Validators.jordanPhone('0761234567'), isNotNull);
    });

    test('Should reject number with wrong length', () {
      expect(Validators.jordanPhone('079123456'), isNotNull);
    });

    test('Should reject number without 07 prefix', () {
      expect(Validators.jordanPhone('0691234567'), isNotNull);
    });

    test('Should accept +962 international format', () {
      expect(Validators.jordanPhone('+962791234567'), isNull);
    });
  });

  group('Validators - Password', () {
    test('Should return error for null password', () {
      expect(Validators.password(null), isNotNull);
    });

    test('Should return error for empty password', () {
      expect(Validators.password(''), isNotNull);
    });

    test('Should return error for short password (< 8 chars)', () {
      expect(Validators.password('Ab1!'), equals('Minimum 8 characters'));
    });

    test('Should return error for password without uppercase', () {
      expect(Validators.password('abcdefg1!'), equals('At least one capital letter'));
    });

    test('Should return error for password without number', () {
      expect(Validators.password('Abcdefgh!'), equals('At least one digit'));
    });

    test('Should return error for password without special character', () {
      expect(Validators.password('Abcdefg1'), equals('At least one special character'));
    });

    test('Should accept valid password', () {
      expect(Validators.password('Secure1!'), isNull);
    });

    test('Should accept complex valid password', () {
      expect(Validators.password('MyP@ssw0rd!'), isNull);
    });
  });

  group('Validators - Confirm Password', () {
    test('Should return error when passwords do not match', () {
      expect(Validators.confirmPassword('abc', 'xyz'), equals('Passwords do not match'));
    });

    test('Should return null when passwords match', () {
      expect(Validators.confirmPassword('Secure1!', 'Secure1!'), isNull);
    });
  });

  group('Validators - Numeric', () {
    test('Should return error for null value', () {
      expect(Validators.numeric(null, 'Latitude'), isNotNull);
    });

    test('Should return error for empty value', () {
      expect(Validators.numeric('', 'Latitude'), isNotNull);
    });

    test('Should return error for non-numeric value', () {
      expect(Validators.numeric('abc', 'Latitude'), equals('Latitude must be a number'));
    });

    test('Should accept integer string', () {
      expect(Validators.numeric('42', 'Latitude'), isNull);
    });

    test('Should accept decimal string', () {
      expect(Validators.numeric('31.9539', 'Latitude'), isNull);
    });

    test('Should accept negative number', () {
      expect(Validators.numeric('-5.5', 'Longitude'), isNull);
    });
  });
}
