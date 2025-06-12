import 'dart:developer';

import 'package:ogzfirebasemanager/ogzfirebasemanager.dart';

/// FCM token işlemleri için yardımcı sınıf
///
/// Bu sınıf splash screen, remember me ve diğer özel durumlar için
/// token işlemlerini kolaylaştıran utility metodları içerir.
class FcmTokenHelper {
  static final FcmTokenHelper _instance = FcmTokenHelper._internal();
  factory FcmTokenHelper() => _instance;
  FcmTokenHelper._internal();

  /// Splash screen için token kontrolü ve refresh
  ///
  /// Bu metod uygulama açılırken kullanıcının remember me durumunu
  /// kontrol ederek token refresh işlemini yapar.
  ///
  /// **Parameters:**
  /// - [isUserRemembered]: Kullanıcının remember me durumu
  /// - [userId]: Kullanıcı ID'si (opsiyonel)
  ///
  /// **Returns:**
  /// TokenRefreshResult - İşlem sonucu ve detaylar
  ///
  /// **Example:**
  /// ```dart
  /// // Splash screen'de kullanım
  /// final result = await FcmTokenHelper().handleSplashTokenRefresh(
  ///   isUserRemembered: userPrefs.rememberMe,
  ///   userId: userPrefs.userId,
  /// );
  ///
  /// if (result.success) {
  ///   // Token başarıyla refresh edildi, ana sayfaya git
  ///   navigator.pushReplacementNamed('/home');
  /// } else {
  ///   // Login sayfasına git
  ///   navigator.pushReplacementNamed('/login');
  /// }
  /// ```
  Future<TokenRefreshResult> handleSplashTokenRefresh({required bool isUserRemembered, String? userId}) async {
    try {
      log('🚀 Splash token refresh başlatıldı - Remember: $isUserRemembered');

      if (!isUserRemembered) {
        return TokenRefreshResult(success: false, token: null, reason: 'User not remembered');
      }

      // Mevcut cache'lenmiş token'ı kontrol et
      final cachedToken = FcmManager().getCachedToken();
      if (cachedToken != null) {
        log('📋 Cache\'lenmiş token bulundu');
        return TokenRefreshResult(success: true, token: cachedToken, reason: 'Token found in cache');
      }

      // Token refresh yap
      final newToken = await FcmManager().refreshToken();
      if (newToken != null) {
        log('✅ Splash token refresh başarılı');
        return TokenRefreshResult(success: true, token: newToken, reason: 'Token refreshed successfully');
      } else {
        log('❌ Splash token refresh başarısız');
        return TokenRefreshResult(success: false, token: null, reason: 'Token refresh failed');
      }
    } catch (e) {
      log('❌ Splash token refresh hatası: $e');
      return TokenRefreshResult(success: false, token: null, reason: 'Exception: $e');
    }
  }

  /// Login sonrası token refresh işlemi
  ///
  /// Kullanıcı login olduktan sonra token'ı kullanıcı bilgileriyle
  /// birlikte backend'e gönderir.
  ///
  /// **Parameters:**
  /// - [userId]: Login olan kullanıcı ID'si
  /// - [forceRefresh]: Zorunlu yeni token oluşturma (varsayılan: false)
  ///
  /// **Returns:**
  /// TokenRefreshResult - İşlem sonucu
  ///
  /// **Example:**
  /// ```dart
  /// // Login sonrası kullanım
  /// final result = await FcmTokenHelper().handlePostLoginTokenRefresh(
  ///   userId: user.id,
  ///   forceRefresh: false,
  /// );
  ///
  /// if (result.success) {
  ///   showSuccessMessage('Bildirimler aktif edildi');
  /// }
  /// ```
  Future<TokenRefreshResult> handlePostLoginTokenRefresh({required String userId, bool forceRefresh = false}) async {
    try {
      log('👤 Post-login token refresh - User: $userId, Force: $forceRefresh');

      String? token;

      if (forceRefresh) {
        // Zorunlu yeni token oluştur
        token = await FcmManager().forceRefreshToken();
      } else {
        // Normal refresh
        token = await FcmManager().refreshToken();
      }

      if (token != null) {
        log('✅ Post-login token refresh başarılı');
        return TokenRefreshResult(success: true, token: token, reason: 'Post-login refresh successful', userId: userId);
      } else {
        log('❌ Post-login token refresh başarısız');
        return TokenRefreshResult(success: false, token: null, reason: 'Post-login refresh failed', userId: userId);
      }
    } catch (e) {
      log('❌ Post-login token refresh hatası: $e');
      return TokenRefreshResult(success: false, token: null, reason: 'Exception: $e', userId: userId);
    }
  }

