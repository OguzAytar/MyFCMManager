# OGZ Firebase Manager

🔥 **Gelişmiş Firebase Cloud Messaging (FCM) yönetim paketi** - Interface tabanlı mimari ile maksimum esneklik sunar.

## ✨ Özellikler

🚀 **Kapsamlı FCM Yönetimi**
- FCM token yönetimi ve otomatik yenileme
- Foreground ve background bildirim işleme
- iOS ve Android için izin yönetimi
- Token değişim takibi ile gerçek zamanlı güncellemeler

🏗️ **Interface Tabanlı Mimari**
- `FcmTokenHandler` - Token işlemleri için
- `FcmMessageHandler` - Mesaj işleme için
- `FcmAnalyticsHandler` - Analytics takibi için  
- `FcmPreferencesHandler` - Kullanıcı tercihleri için

🔧 **Esnek Entegrasyon**
- Zorunlu HTTP client veya yerel bildirim kütüphanesi yok
- Kendi backend entegrasyonunuzu getirin
- Özelleştirilebilir analytics ve logging
- Stream tabanlı token değişim dinleme

⚡ **Kolay Yapılandırma**
- Opsiyonel handler'larla basit başlatma
- Esnek yapılandırma seçenekleri
- Kolay erişim için singleton pattern

## Getting started

### Prerequisites

1. **Firebase Project Setup**
   - Create a Firebase project
   - Add your Flutter app to Firebase
   - Download and add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

2. **Platform Configuration**

   **Android:** Add to `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.WAKE_LOCK" />
   <uses-permission android:name="android.permission.VIBRATE" />
   ```

   **iOS:** Add to `ios/Runner/Info.plist`:
   ```xml
   <key>UIBackgroundModes</key>
   <array>
       <string>fetch</string>
       <string>remote-notification</string>
   </array>
   ```

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  ogzfirebasemanager: ^0.0.1
```

## Usage

### Basic Setup

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ogzfirebasemanager/ogzfirebasemanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}
```

### Implementing Handler Interfaces

```dart
// Token Handler - Backend integration
class MyTokenHandler implements FcmTokenHandler {
  @override
  Future<bool> onTokenReceived(String token, {String? userId}) async {
    // Send token to your backend
    print('Sending token to backend: ${token.substring(0, 20)}...');
    // Your backend API call here
    return true;
  }

  @override
  Future<bool> onTokenDelete(String token) async {
    // Delete token from your backend
    print('Deleting token from backend: ${token.substring(0, 20)}...');
    // Your backend API call here
    return true;
  }

  @override
  Future<void> onTokenRefreshed(String oldToken, String newToken) async {
    print('Token refreshed: ${oldToken.substring(0, 20)}... -> ${newToken.substring(0, 20)}...');
    await onTokenReceived(newToken);
  }
}

// Message Handler - Notification processing
class MyMessageHandler implements FcmMessageHandler {
  @override
  Future<void> onForegroundMessage(FcmMessage message) async {
    // Handle foreground notifications
    // You can use any local notification library here
    print('Foreground message: ${message.title}');
  }

  @override
  Future<void> onMessageTap(FcmMessage message) async {
    // Handle notification tap
    print('Notification tapped: ${message.title}');
    
    // Custom navigation logic
    final route = message.data?['route'];
    if (route != null) {
      // Navigate to specific route
    }
  }

  @override
  Future<void> onAppOpenedFromNotification(FcmMessage message) async {
    // Handle app opened from notification
    print('App opened from notification: ${message.title}');
  }
}

// Analytics Handler - Event tracking
class MyAnalyticsHandler implements FcmAnalyticsHandler {
  @override
  Future<void> onNotificationEvent({
    required String eventType,
    required String messageId,
    Map<String, dynamic>? additionalData,
  }) async {
    // Send analytics to your preferred service
    print('Analytics event: $eventType for $messageId');
  }
}

// Preferences Handler - User settings
class MyPreferencesHandler implements FcmPreferencesHandler {
  @override
  Future<bool> onUpdatePreferences({
    required bool enabled,
    List<String>? categories,
    Map<String, bool>? channelSettings,
  }) async {
    // Update user preferences in your backend
    print('Updating preferences: $enabled');
    return true;
  }
}
```

### Initialize FCM Manager

```dart
class _MyHomePageState extends State<MyHomePage> {
  late MyTokenHandler _tokenHandler;
  late MyMessageHandler _messageHandler;
  late MyAnalyticsHandler _analyticsHandler;
  late MyPreferencesHandler _preferencesHandler;

  @override
  void initState() {
    super.initState();
    _initHandlers();
    _initializeFCM();
  }

  void _initHandlers() {
    _tokenHandler = MyTokenHandler();
    _messageHandler = MyMessageHandler();
    _analyticsHandler = MyAnalyticsHandler();
    _preferencesHandler = MyPreferencesHandler();
  }

  Future<void> _initializeFCM() async {
    // Initialize FCM Manager with handlers
    await FcmManager().initialize(
      tokenHandler: _tokenHandler,
      messageHandler: _messageHandler,
      analyticsHandler: _analyticsHandler,
      preferencesHandler: _preferencesHandler,
      // Simple callback for quick notifications
      onNotificationTap: (message) {
        print('Simple notification tap: ${message.title}');
      },
    );

    // Request permissions
    await FcmManager().requestPermission();

    // Get initial token
    final token = await FcmManager().getToken();
    print('FCM Token: $token');
  }
}
```

