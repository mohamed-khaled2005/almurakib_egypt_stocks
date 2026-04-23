class ManagedAppUser {
  const ManagedAppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.countryCode,
    required this.countryName,
    required this.phoneNumber,
    required this.tradingStatus,
    required this.status,
    required this.authProvider,
    required this.hasPassword,
    required this.createdAt,
    required this.lastLoginAt,
  });

  final int id;
  final String email;
  final String? fullName;
  final String? countryCode;
  final String? countryName;
  final String? phoneNumber;
  final String? tradingStatus;
  final String status;
  final String authProvider;
  final bool hasPassword;
  final String? createdAt;
  final String? lastLoginAt;

  factory ManagedAppUser.fromJson(Map<String, dynamic> json) {
    return ManagedAppUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: (json['email'] ?? '').toString(),
      fullName: json['full_name']?.toString(),
      countryCode: json['country_code']?.toString(),
      countryName: json['country_name']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      tradingStatus: json['trading_status']?.toString(),
      status: (json['status'] ?? 'active').toString(),
      authProvider: (json['auth_provider'] ?? 'password').toString(),
      hasPassword: json['has_password'] == true,
      createdAt: json['created_at']?.toString(),
      lastLoginAt: json['last_login_at']?.toString(),
    );
  }

  bool get hasCountry {
    return (countryCode ?? '').trim().isNotEmpty &&
        (countryName ?? '').trim().isNotEmpty;
  }

  bool get hasPhoneNumber {
    return (phoneNumber ?? '').trim().isNotEmpty;
  }

  bool get hasTradingStatus {
    return (tradingStatus ?? '').trim().isNotEmpty;
  }

  DateTime? get createdAtDateTime {
    final raw = (createdAt ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(raw);
    return parsed?.toLocal();
  }

  String get displayName {
    final normalized = _normalizeName(fullName);
    if (normalized != null) {
      return normalized;
    }

    final localPart = email.split('@').first.trim();
    final fallback = localPart
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return fallback.isNotEmpty ? fallback : email;
  }

  static String? _normalizeName(String? rawValue) {
    final normalized = (rawValue ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return null;
    }

    final meaningful =
        normalized.replaceAll(RegExp(r'[\p{P}\p{S}\s]+', unicode: true), '');
    if (meaningful.isEmpty) {
      return null;
    }

    return normalized;
  }
}
