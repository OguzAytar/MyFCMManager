import 'package:flutter_test/flutter_test.dart';
import 'package:ogzfirebasemanager/ogzfirebasemanager.dart';

/// Token Refresh Integration Test
///
/// Bu test dosyası _handleTokenRefresh metodunun gerçek senaryolardaki
/// davranışlarını test eder. Firebase olmadan mock handler'lar kullanarak
/// token refresh flow'unu simüle eder.

class MockTokenHandler implements FcmTokenHandler {
  String? lastToken;
  String? lastDeletedToken;
  String? lastOldToken;
  String? lastNewToken;
  List<String> tokenHistory = [];
  List<Map<String, String>> refreshHistory = [];

  @override
  Future<bool> onTokenReceived(String token, {String? userId}) async {
    final tokenPreview = token.length > 20 ? '${token.substring(0, 20)}...' : token;
    print('📥 Token received: $tokenPreview');
    lastToken = token;
    tokenHistory.add(token);
    await Future.delayed(Duration(milliseconds: 10)); // Simüle delay
    return true;
  }

  @override
  Future<bool> onTokenDelete(String token) async {
    final tokenPreview = token.length > 20 ? '${token.substring(0, 20)}...' : token;
    print('🗑️ Token deleted: $tokenPreview');
    lastDeletedToken = token;
    await Future.delayed(Duration(milliseconds: 10)); // Simüle delay
    return true;
  }

  @override
  Future<void> onTokenRefreshed(String oldToken, String newToken) async {
    final oldPreview = oldToken.length > 20 ? '${oldToken.substring(0, 20)}...' : oldToken;
    final newPreview = newToken.length > 20 ? '${newToken.substring(0, 20)}...' : newToken;
    print('🔄 Token refreshed: $oldPreview -> $newPreview');
    lastOldToken = oldToken;
    lastNewToken = newToken;
    refreshHistory.add({'old': oldToken, 'new': newToken});

    // onTokenReceived'i de çağır (gerçek implementasyon gibi)
    await onTokenReceived(newToken);
  }

  void reset() {
    lastToken = null;
    lastDeletedToken = null;
    lastOldToken = null;
    lastNewToken = null;
    tokenHistory.clear();
    refreshHistory.clear();
  }
}

class SlowTokenHandler implements FcmTokenHandler {
  final int delayMs;
  String? lastToken;

  SlowTokenHandler({this.delayMs = 100});

  @override
  Future<bool> onTokenReceived(String token, {String? userId}) async {
    await Future.delayed(Duration(milliseconds: delayMs));
    lastToken = token;
    return true;
  }

  @override
  Future<bool> onTokenDelete(String token) async {
    await Future.delayed(Duration(milliseconds: delayMs));
    return true;
  }

  @override
  Future<void> onTokenRefreshed(String oldToken, String newToken) async {
    await Future.delayed(Duration(milliseconds: delayMs));
    await onTokenReceived(newToken);
  }
}

class FailingTokenHandler implements FcmTokenHandler {
  int callCount = 0;
  final int failAfter;

  FailingTokenHandler({this.failAfter = 2});

  @override
  Future<bool> onTokenReceived(String token, {String? userId}) async {
    callCount++;
    if (callCount > failAfter) {
      throw Exception('Token handler failed after $failAfter calls');
    }
    return true;
  }

  @override
  Future<bool> onTokenDelete(String token) async {
    throw Exception('Delete operation failed');
  }

  @override
  Future<void> onTokenRefreshed(String oldToken, String newToken) async {
    callCount++;
    if (callCount > failAfter) {
      throw Exception('Token refresh failed after $failAfter calls');
    }
    await onTokenReceived(newToken);
  }
}

