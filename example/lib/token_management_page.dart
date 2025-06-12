import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ogzfirebasemanager/ogzfirebasemanager.dart';

import 'token_handler_example.dart';

/// Token işlemlerini gösteren örnek sayfa
class TokenManagementPage extends StatefulWidget {
  const TokenManagementPage({super.key});

  @override
  State<TokenManagementPage> createState() => _TokenManagementPageState();
}

class _TokenManagementPageState extends State<TokenManagementPage> {
  String? _currentToken;
  bool _isLoading = false;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentToken();
    _listenToTokenChanges();
  }

  /// Mevcut token'ı yükle
  void _loadCurrentToken() async {
    setState(() => _isLoading = true);

    try {
      // FcmManager'dan token al
      final token = await FcmManager().getToken();
      setState(() {
        _currentToken = token;
        _addLog('Token yüklendi: ${token?.substring(0, 20) ?? 'null'}...');
      });
    } catch (e) {
      _addLog('Token yükleme hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Token değişikliklerini dinle
  void _listenToTokenChanges() {
    FcmManager().onTokenRefresh.listen((newToken) {
      setState(() {
        _currentToken = newToken;
        _addLog('Token otomatik güncellendi: ${newToken.substring(0, 20)}...');
      });
    });
  }

  /// Log ekle
  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '${DateTime.now().toString().substring(11, 19)}: $message');
      if (_logs.length > 10) _logs.removeLast();
    });
  }

  /// Token'ı manuel refresh et
  void _refreshToken() async {
    setState(() => _isLoading = true);
    _addLog('Manuel token refresh başlatıldı...');

    try {
      final newToken = await TokenService().refreshToken();
      if (newToken != null) {
        setState(() => _currentToken = newToken);
        _addLog('Manuel refresh başarılı');
      } else {
        _addLog('Manuel refresh başarısız');
      }
    } catch (e) {
      _addLog('Manuel refresh hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Token'ı panoya kopyala
  void _copyToken() {
    if (_currentToken != null) {
      Clipboard.setData(ClipboardData(text: _currentToken!));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token panoya kopyalandı')));
      _addLog('Token panoya kopyalandı');
    }
  }

  /// Logout işlemi
  void _logout() async {
    setState(() => _isLoading = true);
    _addLog('Logout işlemi başlatıldı...');

    try {
      final success = await TokenService().logout();
      if (success) {
        setState(() => _currentToken = null);
        _addLog('Logout başarılı - Token silindi');

        // Ana sayfaya dön
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        _addLog('Logout başarısız');
      }
    } catch (e) {
      _addLog('Logout hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Token'ı backend'e manuel gönder
  void _sendTokenToBackend() async {
    if (_currentToken == null) {
      _addLog('Gönderilecek token yok');
      return;
    }

    setState(() => _isLoading = true);
    _addLog('Token backend\'e gönderiliyor...');

    try {
      // Token handler üzerinden backend'e gönder
      final tokenHandler = MyTokenHandler();
      final success = await tokenHandler.onTokenReceived(_currentToken!, userId: 'user123');

      if (success) {
        _addLog('Token backend\'e başarıyla gönderildi');
      } else {
        _addLog('Token backend\'e gönderilemedi');
      }
    } catch (e) {
      _addLog('Backend gönderme hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Token Yönetimi'), backgroundColor: Colors.blue[600], foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Token Bilgi Kartı
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        const Text('FCM Token', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_currentToken != null) ...[
                      Text(
                        'Token (ilk 50 karakter):',
                        style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          _currentToken!.length > 50 ? '${_currentToken!.substring(0, 50)}...' : _currentToken!,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Token Uzunluğu: ${_currentToken!.length} karakter', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: const Text('Token henüz alınmadı', style: TextStyle(color: Colors.orange)),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Aksiyon Butonları
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loadCurrentToken,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Token Yükle'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _refreshToken,
                      icon: const Icon(Icons.autorenew),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _currentToken != null ? _copyToken : null,
                      icon: const Icon(Icons.copy),
                      label: const Text('Kopyala'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _sendTokenToBackend,
                      icon: const Icon(Icons.send),
                      label: const Text('Backend\'e Gönder'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[600]),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout (Token Sil)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white),
              ),
            ],

            const SizedBox(height: 24),

            // Log Kartı
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.list_alt, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          const Text('İşlem Logları', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => setState(() => _logs.clear()),
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Temizle'),
                          ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: _logs.isEmpty
                            ? const Center(
                                child: Text('Henüz log yok', style: TextStyle(color: Colors.grey)),
                              )
                            : ListView.builder(
                                itemCount: _logs.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    margin: const EdgeInsets.only(bottom: 2),
                                    decoration: BoxDecoration(
                                      color: index.isEven ? Colors.grey[50] : Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(_logs[index], style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