  /// Background'dan foreground'a geçişte token kontrolü
  ///
  /// Uygulama background'dan foreground'a geçtiğinde token'ın
  /// hala geçerli olup olmadığını kontrol eder.
  ///
  /// **Returns:**
  /// TokenRefreshResult - Kontrol sonucu
  ///
  /// **Example:**
  /// ```dart
  /// // AppLifecycleState.resumed'da kullanım
  /// final result = await FcmTokenHelper().handleAppResumeTokenCheck();
  /// if (!result.success) {
  ///   // Token sorunu var, yeniden login iste
  /// }
  /// ```
  Future<TokenRefreshResult> handleAppResumeTokenCheck() async {
    try {
      log('🔄 App resume token kontrolü');

      // Mevcut token'ı kontrol et
      if (FcmManager().hasValidToken()) {
        final cachedToken = FcmManager().getCachedToken();
        log('✅ App resume - Token geçerli');
        return TokenRefreshResult(success: true, token: cachedToken, reason: 'Token valid on resume');
      }

      // Token yoksa refresh dene
      final newToken = await FcmManager().refreshToken();
      if (newToken != null) {
        log('✅ App resume - Token refresh başarılı');
        return TokenRefreshResult(success: true, token: newToken, reason: 'Token refreshed on resume');
      } else {
        log('❌ App resume - Token refresh başarısız');
        return TokenRefreshResult(success: false, token: null, reason: 'Token refresh failed on resume');
      }
    } catch (e) {
      log('❌ App resume token kontrol hatası: $e');
      return TokenRefreshResult(success: false, token: null, reason: 'Exception on resume: $e');
    }
  }

  /// Periyodik token kontrolü
  ///
  /// Belirli aralıklarla token'ın geçerliliğini kontrol eder.
  ///
  /// **Parameters:**
  /// - [maxAgeHours]: Token maksimum yaşı (saat, varsayılan: 24)
  ///
  /// **Returns:**
  /// TokenRefreshResult - Kontrol sonucu
  ///
  /// **Example:**
  /// ```dart
  /// // Günlük token kontrol
  /// Timer.periodic(Duration(hours: 12), (timer) async {
  ///   final result = await FcmTokenHelper().handlePeriodicTokenCheck();
  ///   if (!result.success) {
  ///     // Token yenileme gerekli
  ///   }
  /// });
  /// ```
  Future<TokenRefreshResult> handlePeriodicTokenCheck({int maxAgeHours = 24}) async {
    try {
      log('⏰ Periyodik token kontrolü - Max yaş: ${maxAgeHours}h');

      // Token var mı kontrol et
      if (!FcmManager().hasValidToken()) {
        // Token yoksa refresh yap
        final newToken = await FcmManager().refreshToken();
        return TokenRefreshResult(
          success: newToken != null,
          token: newToken,
          reason: newToken != null ? 'Token refreshed in periodic check' : 'Periodic token refresh failed',
        );
      }

      // Token var, yaşını kontrol etmek için refresh dene
      final refreshedToken = await FcmManager().refreshToken();

      return TokenRefreshResult(success: refreshedToken != null, token: refreshedToken, reason: 'Periodic token check completed');
    } catch (e) {
      log('❌ Periyodik token kontrol hatası: $e');
      return TokenRefreshResult(success: false, token: null, reason: 'Exception in periodic check: $e');
    }
  }

  /// Network bağlantısı geri geldiğinde token kontrolü
  ///
  /// İnternet bağlantısı geri geldiğinde token'ı kontrol eder.
  ///
  /// **Returns:**
  /// TokenRefreshResult - Kontrol sonucu
  ///
  /// **Example:**
  /// ```dart
  /// // Connectivity değiştiğinde kullanım
  /// connectivity.onConnectivityChanged.listen((result) async {
  ///   if (result != ConnectivityResult.none) {
  ///     await FcmTokenHelper().handleNetworkReconnectTokenCheck();
  ///   }
  /// });
  /// ```
  Future<TokenRefreshResult> handleNetworkReconnectTokenCheck() async {
    try {
      log('🌐 Network reconnect token kontrolü');

      // Network geri geldiğinde token refresh dene
      final refreshedToken = await FcmManager().refreshToken();

      if (refreshedToken != null) {
        log('✅ Network reconnect - Token refresh başarılı');
        return TokenRefreshResult(success: true, token: refreshedToken, reason: 'Token refreshed after network reconnect');
      } else {
        log('❌ Network reconnect - Token refresh başarısız');
        return TokenRefreshResult(success: false, token: null, reason: 'Token refresh failed after network reconnect');
      }
    } catch (e) {
      log('❌ Network reconnect token kontrol hatası: $e');
      return TokenRefreshResult(success: false, token: null, reason: 'Exception after network reconnect: $e');
    }
  }
}

/// Token refresh işlem sonucu
class TokenRefreshResult {
  final bool success;
  final String? token;
  final String reason;
  final String? userId;
  final DateTime timestamp;

  TokenRefreshResult({required this.success, required this.token, required this.reason, this.userId}) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'TokenRefreshResult('
        'success: $success, '
        'hasToken: ${token != null}, '
        'reason: $reason, '
        'userId: $userId, '
        'timestamp: $timestamp'
        ')';
  }
}