### Listen to Token Changes

```dart
class _MyHomePageState extends State<MyHomePage> {
  StreamSubscription<String>? _tokenSubscription;

  void _startTokenListener() {
    _tokenSubscription = FcmManager().onTokenRefresh.listen((newToken) {
      print('Token changed: $newToken');
      // Update UI or cache
    });
  }

  @override
  void dispose() {
    _tokenSubscription?.cancel();
    super.dispose();
  }
}
```

### Advanced Usage

#### Manual Token Management
```dart
// Get current token
final token = await FcmManager().getToken();

// Logout (delete token from backend)
final success = await FcmManager().logout();

// Update notification preferences
await FcmManager().updateNotificationPreferences(
  enabled: true,
  categories: ['news', 'promotions'],
  channelSettings: {'alerts': true, 'marketing': false},
);

// Send custom analytics event
await FcmManager().sendAnalyticsEvent(
  eventType: 'custom_event',
  messageId: 'message_123',
  additionalData: {'source': 'user_action'},
);
```

#### Listen to Messages Stream
```dart
StreamSubscription<FcmMessage>? _messageSubscription;

void _startMessageListener() {
  _messageSubscription = FcmManager().onMessage.listen((message) {
    print('New FCM message: ${message.title}');
  });
}

    // Initialize FCM
    await FcmManager().initialize(
      navigatorKey: widget.navigatorKey,
      showForegroundNotifications: true,
      userId: 'user123',
    );

    // Register custom route handlers
    FcmManager().registerRouteHandler('profile', (message) async {
      // Custom profile navigation logic
      await Navigator.pushNamed(context, '/profile');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('FCM Manager Demo')),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _getToken,
              child: Text('Get FCM Token'),
            ),
            ElevatedButton(
              onPressed: _requestPermissions,
              child: Text('Request Permissions'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getToken() async {
    final token = await FcmManager().getToken();
    print('FCM Token: $token');
  }

  Future<void> _requestPermissions() async {
    final settings = await FcmManager().requestPermission();
    print('Permissions: ${settings.toString()}');
  }
}
```

### Advanced Usage

#### Custom Navigation Handling

```dart
// Register multiple route handlers
FcmManager().registerRouteHandler('chat', (message) async {
  final chatId = message.data?['chat_id'];
  await Navigator.pushNamed(context, '/chat/$chatId');
});

FcmManager().registerRouteHandler('product', (message) async {
  final productId = message.data?['product_id'];
  await Navigator.pushNamed(context, '/product/$productId');
});

// Handle notification taps
FcmManager().onNotificationTap = (message) {
  print('Notification tapped: ${message.title}');
  // Custom logic here
};
```

#### Backend Integration

```dart
// Update notification preferences
await FcmManager().updateNotificationPreferences(
  enabled: true,
  categories: ['news', 'promotions', 'updates'],
  channelSettings: {
    'news': true,
    'promotions': false,
    'updates': true,
  },
);

// Send custom analytics
await FcmManager().sendAnalyticsEvent(
  eventType: 'notification_viewed',
  messageId: 'msg_123',
  additionalData: {
    'source': 'push_notification',
    'campaign_id': 'summer_sale',
  },
);

// Logout and clean up
await FcmManager().logout();
```

#### Listen to FCM Events

```dart
// Listen to token changes
FcmManager().onTokenRefresh.listen((newToken) {
  print('New token received: $newToken');
  // Send to your backend
});

// Listen to foreground messages
FcmManager().onMessage.listen((message) {
  print('Foreground message: ${message.title}');
  // Handle message
});
```

### Notification Payload Structure

For optimal navigation and handling, structure your FCM payload like this:

```json
{
  "notification": {
    "title": "New Message",
    "body": "You have a new message from John"
  },
  "data": {
    "messageId": "msg_123",
    "route": "chat",
    "screen": "chat",
    "action": "open_chat",
    "chat_id": "chat_456",
    "priority": "high",
    "category": "messages",
    "deep_link": "myapp://chat/456"
  }
}
```

## API Reference

### FcmManager

| Method | Description |
|--------|-------------|
| `initialize()` | Initialize FCM with configuration |
| `configureHttpService()` | Configure backend integration |
| `getToken()` | Get current FCM token |
| `requestPermission()` | Request notification permissions |
| `registerRouteHandler()` | Register custom navigation handler |
| `updateNotificationPreferences()` | Update user preferences |
| `logout()` | Clean up and remove token |

### Navigation Data Keys

| Key | Description |
|-----|-------------|
| `route` | Custom route handler name |
| `screen` | Direct screen navigation |
| `action` | Action-based handling |
| `*_id` | Entity IDs for navigation |

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
