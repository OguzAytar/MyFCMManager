import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ogzfirebasemanager/src/interfaces/index.dart';
import 'package:ogzfirebasemanager/src/models/index.dart';
import 'package:ogzfirebasemanager/src/service/index.dart';

/// Firebase Cloud Messaging (FCM) servisini yöneten merkezi sınıf
///
/// Bu sınıf FCM ile ilgili tüm işlemleri merkezi olarak yönetir ve
/// interface-based architecture kullanarak esnek bir yapı sunar.
///
/// **Ana Özellikler:**
/// - Token yönetimi ve değişim takibi
/// - Foreground/Background bildirim işleme
/// - Analytics event takibi
/// - Notification preferences yönetimi
/// - Interface tabanlı genişletilebilir yapı
///
/// **Kullanım:**
/// ```dart
/// // Initialize FCM Manager with handlers
/// await FcmManager().initialize(
///   tokenHandler: MyTokenHandler(),
///   messageHandler: MyMessageHandler(),
///   analyticsHandler: MyAnalyticsHandler(),
///   preferencesHandler: MyPreferencesHandler(),
/// );
///
/// // Listen to token changes
/// FcmManager().onTokenRefresh.listen((token) {
///   print('New token: $token');
/// });
/// ```
///
/// **Singleton Pattern:**
/// Bu sınıf singleton pattern kullanır, yani uygulama boyunca
/// tek bir instance'ı bulunur ve FcmManager() ile erişilir.
class FcmManager {
  /// Singleton instance'ı
  /// Bu sınıfın tek bir instance'ının olmasını sağlar
  static final FcmManager _instance = FcmManager._internal();

  /// Factory constructor - her çağrıldığında aynı instance'ı döner
  factory FcmManager() => _instance;

  /// Private constructor - sadece içeriden çağrılabilir
  FcmManager._internal();

  // FCM dinleyicileri için subscription'lar
  /// FCM token değişikliklerini dinleyen subscription
  /// Token her değiştiğinde tetiklenir (örn: app restore, token refresh)
  StreamSubscription<String>? _tokenSub;

  /// Foreground (uygulama açıkken) gelen bildirimleri dinleyen subscription
  /// Sadece uygulama açıkken gelen bildirimler için tetiklenir
  StreamSubscription<FcmMessage>? _fcmForegroundSub;

  // Services
  /// FCM servisinin ana implementasyonu
  /// Firebase Messaging ile doğrudan iletişim kurar
  final _fcmService = FcmService();

  // Handler'lar (kullanıcı tarafından implement edilecek)
  /// Token işlemleri için kullanıcı tarafından implement edilen handler
  /// Token alındığında, yenilendiğinde veya silindiğinde çağrılır
  FcmTokenHandler? _tokenHandler;

  /// Mesaj işlemleri için kullanıcı tarafından implement edilen handler
  /// Foreground mesaj, tap, app açılma durumlarında çağrılır
  FcmMessageHandler? _messageHandler;

  /// Analytics işlemleri için kullanıcı tarafından implement edilen handler
  /// Bildirim eventleri (alındı, tıklandı, açıldı) için çağrılır
  FcmAnalyticsHandler? _analyticsHandler;

  /// Notification ayarları için kullanıcı tarafından implement edilen handler
  /// Kullanıcı bildirim tercihlerini güncellemek için kullanılır
  FcmPreferencesHandler? _preferencesHandler;

  // Callback fonksiyonları (basit kullanım için)
  /// Basit kullanım için bildirime tıklama callback'i
  /// Interface kullanmak istemeyenler için alternatif yöntem
  void Function(FcmMessage)? _onNotificationTap;

  // Token caching
  /// Mevcut FCM token'ını cache'ler
  /// Token değişikliklerini karşılaştırmak için kullanılır
  String? _currentToken;

