import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:ogzfirebasemanager/src/models/index.dart';

/// Katmanlı mimariye uygun, generic FCM servis katmanı
class FcmService {
  /// Singleton tasarım deseni ile tekil örnek oluşturma
  factory FcmService() => _instance;
  FcmService._internal();
  static final FcmService _instance = FcmService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  // Topic subscription tracking için local cache
  final Set<String> _subscribedTopics = <String>{};

  // Foreground bildirimleri için stream controller
  final StreamController<FcmMessage> _onMessageController = StreamController.broadcast();

  /// Foreground bildirimlerini dinlemek için stream controller
  Stream<FcmMessage> get onMessage => _onMessageController.stream;

  // Token değişimlerini dinlemek için stream controller
  final StreamController<String> _onTokenRefreshController = StreamController.broadcast();

  /// Token değişimlerini dinlemek için stream controller
  Stream<String> get onTokenRefresh => _onTokenRefreshController.stream;

  /// FCM token'ını alır ve döndürür
  Future<String?> getToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      return token;
    } catch (e) {
      return null;
    }
  }

  /// Bildirim izinlerini ister (iOS/Android)
  Future<FcmNotificationSettings> requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission();
    return FcmNotificationSettings(
      alert: settings.alert is bool ? settings.alert as bool : false,
      badge: settings.badge is bool ? settings.badge as bool : false,
      sound: settings.sound is bool ? settings.sound as bool : false,
      provisional: false, // NotificationSettings içinde yoksa false
      announcement: settings.announcement is bool ? settings.announcement as bool : false,
    );
  }

  /// FCM servis dinleyicilerini başlatır
  void initialize() {
    // Foreground bildirimleri
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _onMessageController.add(_toFcmMessage(message));
    });

    // Bildirim tıklama (uygulama açık/arka planda)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (onNotificationTap != null) {
        onNotificationTap!(_toFcmMessage(message));
      }
    });

    // Token yenileme
    _firebaseMessaging.onTokenRefresh.listen(_onTokenRefreshController.add);
  }

  /// Bildirim tıklama callback'i (opsiyonel)
  void Function(FcmMessage message)? onNotificationTap;

  /// Uygulama background/terminated iken bildirime tıklanıp açılırsa ilk mesajı getirir
  Future<FcmMessage?> getInitialMessage() async {
    final msg = await _firebaseMessaging.getInitialMessage();
    return msg == null ? null : _toFcmMessage(msg);
  }

  /// Temizlik (stream controller kapatma)
  void dispose() {
    _onMessageController.close();
    _onTokenRefreshController.close();
  }

  /// FCM token'ını siler (logout için)
  Future<void> deleteToken() async {
    try {
      await _firebaseMessaging.deleteToken();
    } catch (e) {
      // Token silme hatası - sessizce devam et
    }
  }

  /// Bir topic'e abone ol
  /// 
  /// **Parameters:**
  /// - [topic]: Abone olunacak topic adı
  /// 
  /// **Returns:**
  /// true - Başarılı, false - Hatalı
  /// 
  /// **Example:**
  /// ```dart
  /// await fcmService.subscribeToTopic('news');
  /// await fcmService.subscribeToTopic('weather-alerts');
  /// ```
  Future<bool> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      _subscribedTopics.add(topic);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Bir topic'den abonelikten çık
  /// 
  /// **Parameters:**
  /// - [topic]: Abonelikten çıkılacak topic adı
  /// 
  /// **Returns:**
  /// true - Başarılı, false - Hatalı
  /// 
  /// **Example:**
  /// ```dart
  /// await fcmService.unsubscribeFromTopic('news');
  /// ```
  Future<bool> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      _subscribedTopics.remove(topic);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Bir topic'e abone olup olmadığını kontrol eder (local cache)
  /// 
  /// **Parameters:**
  /// - [topic]: Kontrol edilecek topic adı
  /// 
  /// **Returns:**
  /// true - Abone, false - Abone değil
  /// 
  /// **Note:**
  /// Bu metod local cache'i kontrol eder. Firebase'den gerçek zamanlı 
  /// subscription durumu almaz çünkü Firebase böyle bir API sağlamaz.
  /// 
  /// **Example:**
  /// ```dart
  /// final isSubscribed = fcmService.isSubscribedToTopic('news');
  /// if (isSubscribed) {
  ///   print('News topic\'ine abone');
  /// }
  /// ```
  bool isSubscribedToTopic(String topic) {
    return _subscribedTopics.contains(topic);
  }

  /// Tüm abone olunan topic'leri getirir (local cache)
  /// 
  /// **Returns:**
  /// Set<String> - Abone olunan topic'lerin seti
  /// 
  /// **Example:**
  /// ```dart
  /// final topics = fcmService.getAllSubscribedTopics();
  /// print('Abone olunan topic\'ler: $topics');
  /// ```
  Set<String> getAllSubscribedTopics() {
    return Set<String>.from(_subscribedTopics);
  }

  /// Belirli topic'lere abone olup olmadığını kontrol eder
  /// 
  /// **Parameters:**
  /// - [topics]: Kontrol edilecek topic listesi
  /// 
  /// **Returns:**
  /// Map<String, bool> - Her topic için subscription durumu
  /// 
  /// **Example:**
  /// ```dart
  /// final statuses = fcmService.getTopicSubscriptionStatuses([
  ///   'news', 'sports', 'weather'
  /// ]);
  /// // {'news': true, 'sports': false, 'weather': true}
  /// ```
  Map<String, bool> getTopicSubscriptionStatuses(List<String> topics) {
    final Map<String, bool> statuses = {};
    for (final topic in topics) {
      statuses[topic] = isSubscribedToTopic(topic);
    }
    return statuses;
  }

  /// Topic cache'ini temizler (logout için)
  /// 
  /// **Example:**
  /// ```dart
  /// fcmService.clearTopicCache();
  /// ```
  void clearTopicCache() {
    _subscribedTopics.clear();
  }

  /// Birden fazla topic'e aynı anda abone ol
  /// 
  /// **Parameters:**
  /// - [topics]: Abone olunacak topic listesi
  /// 
  /// **Returns:**
  /// Map<String, bool> - Her topic için başarı durumu
  /// 
  /// **Example:**
  /// ```dart
  /// final results = await fcmService.subscribeToMultipleTopics([
  ///   'news', 'sports', 'weather'
  /// ]);
  /// ```
  Future<Map<String, bool>> subscribeToMultipleTopics(List<String> topics) async {
    final Map<String, bool> results = {};
    
    for (final topic in topics) {
      results[topic] = await subscribeToTopic(topic);
    }
    
    return results;
  }

  /// Birden fazla topic'ten aynı anda abonelikten çık
  /// 
  /// **Parameters:**
  /// - [topics]: Abonelikten çıkılacak topic listesi
  /// 
  /// **Returns:**
  /// Map<String, bool> - Her topic için başarı durumu
  Future<Map<String, bool>> unsubscribeFromMultipleTopics(List<String> topics) async {
    final Map<String, bool> results = {};
    
    for (final topic in topics) {
      results[topic] = await unsubscribeFromTopic(topic);
    }
    
    return results;
  }

  // RemoteMessage'dan FcmMessage'a dönüştürme
  FcmMessage _toFcmMessage(RemoteMessage message) {
    return FcmMessage(title: message.notification?.title, body: message.notification?.body, data: message.data);
  }
}
