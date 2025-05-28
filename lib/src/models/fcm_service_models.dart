/// FCM'den gelen bildirim verisi için generic model
class FcmMessage {
  final String? title;
  final String? body;
  final Map<String, dynamic>? data;

  FcmMessage({this.title, this.body, this.data});

  /// JSON'dan FcmMessage oluşturur
  factory FcmMessage.fromJson(Map<String, dynamic> json) {
    return FcmMessage(title: json['title'] as String?, body: json['body'] as String?, data: json['data'] as Map<String, dynamic>?);
  }

  /// FcmMessage'ı JSON'a çevirir
  Map<String, dynamic> toJson() {
    return {'title': title, 'body': body, 'data': data};
  }

  /// Message ID'yi data'dan alır
  String? get messageId => data?['messageId'] as String?;

  /// Route bilgisini data'dan alır
  String? get route => data?['route'] as String?;

  /// Screen bilgisini data'dan alır
  String? get screen => data?['screen'] as String?;

  /// Action bilgisini data'dan alır
  String? get action => data?['action'] as String?;

  /// Priority bilgisini data'dan alır
  String get priority => data?['priority'] as String? ?? 'normal';

  /// Category bilgisini data'dan alır
  String? get category => data?['category'] as String?;

  /// Deep link URL'ini data'dan alır
  String? get deepLink => data?['deep_link'] as String?;

  @override
  String toString() {
    return 'FcmMessage(title: $title, body: $body, data: $data)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FcmMessage && other.title == title && other.body == body && other.data.toString() == data.toString();
  }

  @override
  int get hashCode => Object.hash(title, body, data);
}

/// FCM bildirim izin ayarları için generic model
class FcmNotificationSettings {
  final bool alert;
  final bool badge;
  final bool sound;
  final bool provisional;
  final bool announcement;

  FcmNotificationSettings({required this.alert, required this.badge, required this.sound, required this.provisional, required this.announcement});

  /// JSON'dan FcmNotificationSettings oluşturur
  factory FcmNotificationSettings.fromJson(Map<String, dynamic> json) {
    return FcmNotificationSettings(
      alert: json['alert'] as bool? ?? false,
      badge: json['badge'] as bool? ?? false,
      sound: json['sound'] as bool? ?? false,
      provisional: json['provisional'] as bool? ?? false,
      announcement: json['announcement'] as bool? ?? false,
    );
  }

  /// FcmNotificationSettings'i JSON'a çevirir
  Map<String, dynamic> toJson() {
    return {'alert': alert, 'badge': badge, 'sound': sound, 'provisional': provisional, 'announcement': announcement};
  }

  /// Tüm izinlerin verilip verilmediğini kontrol eder
  bool get hasAllPermissions => alert && badge && sound;

  /// Hiç izin verilmediğini kontrol eder
  bool get hasNoPermissions => !alert && !badge && !sound;

  @override
  String toString() {
    return 'FcmNotificationSettings(alert: $alert, badge: $badge, sound: $sound, provisional: $provisional, announcement: $announcement)';
  }
}

/// Notification preferences modeli
class NotificationPreferences {
  final bool enabled;
  final List<String> categories;
  final Map<String, bool> channelSettings;
  final DateTime updatedAt;

  NotificationPreferences({required this.enabled, required this.categories, required this.channelSettings, required this.updatedAt});

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      enabled: json['enabled'] as bool? ?? true,
      categories: List<String>.from(json['categories'] as List? ?? []),
      channelSettings: Map<String, bool>.from(json['channel_settings'] as Map? ?? {}),
      updatedAt: DateTime.parse(json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {'enabled': enabled, 'categories': categories, 'channel_settings': channelSettings, 'updated_at': updatedAt.toIso8601String()};
  }
}

/// Analytics event modeli
class NotificationEvent {
  final String eventType;
  final String messageId;
  final DateTime timestamp;
  final String platform;
  final Map<String, dynamic>? additionalData;

  NotificationEvent({required this.eventType, required this.messageId, required this.timestamp, required this.platform, this.additionalData});

  factory NotificationEvent.fromJson(Map<String, dynamic> json) {
    return NotificationEvent(
      eventType: json['event_type'] as String,
      messageId: json['message_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      platform: json['platform'] as String,
      additionalData: json['additional_data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'message_id': messageId,
      'timestamp': timestamp.toIso8601String(),
      'platform': platform,
      if (additionalData != null) 'additional_data': additionalData,
    };
  }
}
