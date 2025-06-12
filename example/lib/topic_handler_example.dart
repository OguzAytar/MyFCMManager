import 'dart:developer';
import 'package:ogzfirebasemanager/ogzfirebasemanager.dart';

/// Topic işlemleri için örnek handler implementasyonu
/// 
/// Bu sınıf FCM topic abonelik işlemlerini nasıl yöneteceğinizi gösterir.
/// Backend ile senkronizasyon, analytics ve kullanıcı tercihleri için kullanılır.
class MyTopicHandler implements FcmTopicHandler {
  
  // Topic durumlarını local olarak saklamak için
  final Set<String> _subscribedTopics = <String>{};
  
  /// Topic'e abone olduğunda çağrılır
  @override
  Future<void> onTopicSubscribed(String topic, bool success) async {
    try {
      log('📋 Topic subscription: $topic - ${success ? "Başarılı" : "Başarısız"}');
      
      if (success) {
        // Local state'i güncelle
        _subscribedTopics.add(topic);
        
        // Backend'e topic aboneliğini kaydet
        await _saveTopicSubscriptionToBackend(topic);
        
        // Analytics event gönder
        await _sendTopicAnalytics('topic_subscribed', topic);
        
        // Kullanıcı preferences'ı güncelle
        await _updateUserTopicPreferences();
        
        log('✅ Topic aboneliği işlemleri tamamlandı: $topic');
      } else {
        log('❌ Topic aboneliği başarısız: $topic');
      }
    } catch (e) {
      log('❌ Topic subscription handler hatası: $e');
    }
  }
  
  /// Topic'ten abonelikten çıktığında çağrılır
  @override
  Future<void> onTopicUnsubscribed(String topic, bool success) async {
    try {
      log('📋 Topic unsubscription: $topic - ${success ? "Başarılı" : "Başarısız"}');
      
      if (success) {
        // Local state'i güncelle
        _subscribedTopics.remove(topic);
        
        // Backend'den topic aboneliğini sil
        await _removeTopicSubscriptionFromBackend(topic);
        
        // Analytics event gönder
        await _sendTopicAnalytics('topic_unsubscribed', topic);
        
        // Kullanıcı preferences'ı güncelle
        await _updateUserTopicPreferences();
        
        log('✅ Topic abonelikten çıkma işlemleri tamamlandı: $topic');
      } else {
        log('❌ Topic abonelikten çıkma başarısız: $topic');
      }
    } catch (e) {
      log('❌ Topic unsubscription handler hatası: $e');
    }
  }
  
  /// Bulk topic işlemleri sonrasında çağrılır
  @override
  Future<void> onBulkTopicOperation(Map<String, bool> results, bool isSubscription) async {
    try {
      final operation = isSubscription ? 'Abonelik' : 'Abonelikten çıkma';
      log('📋 Bulk topic $operation sonuçları:');
      
      final successful = <String>[];
      final failed = <String>[];
      
      results.forEach((topic, success) {
        if (success) {
          successful.add(topic);
          if (isSubscription) {
            _subscribedTopics.add(topic);
          } else {
            _subscribedTopics.remove(topic);
          }
        } else {
          failed.add(topic);
        }
        log('  $topic: ${success ? "✅" : "❌"}');
      });
      
      // Backend'e bulk update gönder
      if (successful.isNotEmpty) {
        await _bulkUpdateTopicsToBackend(successful, isSubscription);
      }
      
      // Analytics için bulk event gönder
      await _sendBulkTopicAnalytics(results, isSubscription);
      
      // Kullanıcı preferences'ı güncelle
      await _updateUserTopicPreferences();
      
      log('✅ Bulk topic işlemi tamamlandı: ${successful.length} başarılı, ${failed.length} başarısız');
      
    } catch (e) {
      log('❌ Bulk topic operation handler hatası: $e');
    }
  }
  
  /// Mevcut abone olunan topic'lerin listesini döndürür
  Set<String> getSubscribedTopics() {
    return Set.from(_subscribedTopics);
  }
  
