/// Модели ответов API авторизации (backend/apps/accounts/serializers.py).
class User {
  const User({
    required this.id,
    required this.email,
    required this.emailVerified,
    required this.displayName,
    required this.firstName,
    required this.leaderboardOptIn,
    this.founderNumber,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    email: json['email'] as String,
    emailVerified: json['email_verified'] as bool? ?? false,
    displayName: json['display_name'] as String,
    firstName: json['first_name'] as String? ?? '',
    leaderboardOptIn: json['leaderboard_opt_in'] as bool? ?? false,
    founderNumber: json['founder_number'] as int?,
  );

  final String id;
  final String email;
  final bool emailVerified;
  final String displayName;
  final String firstName;
  final bool leaderboardOptIn;
  final int? founderNumber;
}

class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.platform,
    required this.deviceName,
    required this.createdAt,
    required this.lastUsedAt,
    required this.isCurrent,
  });

  factory DeviceSession.fromJson(Map<String, dynamic> json) => DeviceSession(
    id: json['id'] as String,
    platform: json['platform'] as String,
    deviceName: json['device_name'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
    lastUsedAt: DateTime.parse(json['last_used_at'] as String),
    isCurrent: json['is_current'] as bool? ?? false,
  );

  final String id;
  final String platform;
  final String deviceName;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final bool isCurrent;
}

/// Устройство, с которого входят: попадает в список сессий. Модель телефона не собираем.
class DeviceInfo {
  const DeviceInfo({required this.platform, required this.appVersion});

  final String platform;
  final String appVersion;

  String get deviceName => platform == 'ios' ? 'iPhone' : 'Android';

  Map<String, String> toJson() => {'platform': platform, 'device_name': deviceName, 'app_version': appVersion};
}

/// Документы, на которые даётся согласие при регистрации (версии — из `GET app/config`).
abstract final class LegalDocument {
  static const pdProcessing = 'pd_processing';
  static const terms = 'terms';
  static const privacyPolicy = 'privacy_policy';
}
