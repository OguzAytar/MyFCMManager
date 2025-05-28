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
      final manager1 = FcmManager();
      final manager2 = FcmManager();
      expect(manager1, equals(manager2));
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
  });
}
