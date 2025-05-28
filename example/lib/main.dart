import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ogzfirebasemanager/ogzfirebasemanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCM Manager Example',
      initialRoute: '/',
      routes: {
        '/': (context) => MyHomePage(),
        '/profile': (context) => ProfilePage(),
        '/chat': (context) => ChatPage(),
        '/settings': (context) => SettingsPage(),
      },
    );
  }
}

// Token Handler Implementation
class MyTokenHandler implements FcmTokenHandler {
  final Function(String)? onEventLog;

  MyTokenHandler({this.onEventLog});

  @override
  Future<bool> onTokenReceived(String token, {String? userId}) async {
    debugPrint('🔑 Token backend\'e gönderiliyor: ${token.substring(0, 20)}...');
    onEventLog?.call('Token received: ${token.substring(0, 20)}...');

    await Future.delayed(Duration(seconds: 1));
    return true;
  }

  @override
  Future<bool> onTokenDelete(String token) async {
    debugPrint('🗑️ Token backend\'den siliniyor: ${token.substring(0, 20)}...');
    onEventLog?.call('Token deleted: ${token.substring(0, 20)}...');

    await Future.delayed(Duration(seconds: 1));
    return true;
  }

  @override
  Future<void> onTokenRefreshed(String oldToken, String newToken) async {
    debugPrint('🔄 Token yenilendi: ${oldToken.substring(0, 20)}... -> ${newToken.substring(0, 20)}...');
    onEventLog?.call('Token refreshed: ${oldToken.substring(0, 20)}... -> ${newToken.substring(0, 20)}...');
    
    // Yeni token'ı backend'e gönder
    await onTokenReceived(newToken);
  }
}

// Message Handler Implementation
class MyMessageHandler implements FcmMessageHandler {
  final Function(String) onEventLog;

  MyMessageHandler(this.onEventLog);

  @override
  Future<void> onForegroundMessage(FcmMessage message) async {
    debugPrint('📱 Foreground mesaj alındı: ${message.title}');
    onEventLog('Foreground: ${message.title}');
  }

  @override
  Future<void> onMessageTap(FcmMessage message) async {
    debugPrint('👆 Mesaja tıklandı: ${message.title}');
    onEventLog('Tapped: ${message.title}');
    _handleNavigation(message);
  }

  @override
  Future<void> onAppOpenedFromNotification(FcmMessage message) async {
    debugPrint('🚀 Uygulama bildirimle açıldı: ${message.title}');
    onEventLog('App opened: ${message.title}');
    _handleNavigation(message);
  }

  void _handleNavigation(FcmMessage message) {
    final route = message.data?['route'];
    if (route != null) {
      debugPrint('🧭 Navigate to: /$route');
    }
  }
}

// Analytics Handler Implementation
class MyAnalyticsHandler implements FcmAnalyticsHandler {
  final Function(String) onEventLog;

  MyAnalyticsHandler(this.onEventLog);

  @override
  Future<void> onNotificationEvent({required String eventType, required String messageId, Map<String, dynamic>? additionalData}) async {
    debugPrint('📊 Analytics event: $eventType for $messageId');
    onEventLog('Analytics: $eventType');
  }
}

// Preferences Handler Implementation
class MyPreferencesHandler implements FcmPreferencesHandler {
  final Function(String) onEventLog;

  MyPreferencesHandler(this.onEventLog);