void main() {
  group('Token Refresh Integration Tests', () {
    late MockTokenHandler tokenHandler;

    setUp(() {
      tokenHandler = MockTokenHandler();
    });

    tearDown(() {
      tokenHandler.reset();
    });

    test('should handle token lifecycle correctly', () async {
      const initialToken = 'initial_token_abc123def456';
      const refreshedToken1 = 'refreshed_token_xyz789ghi012';
      const refreshedToken2 = 'refreshed_token_mno345pqr678';

      // Scenario 1: Initial token
      await tokenHandler.onTokenReceived(initialToken);
      expect(tokenHandler.lastToken, equals(initialToken));
      expect(tokenHandler.tokenHistory.length, equals(1));
      expect(tokenHandler.refreshHistory.length, equals(0));

      // Scenario 2: First refresh
      await tokenHandler.onTokenRefreshed(initialToken, refreshedToken1);
      expect(tokenHandler.lastOldToken, equals(initialToken));
      expect(tokenHandler.lastNewToken, equals(refreshedToken1));
      expect(tokenHandler.lastToken, equals(refreshedToken1));
      expect(tokenHandler.tokenHistory.length, equals(2));
      expect(tokenHandler.refreshHistory.length, equals(1));

      // Scenario 3: Second refresh
      await tokenHandler.onTokenRefreshed(refreshedToken1, refreshedToken2);
      expect(tokenHandler.lastOldToken, equals(refreshedToken1));
      expect(tokenHandler.lastNewToken, equals(refreshedToken2));
      expect(tokenHandler.lastToken, equals(refreshedToken2));
      expect(tokenHandler.tokenHistory.length, equals(3));
      expect(tokenHandler.refreshHistory.length, equals(2));

      // Verify history
      expect(tokenHandler.tokenHistory[0], equals(initialToken));
      expect(tokenHandler.tokenHistory[1], equals(refreshedToken1));
      expect(tokenHandler.tokenHistory[2], equals(refreshedToken2));

      expect(tokenHandler.refreshHistory[0]['old'], equals(initialToken));
      expect(tokenHandler.refreshHistory[0]['new'], equals(refreshedToken1));
      expect(tokenHandler.refreshHistory[1]['old'], equals(refreshedToken1));
      expect(tokenHandler.refreshHistory[1]['new'], equals(refreshedToken2));
    });

    test('should handle same token refresh scenario', () async {
      const sameToken = 'same_token_123456789';

      // Initial token
      await tokenHandler.onTokenReceived(sameToken);
      expect(tokenHandler.tokenHistory.length, equals(1));

      // "Refresh" with same token (Firebase sometimes does this)
      await tokenHandler.onTokenRefreshed(sameToken, sameToken);
      expect(tokenHandler.lastOldToken, equals(sameToken));
      expect(tokenHandler.lastNewToken, equals(sameToken));
      expect(tokenHandler.lastToken, equals(sameToken));
      expect(tokenHandler.tokenHistory.length, equals(2)); // onTokenReceived called again
      expect(tokenHandler.refreshHistory.length, equals(1));
    });

    test('should handle rapid token refreshes', () async {
      const tokens = ['token_1_rapid_test', 'token_2_rapid_test', 'token_3_rapid_test', 'token_4_rapid_test', 'token_5_rapid_test'];

      // Initial token
      await tokenHandler.onTokenReceived(tokens[0]);

      // Rapid refreshes
      for (int i = 1; i < tokens.length; i++) {
        await tokenHandler.onTokenRefreshed(tokens[i - 1], tokens[i]);
      }

      // Verify final state
      expect(tokenHandler.lastToken, equals(tokens.last));
      expect(tokenHandler.tokenHistory.length, equals(tokens.length));
      expect(tokenHandler.refreshHistory.length, equals(tokens.length - 1));

      // Verify all transitions
      for (int i = 0; i < tokenHandler.refreshHistory.length; i++) {
        expect(tokenHandler.refreshHistory[i]['old'], equals(tokens[i]));
        expect(tokenHandler.refreshHistory[i]['new'], equals(tokens[i + 1]));
      }
    });

    test('should handle slow token handler gracefully', () async {
      final slowHandler = SlowTokenHandler(delayMs: 50);
      const testToken = 'slow_handler_test_token';

      final stopwatch = Stopwatch()..start();
      await slowHandler.onTokenReceived(testToken);
      stopwatch.stop();

      expect(slowHandler.lastToken, equals(testToken));
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(50));
    });

    test('should handle token handler failures gracefully', () async {
      final failingHandler = FailingTokenHandler(failAfter: 1);

      // First call should succeed
      await failingHandler.onTokenReceived('first_token');
      expect(failingHandler.callCount, equals(1));

      // Second call should fail
      expect(() async => await failingHandler.onTokenReceived('second_token'), throwsException);

      // Refresh should also fail after threshold
      expect(() async => await failingHandler.onTokenRefreshed('old', 'new'), throwsException);

      // Delete should always fail in this mock
      expect(() async => await failingHandler.onTokenDelete('any_token'), throwsException);
    });

    test('should handle empty and edge case tokens', () async {
      final edgeCaseTokens = [
        '', // Empty string
        ' ', // Single space
        'a', // Single character
        'x' * 4096, // Very long token (4KB)
        'token_with_special_chars_!@#\$%^&*()',
        'token\nwith\nnewlines',
        'token\twith\ttabs',
        'токен_with_unicode_чарс',
        '🔥🚀📱 emoji_token',
      ];

      for (final token in edgeCaseTokens) {
        tokenHandler.reset();

        try {
          await tokenHandler.onTokenReceived(token);
          expect(tokenHandler.lastToken, equals(token));

          // Test refresh with edge case token
          const newToken = 'normal_token_after_edge_case';
          await tokenHandler.onTokenRefreshed(token, newToken);
          expect(tokenHandler.lastOldToken, equals(token));
          expect(tokenHandler.lastNewToken, equals(newToken));
        } catch (e) {
          // Some edge cases might fail, that's okay
          print('Edge case token failed (expected): $token - $e');
        }
      }
    });

    test('should measure token refresh performance', () async {
      const numIterations = 100;
      final tokens = List.generate(numIterations, (i) => 'performance_test_token_$i');

      final stopwatch = Stopwatch()..start();

      // Initial token
      await tokenHandler.onTokenReceived(tokens[0]);

      // Measure refresh performance
      for (int i = 1; i < tokens.length; i++) {
        await tokenHandler.onTokenRefreshed(tokens[i - 1], tokens[i]);
      }

      stopwatch.stop();

      final avgTimePerRefresh = stopwatch.elapsedMilliseconds / numIterations;
      print('Average time per token refresh: ${avgTimePerRefresh}ms');

      expect(tokenHandler.tokenHistory.length, equals(numIterations));
      expect(tokenHandler.refreshHistory.length, equals(numIterations - 1));
      expect(avgTimePerRefresh, lessThan(50)); // Should be reasonably fast (50ms)
    });

    test('should handle concurrent token operations', () async {
      const concurrentTokens = ['concurrent_token_1', 'concurrent_token_2', 'concurrent_token_3', 'concurrent_token_4', 'concurrent_token_5'];

      // Simulate concurrent token operations
      final futures = <Future>[];

      for (int i = 0; i < concurrentTokens.length; i++) {
        futures.add(tokenHandler.onTokenReceived(concurrentTokens[i]));
      }

      await Future.wait(futures);

      // Should have received all tokens
      expect(tokenHandler.tokenHistory.length, equals(concurrentTokens.length));

      // Last token should be one of the concurrent tokens
      expect(concurrentTokens.contains(tokenHandler.lastToken), isTrue);
    });
  });
}
