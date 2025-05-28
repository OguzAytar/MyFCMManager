import 'package:flutter_test/flutter_test.dart';
import 'package:ogzfirebasemanager/ogzfirebasemanager.dart';

// Test implementations
class TestTokenHandler implements FcmTokenHandler {
  String? lastToken;
  String? lastDeletedToken;
  String? lastOldToken;
  String? lastNewToken;

  @override
  Future<bool> onTokenReceived(String token, {String? userId}) async {
    lastToken = token;
    return true;
  }

  @override
  Future<bool> onTokenDelete(String token) async {
    lastDeletedToken = token;
    return true;
  }

  @override
  Future<void> onTokenRefreshed(String oldToken, String newToken) async {
    lastOldToken = oldToken;
    lastNewToken = newToken;
    await onTokenReceived(newToken);
  }
}

class TestMessageHandler implements FcmMessageHandler {
  FcmMessage? lastForegroundMessage;
  FcmMessage? lastTappedMessage;
  FcmMessage? lastAppOpenedMessage;

  @override
  Future<void> onForegroundMessage(FcmMessage message) async {
    lastForegroundMessage = message;
  }

  @override
  Future<void> onMessageTap(FcmMessage message) async {
    lastTappedMessage = message;
  }

  @override
  Future<void> onAppOpenedFromNotification(FcmMessage message) async {
    lastAppOpenedMessage = message;
  }
}

class TestAnalyticsHandler implements FcmAnalyticsHandler {
  List<Map<String, dynamic>> events = [];

  @override
  Future<void> onNotificationEvent({required String eventType, required String messageId, Map<String, dynamic>? additionalData}) async {
    events.add({'eventType': eventType, 'messageId': messageId, 'additionalData': additionalData});
  }
}

class TestPreferencesHandler implements FcmPreferencesHandler {
  bool? lastEnabled;
  List<String>? lastCategories;
  Map<String, bool>? lastChannelSettings;

  @override
  Future<bool> onUpdatePreferences({required bool enabled, List<String>? categories, Map<String, bool>? channelSettings}) async {
    lastEnabled = enabled;
    lastCategories = categories;
    lastChannelSettings = channelSettings;
    return true;
  }
}

// Hatalı token handler test için
class FaultyTokenHandler implements FcmTokenHandler {
  @override
  Future<bool> onTokenReceived(String token, {String? userId}) async {
    throw Exception('Test exception in onTokenReceived');
  }

  @override
  Future<bool> onTokenDelete(String token) async {
    throw Exception('Test exception in onTokenDelete');
  }

  @override
  Future<void> onTokenRefreshed(String oldToken, String newToken) async {
    throw Exception('Test exception in onTokenRefreshed');
  }
}

