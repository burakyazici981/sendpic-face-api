import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://tdxfwcgqesvgrdqidxik.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkeGZ3Y2dxZXN2Z3JkcWlkeGlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwNTgwOTQsImV4cCI6MjA3MjYzNDA5NH0.b7BQlYkNRb946mH6_-Jj9fAYNkMi6IfWt7QJ-Eal4FQ';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}