  /// FCM servisini başlatır ve gerekli dinleyicileri kurar
  ///
  /// Bu metod FCM servisini başlatır ve kullanıcı tarafından sağlanan
  /// handler'ları kaydeder. Ayrıca token değişimi ve mesaj dinleyicilerini kurar.
  ///
  /// **Parametreler:**
  /// - [tokenHandler]: Token işlemleri için handler (opsiyonel)
  /// - [messageHandler]: Mesaj işlemleri için handler (opsiyonel)
  /// - [analyticsHandler]: Analytics eventi için handler (opsiyonel)
  /// - [preferencesHandler]: Notification preferences için handler (opsiyonel)
  /// - [onNotificationTap]: Basit bildirim tıklama callback'i (opsiyonel)
  ///
  /// **Throws:**
  /// Firebase initialization hatalarını fırlatabilir
  ///
  /// **Example:**
  /// ```dart
  /// await FcmManager().initialize(
  ///   tokenHandler: MyTokenHandler(),
  ///   messageHandler: MyMessageHandler(),
  ///   onNotificationTap: (message) => print('Tapped: ${message.title}'),
  /// );
  /// ```
  Future<void> initialize({
    FcmTokenHandler? tokenHandler,
    FcmMessageHandler? messageHandler,
    FcmAnalyticsHandler? analyticsHandler,
    FcmPreferencesHandler? preferencesHandler,
    void Function(FcmMessage message)? onNotificationTap,
  }) async {
    // Handler'ları kaydet
    _tokenHandler = tokenHandler;
    _messageHandler = messageHandler;
    _analyticsHandler = analyticsHandler;
    _preferencesHandler = preferencesHandler;
    _onNotificationTap = onNotificationTap;

    // FCM servisini başlat
    _fcmService.initialize();

    // Token değişimi dinleniyor
    _tokenSub = _fcmService.onTokenRefresh.listen(_handleTokenRefresh);

    // Foreground (uygulama açıkken) bildirimleri dinle
    _fcmForegroundSub = _fcmService.onMessage.listen(_handleForegroundMessage);

    // Bildirime tıklama handler'ını ayarla
    _fcmService.onNotificationTap = _handleNotificationTap;

    // Bildirime tıklayarak açıldıysa kontrol
    await _handleInitialMessage();

    // İlk token'ı işle
    final initialToken = await getToken();
    if (initialToken != null) {
      log(initialToken);
      await _handleTokenRefresh(initialToken);
    }
  }

  /// FCM kaynaklarını temizler ve dinleyicileri iptal eder
  ///
  /// Bu metod uygulama kapanırken veya FCM servisini durdurmak
  /// istediğinizde çağrılmalıdır. Tüm stream subscription'ları
  /// iptal eder ve bellek sızıntılarını önler.
  ///
  /// **Example:**
  /// ```dart
  /// @override
  /// void dispose() {
  ///   FcmManager().dispose();
  ///   super.dispose();
  /// }
  /// ```
  void dispose() {
    _tokenSub?.cancel();
    _fcmForegroundSub?.cancel();
    _fcmService.dispose();
  }