  @override
  Future<bool> onUpdatePreferences({required bool enabled, List<String>? categories, Map<String, bool>? channelSettings}) async {
    debugPrint('⚙️ Preferences güncelleniyor: $enabled');
    onEventLog('Preferences: $enabled');
    await Future.delayed(Duration(seconds: 1));
    return true;
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _fcmToken;
  bool _notificationsEnabled = true;
  final List<String> _eventLog = [];
  
  StreamSubscription<String>? _tokenSubscription;

  late MyTokenHandler _tokenHandler;
  late MyMessageHandler _messageHandler;
  late MyAnalyticsHandler _analyticsHandler;
  late MyPreferencesHandler _preferencesHandler;

  @override
  void initState() {
    super.initState();
    _initHandlers();
    _initializeFcm();
  }

  void _initHandlers() {
    _tokenHandler = MyTokenHandler(onEventLog: _addEventLog);
    _messageHandler = MyMessageHandler(_addEventLog);
    _analyticsHandler = MyAnalyticsHandler(_addEventLog);
    _preferencesHandler = MyPreferencesHandler(_addEventLog);
  }

  void _addEventLog(String event) {
    setState(() {
      _eventLog.insert(0, '${DateTime.now().toString().substring(11, 19)}: $event');
      if (_eventLog.length > 50) {
        _eventLog.removeLast();
      }
    });
  }

  Future<void> _initializeFcm() async {
    try {
      await FcmManager().initialize(
        tokenHandler: _tokenHandler,
        messageHandler: _messageHandler,
        analyticsHandler: _analyticsHandler,
        preferencesHandler: _preferencesHandler,
        onNotificationTap: (message) {
          _addEventLog('Simple callback: ${message.title}');
        },
      );

      // İlk token'ı al
      final token = await FcmManager().getToken();
      setState(() {
        _fcmToken = token;
      });

      // Token değişimlerini dinle
      _startTokenListener();

      _addEventLog('FCM initialized successfully');
      await _requestPermissions();
    } catch (e) {
      _addEventLog('FCM initialization error: $e');
    }
  }

  void _startTokenListener() {
    _tokenSubscription = FcmManager().onTokenRefresh.listen((newToken) {
      setState(() {
        _fcmToken = newToken;
      });
      _addEventLog('🔄 Token değişti: ${newToken.substring(0, 20)}...');
    });
  }

  Future<void> _requestPermissions() async {
    try {
      final settings = await FcmManager().requestPermission();
      _addEventLog('Permissions: ${settings.toString()}');
    } catch (e) {
      _addEventLog('Permission error: $e');
    }
  }

  Future<void> _refreshToken() async {
    try {
      final token = await FcmManager().getToken();
      setState(() {
        _fcmToken = token;
      });
      _addEventLog('Token refreshed');
    } catch (e) {
      _addEventLog('Token refresh error: $e');
    }
  }

  Future<void> _logout() async {
    try {
      final success = await FcmManager().logout();
      _addEventLog('Logout: ${success ? 'Success' : 'Failed'}');
    } catch (e) {
      _addEventLog('Logout error: $e');
    }
  }

  Future<void> _updatePreferences() async {
    try {
      final success = await FcmManager().updateNotificationPreferences(
        enabled: _notificationsEnabled,
        categories: ['general', 'promotions'],
        channelSettings: {'alerts': true, 'marketing': false},
      );
      _addEventLog('Preferences update: ${success ? 'Success' : 'Failed'}');
    } catch (e) {
      _addEventLog('Preferences error: $e');
    }
  }

  Future<void> _sendCustomAnalytics() async {
    try {
      await FcmManager().sendAnalyticsEvent(eventType: 'custom_event', messageId: 'test_message_id', additionalData: {'source': 'manual_test'});
      _addEventLog('Custom analytics sent');
    } catch (e) {
      _addEventLog('Analytics error: $e');
    }
  }

  Future<void> _forceTokenRefresh() async {
    try {
      // Firebase SDK'da token refresh'i manuel olarak tetikleme özelliği yok
      // Ama simulation için eski token'ı alıp onTokenRefreshed çağırabiliriz
      final currentToken = await FcmManager().getToken();
      if (currentToken != null) {
        // Simulate token refresh - gerçek uygulamada bu Firebase tarafından otomatik yapılır
        await _tokenHandler.onTokenRefreshed(currentToken, '${currentToken}_refreshed_${DateTime.now().millisecondsSinceEpoch}');
        _addEventLog('Token refresh simulation completed');
      }
    } catch (e) {
      _addEventLog('Force token refresh error: $e');
    }
  }

  @override
  void dispose() {
    _tokenSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('FCM Manager Example'), backgroundColor: Colors.blue),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FCM Token:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(_fcmToken ?? 'No token yet', style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(onPressed: _refreshToken, child: Text('Refresh Token')),
                        SizedBox(width: 8),
                        ElevatedButton(onPressed: _requestPermissions, child: Text('Request Permissions')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Controls:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            setState(() {
                              _notificationsEnabled = value ?? true;
                            });
                          },
                        ),
                        Text('Notifications Enabled'),
                      ],
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton(onPressed: _updatePreferences, child: Text('Update Preferences')),
                        ElevatedButton(onPressed: _sendCustomAnalytics, child: Text('Send Analytics')),
                        ElevatedButton(onPressed: _forceTokenRefresh, child: Text('Force Token Refresh')),
                        ElevatedButton(onPressed: _logout, child: Text('Logout')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Expanded(child: _buildEventLog()),
          ],
        ),
      ),
    );
  }

  Widget _buildEventLog() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event Log:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _eventLog.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(_eventLog[index], style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: Center(child: Text('Profile Page\n\nBu sayfa bildirimle yönlendirme testi için.')),
    );
  }
}

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat')),
      body: Center(child: Text('Chat Page\n\nBu sayfa bildirimle yönlendirme testi için.')),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Center(child: Text('Settings Page\n\nBu sayfa bildirimle yönlendirme testi için.')),
    );
  }
}
