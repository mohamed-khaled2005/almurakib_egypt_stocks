import 'package:dlibphonenumber/dlibphonenumber.dart';

class NormalizedPhoneNumber {
  const NormalizedPhoneNumber({
    required this.e164,
    required this.international,
    required this.national,
  });

  final String e164;
  final String international;
  final String national;
}

class PhoneNumberHelper {
  PhoneNumberHelper._();

  static final PhoneNumberUtil _phoneUtil = PhoneNumberUtil.instance;

  static bool isValidForCountryCode(String rawInput, String regionCode) {
    return tryNormalize(rawInput: rawInput, regionCode: regionCode) != null;
  }

  static NormalizedPhoneNumber? tryNormalize({
    required String rawInput,
    required String regionCode,
  }) {
    final input = rawInput.trim();
    final normalizedRegion = regionCode.trim().toUpperCase();

    if (input.isEmpty || normalizedRegion.isEmpty) {
      return null;
    }

    try {
      final parsed = _phoneUtil.parse(input, normalizedRegion);
      if (!_phoneUtil.isValidNumberForRegion(parsed, normalizedRegion)) {
        return null;
      }

      return NormalizedPhoneNumber(
        e164: _phoneUtil.format(parsed, PhoneNumberFormat.e164),
        international:
            _phoneUtil.format(parsed, PhoneNumberFormat.international),
        national: _phoneUtil.format(parsed, PhoneNumberFormat.national),
      );
    } on NumberParseException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
