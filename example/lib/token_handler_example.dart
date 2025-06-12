import 'dart:developer';

import 'package:ogzfirebasemanager/ogzfirebasemanager.dart';

/// Token işlemlerini yöneten örnek sınıf
///
/// Bu sınıf FCM token'larını nasıl alıp kullanacağınızı gösterir.
/// Token'ları backend'e gönderme, kaydetme ve silme işlemlerini içerir.
class MyTokenHandler implements FcmTokenHandler {
  // Token'ı local olarak saklamak için (gerçek uygulamada shared_preferences kullanın)
  String? _currentToken;

  /// Token'ı alır ve backend'e gönderir
  ///
  /// Bu metod yeni token alındığında veya token yenilendiğinde çağrılır
  @override
  Future<bool> onTokenReceived(String token, {String? userId}) async {
    try {
      log('🔑 Yeni FCM Token alındı: ${token.substring(0, 20)}...');

      // Token'ı local olarak sakla
      _currentToken = token;

      // Backend'e token gönder
      final success = await _sendTokenToBackend(token, userId);

      if (success) {
        log('✅ Token başarıyla backend\'e gönderildi');

        // Token'ı local storage'a kaydet (opsiyonel)
        await _saveTokenToLocal(token);

        return true;
      } else {
        log('❌ Token backend\'e gönderilemedi');
        return false;
      }
    } catch (e) {
      log('❌ Token işleme hatası: $e');
      return false;
    }
  }

  /// Token silindiğinde çağrılır (logout durumu)
  @override
  Future<bool> onTokenDelete(String token) async {
    try {
      log('🗑️ Token siliniyor: ${token.substring(0, 20)}...');

      // Backend'den token'ı sil
      final success = await _deleteTokenFromBackend(token);

      if (success) {
        // Local token'ı temizle
        _currentToken = null;
        await _clearLocalToken();

        log('✅ Token başarıyla silindi');
        return true;
      } else {
        log('❌ Token silinemedi');
        return false;
      }
    } catch (e) {
      log('❌ Token silme hatası: $e');
      return false;
    }
  }

  /// Token yenilendiğinde çağrılır
  @override
  Future<void> onTokenRefreshed(String oldToken, String newToken) async {
    try {
      log('🔄 Token yenilendi:');
      log('   Eski: ${oldToken.substring(0, 20)}...');
      log('   Yeni: ${newToken.substring(0, 20)}...');

      // Önce eski token'ı backend'den sil
      await _deleteTokenFromBackend(oldToken);

      // Sonra yeni token'ı gönder
      await onTokenReceived(newToken);
    } catch (e) {
      log('❌ Token refresh hatası: $e');
    }
  }

  /// Mevcut token'ı döndürür
  String? getCurrentToken() {
    return _currentToken;
  }

  /// Token var mı kontrol eder
  bool hasToken() {
    return _currentToken != null && _currentToken!.isNotEmpty;
  }

  // --- Private Helper Methods ---

  /// Token'ı backend'e gönderir
  Future<bool> _sendTokenToBackend(String token, String? userId) async {
    try {
      // Gerçek API çağrısı örneği:
      /*
      final response = await http.post(
        Uri.parse('https://yourapi.com/fcm/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'userId': userId ?? 'anonymous',
          'platform': Platform.isIOS ? 'ios' : 'android',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      
      return response.statusCode == 200;
      */

      // Test için simülasyon
      await Future.delayed(const Duration(milliseconds: 500));
      log('📤 Token backend\'e gönderildi: POST /api/fcm/token');
      return true;
    } catch (e) {
      log('❌ Backend token gönderme hatası: $e');
      return false;
    }
  }

  /// Token'ı backend'den siler
  Future<bool> _deleteTokenFromBackend(String token) async {
    try {
      // Gerçek API çağrısı örneği:
      /*
      final response = await http.delete(
        Uri.parse('https://yourapi.com/fcm/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );
      
      return response.statusCode == 200;
      */

      // Test için simülasyon
      await Future.delayed(const Duration(milliseconds: 300));
      log('🗑️ Token backend\'den silindi: DELETE /api/fcm/token');
      return true;
    } catch (e) {
      log('❌ Backend token silme hatası: $e');
      return false;
    }
  }

  /// Token'ı local storage'a kaydet
  Future<void> _saveTokenToLocal(String token) async {
    try {
      // Gerçek uygulamada shared_preferences kullanın:
      /*
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      await prefs.setString('fcm_token_date', DateTime.now().toIso8601String());
      */

      log('💾 Token local storage\'a kaydedildi');
    } catch (e) {
      log('❌ Local token kaydetme hatası: $e');
    }
  }

  /// Local token'ı temizle
  Future<void> _clearLocalToken() async {
    try {
      // Gerçek uygulamada shared_preferences kullanın:
      /*
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
      await prefs.remove('fcm_token_date');
      */

      log('🧹 Local token temizlendi');
    } catch (e) {
      log('❌ Local token temizleme hatası: $e');
    }
  }
}

/// Token işlemlerini kullanmak için örnek servis sınıfı
class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  late MyTokenHandler _tokenHandler;

  /// Token servisini başlat
  void initialize() {
    _tokenHandler = MyTokenHandler();
  }

  /// FCM Manager'ı token handler ile başlat
  Future<void> startFcm() async {
    await FcmManager().initialize(tokenHandler: _tokenHandler);
  }

  /// Mevcut token'ı al
  String? getCurrentToken() {
    return _tokenHandler.getCurrentToken();
  }

  /// Token var mı kontrol et
  bool hasValidToken() {
    return _tokenHandler.hasToken();
  }

  /// Manuel token refresh tetikle
  Future<String?> refreshToken() async {
    try {
      final newToken = await FcmManager().getToken();
      if (newToken != null) {
        await _tokenHandler.onTokenReceived(newToken);
        return newToken;
      }
      return null;
    } catch (e) {
      log('❌ Manuel token refresh hatası: $e');
      return null;
    }
  }

  /// Logout işlemi
  Future<bool> logout() async {
    try {
      final currentToken = getCurrentToken();
      if (currentToken != null) {
        return await _tokenHandler.onTokenDelete(currentToken);
      }
      return true;
    } catch (e) {
      log('❌ Logout hatası: $e');
      return false;
    }
  }
}
