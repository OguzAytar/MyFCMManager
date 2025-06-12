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

  // RemoteMessage'dan FcmMessage'a dönüştürme
  FcmMessage _toFcmMessage(RemoteMessage message) {
    return FcmMessage(title: message.notification?.title, body: message.notification?.body, data: message.data);
  }
}
