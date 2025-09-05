import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

class TestUserCreator {
  static final TestUserCreator _instance = TestUserCreator._internal();
  factory TestUserCreator() => _instance;
  TestUserCreator._internal();

  SupabaseClient get _client => SupabaseConfig.client;

  // Test kullanıcıları oluştur
  Future<void> createTestUsers() async {
    final testUsers = [
      {'name': 'Test User 1', 'email': 'test1@example.com', 'password': '123456'},
      {'name': 'Test User 2', 'email': 'test2@example.com', 'password': '123456'},
      {'name': 'Test User 3', 'email': 'test3@example.com', 'password': '123456'},
      {'name': 'Test User 4', 'email': 'test4@example.com', 'password': '123456'},
      {'name': 'Test User 5', 'email': 'test5@example.com', 'password': '123456'},
      {'name': 'Test User 6', 'email': 'test6@example.com', 'password': '123456'},
      {'name': 'Test User 7', 'email': 'test7@example.com', 'password': '123456'},
      {'name': 'Test User 8', 'email': 'test8@example.com', 'password': '123456'},
      {'name': 'Test User 9', 'email': 'test9@example.com', 'password': '123456'},
      {'name': 'Test User 10', 'email': 'test10@example.com', 'password': '123456'},
    ];

    for (final user in testUsers) {
      try {
        // Kullanıcıyı Supabase Auth'da oluştur
        final authResponse = await _client.auth.signUp(
          email: user['email']!,
          password: user['password']!,
        );

        if (authResponse.user != null) {
          final userId = authResponse.user!.id;
          
          // Kullanıcı profilini oluştur
          await _client.from('users').insert({
            'id': userId,
            'email': user['email'],
            'name': user['name'],
            'is_verified': true,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          // Kullanıcıya 1000 jeton ver
          await _client.from('user_tokens').insert({
            'user_id': userId,
            'photo_tokens': 1000,
            'video_tokens': 1000,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          print('✅ Test kullanıcısı oluşturuldu: ${user['name']} (${user['email']})');
        }
      } catch (e) {
        print('❌ Test kullanıcısı oluşturulamadı ${user['name']}: $e');
      }
    }
  }

  // Mevcut kullanıcılara 1000 jeton ver
  Future<void> giveTokensToExistingUsers() async {
    try {
      // Tüm kullanıcıları al
      final usersResponse = await _client.from('users').select('id');
      
      for (final user in usersResponse) {
        final userId = user['id'] as String;
        
        // Kullanıcının token durumunu kontrol et
        final tokenResponse = await _client
            .from('user_tokens')
            .select()
            .eq('user_id', userId)
            .single();
        
        if (tokenResponse != null) {
          // Mevcut tokenları güncelle
          await _client
              .from('user_tokens')
              .update({
                'photo_tokens': 1000,
                'video_tokens': 1000,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', userId);
        } else {
          // Yeni token kaydı oluştur
          await _client.from('user_tokens').insert({
            'user_id': userId,
            'photo_tokens': 1000,
            'video_tokens': 1000,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
        
        print('✅ Token verildi: $userId');
      }
    } catch (e) {
      print('❌ Token verme hatası: $e');
    }
  }
}