  /// Token refresh handler - internal use
  ///
  /// FCM token değiştiğinde otomatik olarak çağrılır.
  /// Eski token ile yeni token'ı karşılaştırır ve uygun handler metodunu çağırır.
  ///
  /// **Behavior:**
  /// - İlk token alımında: onTokenReceived çağrılır
  /// - Token değişiminde: onTokenRefreshed çağrılır
  /// - Aynı token gelirse: onTokenReceived çağrılır
  ///
  /// **Parameters:**
  /// - [token]: Yeni FCM token'ı
  Future<void> _handleTokenRefresh(String token) async {
    try {
      debugPrint('🔄 FCM Token güncellendi: ${token.substring(0, 20)}...');

      final oldToken = _currentToken;
      _currentToken = token;

      if (_tokenHandler != null) {
        // Eğer eski token varsa onTokenRefreshed'i çağır
        if (oldToken != null && oldToken != token) {
          await _tokenHandler!.onTokenRefreshed(oldToken, token);
        } else {
          // İlk token veya aynı token ise onTokenReceived'i çağır
          await _tokenHandler!.onTokenReceived(token);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Foreground mesaj handler - internal use
  ///
  /// Uygulama açıkken gelen FCM mesajlarını işler.
  /// Message handler ve analytics handler'ı çağırır.
  ///
  /// **Parameters:**
  /// - [message]: Gelen FCM mesajı
  ///
  /// **Analytics Event:**
  /// - Event Type: 'received'
  /// - Additional Data: foreground=true, title
  Future<void> _handleForegroundMessage(FcmMessage message) async {
    try {
      debugPrint('📱 Foreground FCM mesajı alındı: ${message.title}');

      if (_messageHandler != null) {
        await _messageHandler!.onForegroundMessage(message);
      }

      // Analytics event gönder
      if (_analyticsHandler != null) {
        await _analyticsHandler!.onNotificationEvent(
          eventType: 'received',
          messageId: message.data?['messageId'] ?? 'unknown',
          additionalData: {'foreground': true, 'title': message.title},
        );
      }
    } catch (e) {
      debugPrint('❌ Foreground message handler hatası: $e');
    }
  }

  /// Bildirime tıklama handler - internal use
  ///
  /// Kullanıcı bir bildirime tıkladığında çağrılır.
  /// Hem callback hem de message handler'ı çağırır.
  ///
  /// **Parameters:**
  /// - [message]: Tıklanan bildirim mesajı
  ///
  /// **Behavior:**
  /// 1. Simple callback çağrılır (varsa)
  /// 2. Message handler'ın onMessageTap metodu çağrılır
  /// 3. Analytics event gönderilir
  ///
  /// **Analytics Event:**
  /// - Event Type: 'tapped'
  /// - Additional Data: title
  Future<void> _handleNotificationTap(FcmMessage message) async {
    try {
      debugPrint('👆 Bildirime tıklandı: ${message.title}');

      // Callback varsa çağır
      if (_onNotificationTap != null) {
        _onNotificationTap!(message);
      }

      // Message handler varsa çağır
      if (_messageHandler != null) {
        await _messageHandler!.onMessageTap(message);
      }

      // Analytics event gönder
      if (_analyticsHandler != null) {
        await _analyticsHandler!.onNotificationEvent(
          eventType: 'tapped',
          messageId: message.data?['messageId'] ?? 'unknown',
          additionalData: {'title': message.title},
        );
      }
    } catch (e) {
      debugPrint('❌ Notification tap handler hatası: $e');
    }
  }

  /// Initial message handler - internal use
  ///
  /// Uygulama kapalıyken gelen bir bildirime tıklanarak açıldığında çağrılır.
  /// Bu durumda özel bir işlem yapılması gerekebilir (deep linking, özel sayfa açma vb.)
  ///
  /// **Behavior:**
  /// 1. Firebase'den initial message kontrol edilir
  /// 2. Varsa messageHandler'ın onAppOpenedFromNotification metodu çağrılır
  /// 3. Analytics event gönderilir
  ///
  /// **Analytics Event:**
  /// - Event Type: 'app_opened'
  /// - Additional Data: title
  ///
  /// **Use Case:**
  /// Kullanıcı bildirime tıklayarak uygulamayı açtığında
  /// genellikle belirli bir sayfaya yönlendirilmek istenir.
  Future<void> _handleInitialMessage() async {
    try {
      final initialMsg = await _fcmService.getInitialMessage();
      if (initialMsg != null) {
        debugPrint('🚀 Uygulama bildirimle açıldı');

        if (_messageHandler != null) {
          await _messageHandler!.onAppOpenedFromNotification(initialMsg);
        }

        // Analytics event gönder
        if (_analyticsHandler != null) {
          await _analyticsHandler!.onNotificationEvent(
            eventType: 'app_opened',
            messageId: initialMsg.data?['messageId'] ?? 'unknown',
            additionalData: {'title': initialMsg.title},
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Initial message handler hatası: $e');
    }
  }

  /// FCM token'ını Firebase'den alır
  ///
  /// Bu metod Firebase'den mevcut FCM token'ını getirir.
  /// Token push notification gönderebilmek için gereklidir.
  ///
  /// **Returns:**
  /// FCM token string'i veya null (token henüz oluşmadıysa)
  ///
  /// **Example:**
  /// ```dart
  /// final token = await FcmManager().getToken();
  /// if (token != null) {
  ///   print('FCM Token: $token');
  ///   // Token'ı backend'e gönder
  /// }
  /// ```
  Future<String?> getToken() async {
    return await _fcmService.getToken();
  }

  /// Token değişikliklerini dinleyen Stream
  ///
  /// FCM token'ları zaman zaman değişebilir (app restore, refresh vb.).
  /// Bu stream kullanılarak token değişimleri dinlenebilir.
  ///
  /// **Returns:**
  /// Token değişikliklerini yayınlayan Stream<String>
  ///
  /// **Example:**
  /// ```dart
  /// FcmManager().onTokenRefresh.listen((newToken) {
  ///   print('Token değişti: $newToken');
  ///   // Yeni token'ı backend'e gönder
  /// });
  /// ```
  Stream<String> get onTokenRefresh => _fcmService.onTokenRefresh;

  /// Foreground mesajları dinleyen Stream
  ///
  /// Uygulama açıkken gelen FCM mesajlarını dinlemek için kullanılır.
  /// Bu stream sadece uygulama foreground'dayken tetiklenir.
  ///
  /// **Returns:**
  /// Foreground mesajları yayınlayan Stream<FcmMessage>
  ///
  /// **Example:**
  /// ```dart
  /// FcmManager().onMessage.listen((message) {
  ///   print('Foreground mesaj: ${message.title}');
  ///   // Kendi local notification'ınızı gösterin
  /// });
  /// ```
  Stream<FcmMessage> get onMessage => _fcmService.onMessage;

  /// Bildirim tıklama callback'ini ayarlar
  ///
  /// Interface kullanmak istemeyenler için basit bir alternatif yöntem.
  /// Kullanıcı bir bildirime tıkladığında bu callback çağrılır.
  ///
  /// **Parameters:**
  /// - [callback]: Bildirim tıklandığında çağrılacak fonksiyon
  ///
  /// **Note:**
  /// Bu basit kullanım içindir. Daha gelişmiş kullanım için
  /// FcmMessageHandler interface'ini implement etmeniz önerilir.
  ///
  /// **Example:**
  /// ```dart
  /// FcmManager().onNotificationTap = (message) {
  ///   print('Bildirime tıklandı: ${message.title}');
  ///   // Gerekli navigation işlemlerini yapın
  /// };
  /// ```
  set onNotificationTap(void Function(FcmMessage) callback) {
    _onNotificationTap = callback;
  }

  /// FCM bildirim izinlerini kullanıcıdan ister
  ///
  /// iOS ve Android'de bildirim gönderebilmek için kullanıcının
  /// izin vermesi gerekir. Bu metod izin dialog'unu gösterir.
  ///
  /// **Returns:**
  /// [FcmNotificationSettings] - İzin durumu ve detaylarını içeren nesne
  ///
  /// **Platform Differences:**
  /// - **iOS**: İzin dialog'u gösterilir, kullanıcı kabul/red edebilir
  /// - **Android**: API 33+ için izin dialog'u, altında otomatik kabul
  ///
  /// **Example:**
  /// ```dart
  /// final settings = await FcmManager().requestPermission();
  /// if (settings.authorizationStatus == AuthorizationStatus.authorized) {
  ///   print('Bildirim izni verildi');
  /// } else {
  ///   print('Bildirim izni reddedildi');
  /// }
  /// ```
  ///
  /// **Best Practice:**
  /// Bu metodu uygulama başlangıcında veya kullanıcı bildirim
  /// ayarlarına eriştiğinde çağırın.
  Future<FcmNotificationSettings> requestPermission() async {
    return await _fcmService.requestPermission();
  }

  /// Kullanıcı logout işlemi ve token silme
  ///
  /// Kullanıcı logout olduğunda FCM token'ını backend'den silmek
  /// için kullanılır. Bu sayede logout olan kullanıcıya bildirim gönderilmez.
  ///
  /// **Process:**
  /// 1. Mevcut FCM token'ı alınır
  /// 2. TokenHandler'ın onTokenDelete metodu çağrılır
  /// 3. Backend'den token silme işlemi yapılır
  ///
  /// **Returns:**
  /// `true` - Token başarıyla silindi
  /// `false` - Token silinemedi veya token handler yok
  ///
  /// **Example:**
  /// ```dart
  /// final success = await FcmManager().logout();
  /// if (success) {
  ///   print('Logout başarılı, artık bildirim alamayacak');
  ///   // Login sayfasına yönlendir
  /// } else {
  ///   print('Logout işleminde hata oluştu');
  /// }
  /// ```
  ///
  /// **Important:**
  /// Token handler implement edilmemişse bu metod false döner.
  /// Backend'e token silme isteği gönderebilmek için FcmTokenHandler
  /// interface'ini implement etmelisiniz.
  Future<bool> logout() async {
    try {
      final token = await getToken();
      if (token != null && _tokenHandler != null) {
        final success = await _tokenHandler!.onTokenDelete(token);
        if (success) {
          debugPrint('✅ Logout başarılı, token silindi');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Logout hatası: $e');
      return false;
    }
  }

  /// Kullanıcı bildirim tercihlerini günceller
  ///
  /// Kullanıcının bildirim ayarlarını (açık/kapalı, kategoriler, kanal ayarları)
  /// güncellemek için kullanılır. Bu ayarlar backend'e kaydedilir.
  ///
  /// **Parameters:**
  /// - [enabled]: Bildirimlerin genel olarak açık/kapalı durumu
  /// - [categories]: Kullanıcının abone olduğu bildirim kategorileri (opsiyonel)
  /// - [channelSettings]: Kanal bazlı bildirim ayarları (opsiyonel)
  ///
  /// **Returns:**
  /// `true` - Ayarlar başarıyla güncellendi
  /// `false` - Güncelleme başarısız veya preferences handler yok
  ///
  /// **Example:**
  /// ```dart
  /// // Tüm bildirimleri kapat
  /// await FcmManager().updateNotificationPreferences(enabled: false);
  ///
  /// // Sadece belirli kategorileri aç
  /// await FcmManager().updateNotificationPreferences(
  ///   enabled: true,
  ///   categories: ['news', 'promotions'],
  ///   channelSettings: {
  ///     'urgent': true,
  ///     'marketing': false,
  ///   },
  /// );
  /// ```
  ///
  /// **Use Case:**
  /// Kullanıcı ayarlar sayfasında bildirim tercihlerini değiştirdiğinde
  /// bu metod çağrılarak backend'e güncel ayarlar gönderilir.
  ///
  /// **Note:**
  /// Preferences handler implement edilmemişse bu metod false döner.
  Future<bool> updateNotificationPreferences({required bool enabled, List<String>? categories, Map<String, bool>? channelSettings}) async {
    try {
      if (_preferencesHandler != null) {
        return await _preferencesHandler!.onUpdatePreferences(enabled: enabled, categories: categories, channelSettings: channelSettings);
      }
      return false;
    } catch (e) {
      debugPrint('❌ Preferences update hatası: $e');
      return false;
    }
  }

  /// Custom analytics eventi gönderir
  ///
  /// FCM ile ilgili özel analytics eventleri göndermek için kullanılır.
  /// Bu metod analytics handler üzerinden custom event'ler göndermenizi sağlar.
  ///
  /// **Parameters:**
  /// - [eventType]: Event'in tipi (örn: 'custom_action', 'special_notification')
  /// - [messageId]: İlgili mesaj ID'si
  /// - [additionalData]: Ek data (opsiyonel)
  ///
  /// **Common Event Types:**
  /// - `'received'` - Bildirim alındı
  /// - `'tapped'` - Bildirime tıklandı
  /// - `'dismissed'` - Bildirim kapatıldı
  /// - `'app_opened'` - Bildirimle uygulama açıldı
  /// - `'custom_action'` - Özel aksiyon
  ///
  /// **Example:**
  /// ```dart
  /// // Özel bir bildirim aksiyonu
  /// await FcmManager().sendAnalyticsEvent(
  ///   eventType: 'button_clicked',
  ///   messageId: 'msg_123',
  ///   additionalData: {
  ///     'button_type': 'cta',
  ///     'campaign_id': 'summer_2024',
  ///     'user_segment': 'premium'
  ///   },
  /// );
  ///
  /// // Bildirim dismiss edildi
  /// await FcmManager().sendAnalyticsEvent(
  ///   eventType: 'dismissed',
  ///   messageId: 'msg_456',
  /// );
  /// ```
  ///
  /// **Analytics Integration:**
  /// Bu metod Firebase Analytics, Mixpanel, Amplitude gibi analytics
  /// servislerine event göndermek için kullanılabilir.
  ///
  /// **Note:**
  /// Analytics handler implement edilmemişse bu metod sessizce başarısız olur.
  Future<void> sendAnalyticsEvent({required String eventType, required String messageId, Map<String, dynamic>? additionalData}) async {
    try {
      if (_analyticsHandler != null) {
        await _analyticsHandler!.onNotificationEvent(eventType: eventType, messageId: messageId, additionalData: additionalData);
      }
    } catch (e) {
      debugPrint('❌ Analytics event gönderme hatası: $e');
    }
  }

  /// Test amaçlı token refresh handler'ını test etmek için
  ///
  /// **NOT:** Bu metod sadece test amaçlı eklenmiştir!
  /// Production kodunda kullanılmamalıdır.
  ///
  /// **Parametreler:**
  /// - [token]: Test edilecek token
  ///
  /// **Example:**
  /// ```dart
  /// // Test içinde kullanım
  /// await manager.testTokenRefresh('test_token_123');
  /// ```
  @visibleForTesting
  Future<void> testTokenRefresh(String token) async {
    await _handleTokenRefresh(token);
  }

  /// Test amaçlı mevcut token'ı almak için
  ///
  /// **NOT:** Bu metod sadece test amaçlı eklenmiştir!
  /// Production kodunda kullanılmamalıdır.
  ///
  /// **Returns:**
  /// Mevcut cache'lenmiş token
  ///
  /// **Example:**
  /// ```dart
  /// // Test içinde kullanım
  /// final currentToken = manager.testGetCurrentToken();
  /// ```
  @visibleForTesting
  String? testGetCurrentToken() {
    return _currentToken;
  }
}
