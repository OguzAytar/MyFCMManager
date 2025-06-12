import 'package:flutter/material.dart';
import 'package:ogzfirebasemanager/ogzfirebasemanager.dart';

/// Topic subscription durumunu kontrol etme ve yönetme sayfası
class TopicStatusPage extends StatefulWidget {
  const TopicStatusPage({super.key});

  @override
  State<TopicStatusPage> createState() => _TopicStatusPageState();
}

class _TopicStatusPageState extends State<TopicStatusPage> {
  bool _isLoading = false;
  Map<String, bool> _topicStatuses = {};
  Set<String> _subscribedTopics = {};
  final List<String> _logs = [];
  
  // Test edilecek topic'ler
  final List<String> _availableTopics = [
    'news',
    'sports', 
    'weather',
    'tech',
    'finance',
    'health',
    'entertainment',
    'breaking-news'
  ];

  @override
  void initState() {
    super.initState();
    _loadTopicStatuses();
  }

  /// Topic durumlarını yükle
  void _loadTopicStatuses() async {
    setState(() => _isLoading = true);
    _addLog('Topic durumları yükleniyor...');

    try {
      // Tüm topic'ler için subscription durumunu kontrol et
      final statuses = FcmManager().getTopicSubscriptionStatuses(_availableTopics);
      final subscribedTopics = FcmManager().getAllSubscribedTopics();
      
      setState(() {
        _topicStatuses = statuses;
        _subscribedTopics = subscribedTopics;
      });

      _addLog('Topic durumları yüklendi: ${subscribedTopics.length} abone topic');
      _addLog('Abone topic\'ler: ${subscribedTopics.join(", ")}');
    } catch (e) {
      _addLog('Topic durumu yükleme hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Topic'e abone ol
  void _subscribeToTopic(String topic) async {
    setState(() => _isLoading = true);
    _addLog('$topic topic\'ine abone oluyor...');

    try {
      final success = await FcmManager().subscribeToTopic(topic);
      if (success) {
        _addLog('✅ $topic topic\'ine başarıyla abone olundu');
        _loadTopicStatuses(); // Durumları güncelle
      } else {
        _addLog('❌ $topic topic aboneliği başarısız');
      }
    } catch (e) {
      _addLog('❌ $topic abonelik hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Topic'ten abonelikten çık
  void _unsubscribeFromTopic(String topic) async {
    setState(() => _isLoading = true);
    _addLog('$topic topic\'inden abonelikten çıkıyor...');

    try {
      final success = await FcmManager().unsubscribeFromTopic(topic);
      if (success) {
        _addLog('✅ $topic topic\'inden başarıyla abonelikten çıkıldı');
        _loadTopicStatuses(); // Durumları güncelle
      } else {
        _addLog('❌ $topic abonelikten çıkma başarısız');
      }
    } catch (e) {
      _addLog('❌ $topic abonelikten çıkma hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Çoklu topic aboneliği
  void _subscribeToMultiple() async {
    setState(() => _isLoading = true);
    
    // Abone olmadığımız topic'leri seç
    final unsubscribedTopics = _availableTopics
        .where((topic) => !(_topicStatuses[topic] ?? false))
        .take(3)
        .toList();
    
    if (unsubscribedTopics.isEmpty) {
      _addLog('Abone olunacak topic bulunamadı');
      setState(() => _isLoading = false);
      return;
    }

    _addLog('Çoklu abonelik başlatıldı: ${unsubscribedTopics.join(", ")}');

    try {
      final results = await FcmManager().subscribeToMultipleTopics(unsubscribedTopics);
      
      int successCount = 0;
      results.forEach((topic, success) {
        if (success) {
          successCount++;
          _addLog('✅ $topic: başarılı');
        } else {
          _addLog('❌ $topic: başarısız');
        }
      });

      _addLog('Çoklu abonelik tamamlandı: $successCount/${unsubscribedTopics.length}');
      _loadTopicStatuses();
    } catch (e) {
      _addLog('❌ Çoklu abonelik hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Çoklu topic abonelikten çıkma
  void _unsubscribeFromMultiple() async {
    setState(() => _isLoading = true);
    
    // Abone olduğumuz topic'leri seç
    final subscribedTopicsList = _subscribedTopics.take(3).toList();
    
    if (subscribedTopicsList.isEmpty) {
      _addLog('Abonelikten çıkılacak topic bulunamadı');
      setState(() => _isLoading = false);
      return;
    }

    _addLog('Çoklu abonelikten çıkma başlatıldı: ${subscribedTopicsList.join(", ")}');

    try {
      final results = await FcmManager().unsubscribeFromMultipleTopics(subscribedTopicsList);
      
      int successCount = 0;
      results.forEach((topic, success) {
        if (success) {
          successCount++;
          _addLog('✅ $topic: başarılı');
        } else {
          _addLog('❌ $topic: başarısız');
        }
      });

      _addLog('Çoklu abonelikten çıkma tamamlandı: $successCount/${subscribedTopicsList.length}');
      _loadTopicStatuses();
    } catch (e) {
      _addLog('❌ Çoklu abonelikten çıkma hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Topic durumlarını göster
  void _showTopicReport() {
    final report = FcmManager().getTopicSubscriptionReport();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Topic Subscription Raporu'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Toplam Abone Sayısı: ${report['totalCount']}'),
              SizedBox(height: 8),
              Text('Rapor Zamanı: ${report['timestamp']}'),
              SizedBox(height: 8),
              Text('Initialize Durumu: ${report['isInitialized']}'),
              SizedBox(height: 16),
              Text('Abone Olunan Topic\'ler:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...((report['topics'] as List<String>).map((topic) => Text('• $topic'))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tamam'),
          ),
        ],
      ),
    );
  }

  /// Log ekle
  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '${DateTime.now().toString().substring(11, 19)}: $message');
      if (_logs.length > 20) _logs.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Topic Status Control'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Durum kartı
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Topic Subscription Durumu',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Toplam Abone: ${FcmManager().getSubscribedTopicCount()}'),
                    Text('FCM Manager: ${FcmManager().isInitialized ? "Aktif" : "İnaktif"}'),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),

            // Aksiyon butonları
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadTopicStatuses,
                  icon: Icon(Icons.refresh),
                  label: Text('Yenile'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _subscribeToMultiple,
                  icon: Icon(Icons.add_circle),
                  label: Text('Çoklu Abone'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _unsubscribeFromMultiple,
                  icon: Icon(Icons.remove_circle),
                  label: Text('Çoklu Çık'),
                ),
                ElevatedButton.icon(
                  onPressed: _showTopicReport,
                  icon: Icon(Icons.analytics),
                  label: Text('Rapor'),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Topic listesi
            Expanded(
              child: Row(
                children: [
                  // Sol: Topic'ler ve durumları
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Topic\'ler',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _availableTopics.length,
                            itemBuilder: (context, index) {
                              final topic = _availableTopics[index];
                              final isSubscribed = _topicStatuses[topic] ?? false;
                              
                              return Card(
                                margin: EdgeInsets.symmetric(vertical: 2),
                                child: ListTile(
                                  leading: Icon(
                                    isSubscribed ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: isSubscribed ? Colors.green : Colors.grey,
                                  ),
                                  title: Text(topic),
                                  subtitle: Text(isSubscribed ? 'Abone' : 'Abone değil'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isSubscribed)
                                        IconButton(
                                          onPressed: _isLoading ? null : () => _subscribeToTopic(topic),
                                          icon: Icon(Icons.add),
                                          tooltip: 'Abone ol',
                                        ),
                                      if (isSubscribed)
                                        IconButton(
                                          onPressed: _isLoading ? null : () => _unsubscribeFromTopic(topic),
                                          icon: Icon(Icons.remove),
                                          tooltip: 'Abonelikten çık',
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(width: 16),
                  
                  // Sağ: Log'lar
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'İşlem Log\'ları',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.builder(
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    _logs[index],
                                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Loading indicator
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
