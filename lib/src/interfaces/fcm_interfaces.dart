import '../models/index.dart';

/// FCM token işlemleri için interface
abstract class FcmTokenHandler {
  /// Token backend'e gönderildiğinde çağrılır (ilk token veya yenilenen token)
  Future<bool> onTokenReceived(String token, {String? userId});

  /// Token silinmesi gerektiğinde çağrılır (logout)
  Future<bool> onTokenDelete(String token);

  /// Token yenilendiğinde çağrılır (opsiyonel)
  /// Bu metod implement edilmezse onTokenReceived kullanılır
  Future<void> onTokenRefreshed(String oldToken, String newToken) async {
    // Default implementation - sadece yeni token'ı işle
    await onTokenReceived(newToken);
  }
}

/// FCM mesaj işlemleri için interface
abstract class FcmMessageHandler {
  /// Foreground mesaj geldiğinde çağrılır
  Future<void> onForegroundMessage(FcmMessage message);

  /// Bildirime tıklandığında çağrılır
  Future<void> onMessageTap(FcmMessage message);

  /// Uygulama bildirimle açıldığında çağrılır
  Future<void> onAppOpenedFromNotification(FcmMessage message);
}

/// FCM analytics için interface
abstract class FcmAnalyticsHandler {
  /// Bildirim eventi gönderildiğinde çağrılır
  Future<void> onNotificationEvent({required String eventType, required String messageId, Map<String, dynamic>? additionalData});
}

/// Notification preferences için interface
abstract class FcmPreferencesHandler {
  /// Notification preferences güncellendiğinde çağrılır
  Future<bool> onUpdatePreferences({required bool enabled, List<String>? categories, Map<String, bool>? channelSettings});
}

/// FCM topic management için interface
abstract class FcmTopicHandler {
  /// Topic'e abone olduğunda çağrılır
  /// 
  /// **Parameters:**
  /// - [topic]: Abone olunan topic adı
  /// - [success]: Abonelik işleminin başarı durumu
  /// 
  /// **Example:**
  /// ```dart
  /// @override
  /// Future<void> onTopicSubscribed(String topic, bool success) async {
  ///   if (success) {
  ///     // Backend'e kaydet, analytics gönder
  ///     await saveTopicSubscriptionToBackend(topic);
  ///   }
  /// }
  /// ```
  Future<void> onTopicSubscribed(String topic, bool success);

  /// Topic'ten abonelikten çıktığında çağrılır
  /// 
  /// **Parameters:**
  /// - [topic]: Abonelikten çıkılan topic adı
  /// - [success]: Abonelikten çıkma işleminin başarı durumu
  Future<void> onTopicUnsubscribed(String topic, bool success);

  /// Bulk topic işlemleri sonrasında çağrılır
  /// 
  /// **Parameters:**
  /// - [results]: Her topic için işlem sonuçları
  /// - [isSubscription]: true=abonelik, false=abonelikten çıkma
  Future<void> onBulkTopicOperation(Map<String, bool> results, bool isSubscription);
}
