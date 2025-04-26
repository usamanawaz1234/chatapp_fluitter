import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://qlyfujpydnttbjniitbb.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFseWZ1anB5ZG50dGJqbmlpdGJiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU2ODg2MTUsImV4cCI6MjA2MTI2NDYxNX0.u4rG1vGriECBBkr3iF_TBufI-dyigcrvZdISPfNr-zM';

  static final supabase = Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