  /// Belirli bir topic'e abone olup olmadığını kontrol eder
  bool isSubscribedToTopic(String topic) {
    return _subscribedTopics.contains(topic);
  }
  
  /// Abone olunan topic sayısını döndürür
  int getSubscribedTopicCount() {
    return _subscribedTopics.length;
  }
  
  // --- Private Helper Methods ---
  
  /// Topic aboneliğini backend'e kaydet
  Future<void> _saveTopicSubscriptionToBackend(String topic) async {
    try {
      // Gerçek API çağrısı örneği:
      /*
      final response = await http.post(
        Uri.parse('https://yourapi.com/user/topics/subscribe'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'topic': topic,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Backend topic subscription failed');
      }
      */
      
      // Test için simülasyon
      await Future.delayed(const Duration(milliseconds: 200));
      log('📤 Topic aboneliği backend\'e kaydedildi: $topic');
      
    } catch (e) {
      log('❌ Backend topic subscription hatası: $e');
      rethrow;
    }
  }
  
  /// Topic aboneliğini backend'den sil
  Future<void> _removeTopicSubscriptionFromBackend(String topic) async {
    try {
      // Gerçek API çağrısı örneği:
      /*
      final response = await http.post(
        Uri.parse('https://yourapi.com/user/topics/unsubscribe'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'topic': topic,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      */
      
      // Test için simülasyon
      await Future.delayed(const Duration(milliseconds: 200));
      log('📤 Topic aboneliği backend\'den silindi: $topic');
      
    } catch (e) {
      log('❌ Backend topic unsubscription hatası: $e');
      rethrow;
    }
  }
  
  /// Bulk topic güncellemesini backend'e gönder
  Future<void> _bulkUpdateTopicsToBackend(List<String> topics, bool isSubscription) async {
    try {
      final action = isSubscription ? 'subscribe' : 'unsubscribe';
      
      // Test için simülasyon
      await Future.delayed(const Duration(milliseconds: 300));
      log('📤 Bulk topic $action backend\'e gönderildi: ${topics.join(", ")}');
      
    } catch (e) {
      log('❌ Bulk topic backend update hatası: $e');
      rethrow;
    }
  }
  
  /// Topic analytics eventi gönder
  Future<void> _sendTopicAnalytics(String eventType, String topic) async {
    try {
      // Firebase Analytics, Mixpanel vs. için
      /*
      await FirebaseAnalytics.instance.logEvent(
        name: eventType,
        parameters: {
          'topic': topic,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      */
      
      // Test için simülasyon
      await Future.delayed(const Duration(milliseconds: 100));
      log('📊 Topic analytics gönderildi: $eventType - $topic');
      
    } catch (e) {
      log('❌ Topic analytics hatası: $e');
    }
  }
  
  /// Bulk topic analytics eventi gönder
  Future<void> _sendBulkTopicAnalytics(Map<String, bool> results, bool isSubscription) async {
    try {
      final eventType = isSubscription ? 'bulk_topic_subscribed' : 'bulk_topic_unsubscribed';
      final successCount = results.values.where((success) => success).length;
      
      // Test için simülasyon
      await Future.delayed(const Duration(milliseconds: 150));
      log('📊 Bulk topic analytics gönderildi: $eventType - $successCount/${results.length} başarılı');
      
    } catch (e) {
      log('❌ Bulk topic analytics hatası: $e');
    }
  }
  
  /// Kullanıcı topic tercihlerini güncelle
  Future<void> _updateUserTopicPreferences() async {
    try {
      // SharedPreferences veya başka local storage'a kaydet
      /*
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('subscribed_topics', _subscribedTopics.toList());
      await prefs.setString('topics_last_updated', DateTime.now().toIso8601String());
      */
      
      // Test için simülasyon
      await Future.delayed(const Duration(milliseconds: 50));
      log('💾 Kullanıcı topic tercihleri güncellendi: ${_subscribedTopics.length} topic');
      
    } catch (e) {
      log('❌ Topic preferences update hatası: $e');
    }
  }
}