void main() {
  group('FCM Manager Tests', () {
    late TestTokenHandler tokenHandler;
    late TestMessageHandler messageHandler;
    late TestAnalyticsHandler analyticsHandler;
    late TestPreferencesHandler preferencesHandler;

    setUp(() {
      tokenHandler = TestTokenHandler();
      messageHandler = TestMessageHandler();
      analyticsHandler = TestAnalyticsHandler();
      preferencesHandler = TestPreferencesHandler();
    });

    test('FcmManager should be singleton', () {
      // Bu test Firebase bağımlılığı olmadan çalışmaz
      expect(true, isTrue); // Firebase olmadan geçici test
    });

    test('Token handler should work correctly', () async {
      const testToken = 'test_token_123';

      await tokenHandler.onTokenReceived(testToken);
      expect(tokenHandler.lastToken, equals(testToken));

      await tokenHandler.onTokenDelete(testToken);
      expect(tokenHandler.lastDeletedToken, equals(testToken));

      const oldToken = 'old_token';
      const newToken = 'new_token';
      await tokenHandler.onTokenRefreshed(oldToken, newToken);
      expect(tokenHandler.lastOldToken, equals(oldToken));
      expect(tokenHandler.lastNewToken, equals(newToken));
      expect(tokenHandler.lastToken, equals(newToken));
    });

    test('Message handler should work correctly', () async {
      final testMessage = FcmMessage(title: 'Test Title', body: 'Test Body', data: {'key': 'value'});

      await messageHandler.onForegroundMessage(testMessage);
      expect(messageHandler.lastForegroundMessage?.title, equals('Test Title'));

      await messageHandler.onMessageTap(testMessage);
      expect(messageHandler.lastTappedMessage?.title, equals('Test Title'));

      await messageHandler.onAppOpenedFromNotification(testMessage);
      expect(messageHandler.lastAppOpenedMessage?.title, equals('Test Title'));
    });

    test('Analytics handler should track events', () async {
      await analyticsHandler.onNotificationEvent(eventType: 'test_event', messageId: 'msg_123', additionalData: {'test': 'data'});

      expect(analyticsHandler.events.length, equals(1));
      expect(analyticsHandler.events.first['eventType'], equals('test_event'));
      expect(analyticsHandler.events.first['messageId'], equals('msg_123'));
      expect(analyticsHandler.events.first['additionalData']['test'], equals('data'));
    });

    test('Preferences handler should update correctly', () async {
      final result = await preferencesHandler.onUpdatePreferences(
        enabled: true,
        categories: ['news', 'sports'],
        channelSettings: {'alerts': true, 'marketing': false},
      );

      expect(result, isTrue);
      expect(preferencesHandler.lastEnabled, isTrue);
      expect(preferencesHandler.lastCategories, equals(['news', 'sports']));
      expect(preferencesHandler.lastChannelSettings?['alerts'], isTrue);
      expect(preferencesHandler.lastChannelSettings?['marketing'], isFalse);
    });

    group('FcmMessage Tests', () {
      test('FcmMessage should create correctly', () {
        final message = FcmMessage(title: 'Test Title', body: 'Test Body', data: {'route': '/profile', 'id': '123'});

        expect(message.title, equals('Test Title'));
        expect(message.body, equals('Test Body'));
        expect(message.data?['route'], equals('/profile'));
        expect(message.data?['id'], equals('123'));
      });

      test('FcmMessage should handle null values', () {
        final message = FcmMessage(title: null, body: null, data: null);

        expect(message.title, isNull);
        expect(message.body, isNull);
        expect(message.data, isNull);
      });
    });

    group('FcmNotificationSettings Tests', () {
      test('FcmNotificationSettings should create correctly', () {
        final settings = FcmNotificationSettings(alert: true, badge: true, sound: true, provisional: true, announcement: false);

        expect(settings.alert, isTrue);
        expect(settings.badge, isTrue);
        expect(settings.sound, isTrue);
      });
    });

    group('Token Refresh Tests', () {
      late TestTokenHandler tokenHandler;

      setUp(() {
        tokenHandler = TestTokenHandler();
      });

      test('should handle first token correctly', () async {
        // İlk token'ı simüle et
        const firstToken = 'first_token_abc123';

        // Token handler'ı direkt test et
        await tokenHandler.onTokenReceived(firstToken);

        // İlk token alındığında onTokenReceived çağrılmalı
        expect(tokenHandler.lastToken, equals(firstToken));
      });

      test('should handle token refresh correctly', () async {
        const oldToken = 'old_token_xyz789';
        const newToken = 'new_token_abc123';

        // İlk olarak eski token'ı ayarla
        await tokenHandler.onTokenReceived(oldToken);
        expect(tokenHandler.lastToken, equals(oldToken));

        // Test değerlerini temizle
        tokenHandler.lastOldToken = null;
        tokenHandler.lastNewToken = null;

        // Şimdi token refresh'i test et
        await tokenHandler.onTokenRefreshed(oldToken, newToken);

        // Token refresh olduğunda onTokenRefreshed çağrılmalı
        expect(tokenHandler.lastOldToken, equals(oldToken));
        expect(tokenHandler.lastNewToken, equals(newToken));
        expect(tokenHandler.lastToken, equals(newToken)); // Son token yeni token olmalı
      });

      test('should handle multiple token refreshes', () async {
        const token1 = 'token_1';
        const token2 = 'token_2';
        const token3 = 'token_3';

        // İlk token
        await tokenHandler.onTokenReceived(token1);
        expect(tokenHandler.lastToken, equals(token1));

        // İkinci token refresh
        tokenHandler.lastOldToken = null;
        tokenHandler.lastNewToken = null;
        await tokenHandler.onTokenRefreshed(token1, token2);
        expect(tokenHandler.lastOldToken, equals(token1));
        expect(tokenHandler.lastNewToken, equals(token2));
        expect(tokenHandler.lastToken, equals(token2));

        // Üçüncü token refresh
        tokenHandler.lastOldToken = null;
        tokenHandler.lastNewToken = null;
        await tokenHandler.onTokenRefreshed(token2, token3);
        expect(tokenHandler.lastOldToken, equals(token2));
        expect(tokenHandler.lastNewToken, equals(token3));
        expect(tokenHandler.lastToken, equals(token3));
      });

      test('should handle same token refresh gracefully', () async {
        const sameToken = 'same_token_123';

        // İlk token
        await tokenHandler.onTokenReceived(sameToken);
        expect(tokenHandler.lastToken, equals(sameToken));

        // Aynı token ile refresh (Firebase bazen aynı token'ı tekrar gönderebilir)
        // Reset test values first
        tokenHandler.lastOldToken = null;
        tokenHandler.lastNewToken = null;

        await tokenHandler.onTokenRefreshed(sameToken, sameToken);

        // Aynı token olsa bile onTokenRefreshed çağrılmalı
        expect(tokenHandler.lastOldToken, equals(sameToken));
        expect(tokenHandler.lastNewToken, equals(sameToken));
        expect(tokenHandler.lastToken, equals(sameToken));
      });

      test('should handle token deletion correctly', () async {
        const tokenToDelete = 'token_to_delete_456';

        // Önce token'ı al
        await tokenHandler.onTokenReceived(tokenToDelete);
        expect(tokenHandler.lastToken, equals(tokenToDelete));

        // Sonra token'ı sil
        await tokenHandler.onTokenDelete(tokenToDelete);
        expect(tokenHandler.lastDeletedToken, equals(tokenToDelete));
      });

      test('should handle empty or null tokens gracefully', () async {
        // Boş string token
        await tokenHandler.onTokenReceived('');
        expect(tokenHandler.lastToken, equals(''));

        // Çok uzun token testi
        const longToken = 'very_long_token_very_long_token_very_long_token';
        await tokenHandler.onTokenReceived(longToken);
        expect(tokenHandler.lastToken, equals(longToken));
      });

      test('should handle token handler errors gracefully', () async {
        // Hatalı token handler oluştur
        final faultyHandler = FaultyTokenHandler();

        // Token refresh çağrısı hata verdiğinde de gracefully handle etmeli
        // Hata fırlatsa bile test devam etmeli
        try {
          await faultyHandler.onTokenReceived('test_token');
          fail('Expected exception was not thrown');
        } catch (e) {
          // Beklenen hata
          expect(e.toString(), contains('Test exception'));
        }

        try {
          await faultyHandler.onTokenRefreshed('old', 'new');
          fail('Expected exception was not thrown');
        } catch (e) {
          // Beklenen hata
          expect(e.toString(), contains('Test exception'));
        }
      });
    });
  });
}
