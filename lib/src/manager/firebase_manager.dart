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

  /// Singleton instance'a direct erişim
  /// Debug ve test amaçlı kullanım için
  static FcmManager get instance => _instance;

  /// Private constructor - sadece içeriden çağrılabilir
  FcmManager._internal();

  // Initialization durumu
  /// FCM Manager'ın initialize edilip edilmediğini takip eder
  bool _isInitialized = false;

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

  /// Topic yönetimi için kullanıcı tarafından implement edilen handler
  /// Topic abone/abonelik çıkma işlemleri için çağrılır
  FcmTopicHandler? _topicHandler;

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
  /// - [topicHandler]: Topic yönetimi için handler (opsiyonel)
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
  ///   topicHandler: MyTopicHandler(),
  ///   onNotificationTap: (message) => print('Tapped: ${message.title}'),
  /// );
  /// ```
  Future<void> initialize({
    FcmTokenHandler? tokenHandler,
    FcmMessageHandler? messageHandler,
    FcmAnalyticsHandler? analyticsHandler,
    FcmPreferencesHandler? preferencesHandler,
    FcmTopicHandler? topicHandler,
    void Function(FcmMessage message)? onNotificationTap,
  }) async {
    // Eğer zaten initialize edilmişse tekrar initialize etme
    if (_isInitialized) {
      debugPrint('⚠️ FCM Manager zaten initialize edilmiş');
      return;
    }

    // Handler'ları kaydet
    _tokenHandler = tokenHandler;
    _messageHandler = messageHandler;
    _analyticsHandler = analyticsHandler;
    _preferencesHandler = preferencesHandler;
    _topicHandler = topicHandler;
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
      //TODO kaldırılacak
      log(initialToken);
      await _handleTokenRefresh(initialToken);
    }

    // Initialize durumunu işaretle
    _isInitialized = true;
    debugPrint('✅ FCM Manager başarıyla initialize edildi');
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
      final oldToken = _currentToken;
      _currentToken = token;

      if (_tokenHandler != null) {
        // Eğer eski token varsa onTokenRefreshed'i çağır
        if (oldToken != null && oldToken != token) {
          await _tokenHandler!.onTokenRefreshed(oldToken, token);
          debugPrint('🔄 FCM Token güncellendi: ${token.substring(0, 20)}...');
        } else {
          // İlk token veya aynı token ise onTokenReceived'i çağır
          await _tokenHandler!.onTokenReceived(token);
        }
      }
    } catch (e) {
      debugPrint('❌ Token refresh handler hatası: $e');
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
          // Topic cache'ini temizle
          _fcmService.clearTopicCache();
          debugPrint('✅ Logout başarılı, token silindi ve topic cache temizlendi');
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

  /// Manuel token refresh tetikler
  ///
  /// Bu metod özellikle splash screen'de veya remember me durumlarında
  /// kullanıcı login olmadan önce token'ı refresh etmek için kullanılır.
  ///
  /// **Use Cases:**
  /// - Splash screen'de stored user varsa token refresh
  /// - Remember me aktifse automatic token refresh
  /// - User login olduktan sonra token'ı güncelleme
  /// - Background'dan foreground'a geçişte token kontrolü
  ///
  /// **Returns:**
  /// Yeni token string'i veya null (token alınamazsa)
  ///
  /// **Example:**
  /// ```dart
  /// // Splash screen'de kullanım
  /// if (userIsRemembered) {
  ///   final token = await FcmManager().refreshToken();
  ///   if (token != null) {
  ///     // Token başarıyla refresh edildi, ana sayfaya git
  ///   }
  /// }
  ///
  /// // Login sonrası kullanım
  /// await FcmManager().refreshToken();
  /// ```
  Future<String?> refreshToken() async {
    try {
      // Initialize kontrolü
      if (!_isInitialized) {
        debugPrint('⚠️ FCM Manager initialize edilmemiş, önce initialize() çağırın');
        return null;
      }

      // Firebase'den güncel token'ı al
      final newToken = await getToken();

      if (newToken != null) {
        // Token refresh handler'ını çağır
        await _handleTokenRefresh(newToken);
        return newToken;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Manuel token refresh hatası: $e');
      return null;
    }
  }

  /// Token'ı force refresh eder (Firebase'den yeni token ister)
  ///
  /// Bu metod Firebase'den yeni bir token oluşturulmasını zorunlu kılar.
  /// Normal refresh'den farkı, cache'lenmiş token'ı değil yeni token üretir.
  ///
  /// **Use Cases:**
  /// - Token corruption şüphesi
  /// - Güvenlik gerekliliği
  /// - Testing amaçlı yeni token alma
  ///
  /// **Returns:**
  /// Yeni üretilen token string'i veya null
  ///
  /// **Example:**
  /// ```dart
  /// // Güvenlik gerekliliği için yeni token
  /// final freshToken = await FcmManager().forceRefreshToken();
  /// ```
  Future<String?> forceRefreshToken() async {
    try {
      // Initialize kontrolü
      if (!_isInitialized) {
        debugPrint('⚠️ FCM Manager initialize edilmemiş, önce initialize() çağırın');
        return null;
      }

      // Firebase'den force refresh ile yeni token al
      await _fcmService.deleteToken(); // Mevcut token'ı sil
      final newToken = await _fcmService.getToken(); // Yeni token oluştur

      if (newToken != null) {
        await _handleTokenRefresh(newToken);
        return newToken;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Force token refresh hatası: $e');
      return null;
    }
  }

  /// Mevcut cache'lenmiş token'ı döndürür
  ///
  /// Bu metod network çağrısı yapmadan cache'lenmiş token'ı döndürür.
  /// Hızlı erişim için kullanılır.
  ///
  /// **Returns:**
  /// Cache'lenmiş token veya null
  ///
  /// **Example:**
  /// ```dart
  /// final cachedToken = FcmManager().getCachedToken();
  /// if (cachedToken != null) {
  ///   // Cache'den token kullan
  /// } else {
  ///   // Token'ı Firebase'den al
  ///   final token = await FcmManager().getToken();
  /// }
  /// ```
  String? getCachedToken() {
    return _currentToken;
  }

  /// Token'ın geçerli olup olmadığını kontrol eder
  ///
  /// **Returns:**
  /// true - Token mevcutsa ve boş değilse
  /// false - Token yoksa veya boşsa
  ///
  /// **Example:**
  /// ```dart
  /// if (FcmManager().hasValidToken()) {
  ///   // Token var, işlemlere devam et
  /// } else {
  ///   // Token al
  ///   await FcmManager().refreshToken();
  /// }
  /// ```
  bool hasValidToken() {
    return _currentToken != null && _currentToken!.isNotEmpty;
  }

  /// FCM Manager'ın initialize edilip edilmediğini kontrol eder
  ///
  /// **Returns:**
  /// true - Initialize edilmiş
  /// false - Henüz initialize edilmemiş
  ///
  /// **Example:**
  /// ```dart
  /// if (FcmManager().isInitialized) {
  ///   // Manager hazır, işlemlere devam et
  /// } else {
  ///   // Önce initialize et
  ///   await FcmManager().initialize(tokenHandler: handler);
  /// }
  /// ```
  bool get isInitialized => _isInitialized;

  // ==================== TOPIC MANAGEMENT ====================

  /// Bir topic'e abone ol
  ///
  /// FCM topic'lere abone olarak belirli kategorilerdeki bildirimleri alabilirsiniz.
  /// Topic'ler server-side'da tanımlanır ve push notification gönderimi için kullanılır.
  ///
  /// **Parameters:**
  /// - [topic]: Abone olunacak topic adı (örn: 'news', 'sports', 'weather')
  ///
  /// **Returns:**
  /// `true` - Abonelik başarılı
  /// `false` - Abonelik başarısız veya FCM Manager initialize edilmemiş
  ///
  /// **Example:**
  /// ```dart
  /// // Haber topic'ine abone ol
  /// final success = await FcmManager().subscribeToTopic('news');
  /// if (success) {
  ///   print('Haber bildirimlerine abone olundu');
  /// }
  ///
  /// // Spor topic'ine abone ol
  /// await FcmManager().subscribeToTopic('sports');
  /// ```
  ///
  /// **Topic Naming Rules:**
  /// - Topic adları sadece [a-zA-Z0-9-_.~%] karakterlerini içerebilir
  /// - Maksimum 900 karaktere kadar olabilir
  /// - `/topics/` prefix'i otomatik eklenir
  ///
  /// **Use Cases:**
  /// - Kategori bazlı bildirimler (haberler, spor, hava durumu)
  /// - Bölge bazlı bildirimler (şehir, ülke)
  /// - Kullanıcı ilgi alanları
  Future<bool> subscribeToTopic(String topic) async {
    try {
      // Initialize kontrolü
      if (!_isInitialized) {
        debugPrint('⚠️ FCM Manager initialize edilmemiş, topic subscription başarısız');
        return false;
      }

      debugPrint('📋 Topic\'e abone olunuyor: $topic');
      
      // FCM service'den topic'e abone ol
      final success = await _fcmService.subscribeToTopic(topic);
      
      // Topic handler'ı çağır
      if (_topicHandler != null) {
        await _topicHandler!.onTopicSubscribed(topic, success);
      }

      if (success) {
        debugPrint('✅ Topic aboneliği başarılı: $topic');
      } else {
        debugPrint('❌ Topic aboneliği başarısız: $topic');
      }

      return success;
    } catch (e) {
      debugPrint('❌ Topic subscription hatası: $e');
      
      // Hata durumunda da handler'ı bilgilendir
      if (_topicHandler != null) {
        await _topicHandler!.onTopicSubscribed(topic, false);
      }
      
      return false;
    }
  }

  /// Bir topic'ten abonelikten çık
  ///
  /// Artık belirli bir topic'ten bildirim almak istemediğinizde kullanılır.
  ///
  /// **Parameters:**
  /// - [topic]: Abonelikten çıkılacak topic adı
  ///
  /// **Returns:**
  /// `true` - Abonelikten çıkma başarılı
  /// `false` - İşlem başarısız
  ///
  /// **Example:**
  /// ```dart
  /// // Haber topic'inden abonelikten çık
  /// final success = await FcmManager().unsubscribeFromTopic('news');
  /// if (success) {
  ///   print('Haber bildirimlerinden abonelikten çıkıldı');
  /// }
  /// ```
  Future<bool> unsubscribeFromTopic(String topic) async {
    try {
      // Initialize kontrolü
      if (!_isInitialized) {
        debugPrint('⚠️ FCM Manager initialize edilmemiş, topic unsubscription başarısız');
        return false;
      }

      debugPrint('📋 Topic\'ten abonelikten çıkılıyor: $topic');
      
      // FCM service'den topic'ten abonelikten çık
      final success = await _fcmService.unsubscribeFromTopic(topic);
      
      // Topic handler'ı çağır
      if (_topicHandler != null) {
        await _topicHandler!.onTopicUnsubscribed(topic, success);
      }

      if (success) {
        debugPrint('✅ Topic abonelikten çıkma başarılı: $topic');
      } else {
        debugPrint('❌ Topic abonelikten çıkma başarısız: $topic');
      }

      return success;
    } catch (e) {
      debugPrint('❌ Topic unsubscription hatası: $e');
      
      // Hata durumunda da handler'ı bilgilendir
      if (_topicHandler != null) {
        await _topicHandler!.onTopicUnsubscribed(topic, false);
      }
      
      return false;
    }
  }

  /// Birden fazla topic'e aynı anda abone ol
  ///
  /// Performans optimizasyonu için birden fazla topic'e aynı anda abone olmanızı sağlar.
  ///
  /// **Parameters:**
  /// - [topics]: Abone olunacak topic listesi
  ///
  /// **Returns:**
  /// Map<String, bool> - Her topic için abonelik sonucu
  ///
  /// **Example:**
  /// ```dart
  /// final results = await FcmManager().subscribeToMultipleTopics([
  ///   'news',
  ///   'sports', 
  ///   'weather',
  ///   'alerts'
  /// ]);
  ///
  /// results.forEach((topic, success) {
  ///   print('$topic: ${success ? "Başarılı" : "Başarısız"}');
  /// });
  /// ```
  Future<Map<String, bool>> subscribeToMultipleTopics(List<String> topics) async {
    try {
      // Initialize kontrolü
      if (!_isInitialized) {
        debugPrint('⚠️ FCM Manager initialize edilmemiş');
        return Map<String, bool>.fromIterable(topics, value: (_) => false);
      }

      debugPrint('📋 Çoklu topic aboneliği başlatıldı: ${topics.join(", ")}');
      
      // FCM service'den bulk subscribe
      final results = await _fcmService.subscribeToMultipleTopics(topics);
      
      // Topic handler'ı çağır
      if (_topicHandler != null) {
        await _topicHandler!.onBulkTopicOperation(results, true);
      }

      final successCount = results.values.where((success) => success).length;
      debugPrint('✅ Çoklu topic aboneliği tamamlandı: $successCount/${topics.length} başarılı');

      return results;
    } catch (e) {
      debugPrint('❌ Çoklu topic subscription hatası: $e');
      final failedResults = Map<String, bool>.fromIterable(topics, value: (_) => false);
      
      // Hata durumunda da handler'ı bilgilendir
      if (_topicHandler != null) {
        await _topicHandler!.onBulkTopicOperation(failedResults, true);
      }
      
      return failedResults;
    }
  }

  /// Birden fazla topic'ten aynı anda abonelikten çık
  ///
  /// **Parameters:**
  /// - [topics]: Abonelikten çıkılacak topic listesi
  ///
  /// **Returns:**
  /// Map<String, bool> - Her topic için işlem sonucu
  ///
  /// **Example:**
  /// ```dart
  /// final results = await FcmManager().unsubscribeFromMultipleTopics([
  ///   'news', 'sports'
  /// ]);
  /// ```
  Future<Map<String, bool>> unsubscribeFromMultipleTopics(List<String> topics) async {
    try {
      // Initialize kontrolü
      if (!_isInitialized) {
        debugPrint('⚠️ FCM Manager initialize edilmemiş');
        return Map<String, bool>.fromIterable(topics, value: (_) => false);
      }

      debugPrint('📋 Çoklu topic abonelikten çıkma başlatıldı: ${topics.join(", ")}');
      
      // FCM service'den bulk unsubscribe
      final results = await _fcmService.unsubscribeFromMultipleTopics(topics);
      
      // Topic handler'ı çağır
      if (_topicHandler != null) {
        await _topicHandler!.onBulkTopicOperation(results, false);
      }

      final successCount = results.values.where((success) => success).length;
      debugPrint('✅ Çoklu topic abonelikten çıkma tamamlandı: $successCount/${topics.length} başarılı');

      return results;
    } catch (e) {
      debugPrint('❌ Çoklu topic unsubscription hatası: $e');
      final failedResults = Map<String, bool>.fromIterable(topics, value: (_) => false);
      
      // Hata durumunda da handler'ı bilgilendir
      if (_topicHandler != null) {
        await _topicHandler!.onBulkTopicOperation(failedResults, false);
      }
      
      return failedResults;
    }
  }

  // ==================== TOPIC SUBSCRIPTION STATUS ====================

  /// Bir topic'e abone olup olmadığını kontrol eder
  ///
  /// **Parameters:**
  /// - [topic]: Kontrol edilecek topic adı
  ///
  /// **Returns:**
  /// true - Abone, false - Abone değil veya FCM initialize edilmemiş
  ///
  /// **Note:**
  /// Bu metod local cache'i kontrol eder. Firebase'den gerçek zamanlı
  /// subscription durumu almaz çünkü Firebase böyle bir API sağlamaz.
  ///
  /// **Example:**
  /// ```dart
  /// if (FcmManager().isSubscribedToTopic('news')) {
  ///   print('News topic\'ine abone');
  /// } else {
  ///   print('News topic\'ine abone değil');
  /// }
  /// ```
  bool isSubscribedToTopic(String topic) {
    if (!_isInitialized) {
      debugPrint('⚠️ FCM Manager initialize edilmemiş');
      return false;
    }
    
    return _fcmService.isSubscribedToTopic(topic);
  }

  /// Tüm abone olunan topic'leri getirir
  ///
  /// **Returns:**
  /// Set<String> - Abone olunan topic'lerin seti (boş set FCM initialize edilmemişse)
  ///
  /// **Example:**
  /// ```dart
  /// final subscribedTopics = FcmManager().getAllSubscribedTopics();
  /// print('Abone olunan topic\'ler: $subscribedTopics');
  /// 
  /// if (subscribedTopics.isNotEmpty) {
  ///   subscribedTopics.forEach((topic) {
  ///     print('- $topic');
  ///   });
  /// }
  /// ```
  Set<String> getAllSubscribedTopics() {
    if (!_isInitialized) {
      debugPrint('⚠️ FCM Manager initialize edilmemiş');
      return <String>{};
    }
    
    return _fcmService.getAllSubscribedTopics();
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
  /// final statuses = FcmManager().getTopicSubscriptionStatuses([
  ///   'news', 'sports', 'weather', 'alerts'
  /// ]);
  /// 
  /// statuses.forEach((topic, isSubscribed) {
  ///   print('$topic: ${isSubscribed ? "Abone" : "Abone değil"}');
  /// });
  /// 
  /// // Sadece abone olunan topic'leri filtrele
  /// final subscribedOnly = statuses.entries
  ///   .where((entry) => entry.value)
  ///   .map((entry) => entry.key)
  ///   .toList();
  /// ```
  Map<String, bool> getTopicSubscriptionStatuses(List<String> topics) {
    if (!_isInitialized) {
      debugPrint('⚠️ FCM Manager initialize edilmemiş');
      return Map<String, bool>.fromIterable(topics, value: (_) => false);
    }
    
    return _fcmService.getTopicSubscriptionStatuses(topics);
  }

  /// Abone olunan topic sayısını getirir
  ///
  /// **Returns:**
  /// int - Abone olunan topic sayısı
  ///
  /// **Example:**
  /// ```dart
  /// final count = FcmManager().getSubscribedTopicCount();
  /// print('Toplam $count topic\'e abone');
  /// 
  /// if (count >= 10) {
  ///   print('⚠️ Çok fazla topic\'e abone olunmuş!');
  /// }
  /// ```
  int getSubscribedTopicCount() {
    return getAllSubscribedTopics().length;
  }

  /// Topic subscription durumunu detaylı rapor olarak getirir
  ///
  /// **Returns:**
  /// Map<String, dynamic> - Detaylı subscription raporu
  ///
  /// **Example:**
  /// ```dart
  /// final report = FcmManager().getTopicSubscriptionReport();
  /// print('Toplam topic sayısı: ${report['totalCount']}');
  /// print('Abone olunan topic\'ler: ${report['topics']}');
  /// print('Rapor zamanı: ${report['timestamp']}');
  /// ```
  Map<String, dynamic> getTopicSubscriptionReport() {
    final topics = getAllSubscribedTopics();
    
    return {
      'totalCount': topics.length,
      'topics': topics.toList(),
      'timestamp': DateTime.now().toIso8601String(),
      'isInitialized': _isInitialized,
    };
  }

  // ==================== TEST METHODS ====================

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
