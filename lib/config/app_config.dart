import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App configuration loaded from environment variables
class AppConfig {
  /// DeepInfra API key (recommended AI provider)
  static String? get deepInfraApiKey => dotenv.env['DEEPINFRA_API_KEY'];
  
  /// Together.ai API key (alternative AI provider)
  static String? get togetherApiKey => dotenv.env['TOGETHER_API_KEY'];
  
  /// Supabase configuration
  static String? get supabaseUrl => dotenv.env['SUPABASE_URL'];
  static String? get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'];
  
  /// Returns the configured AI API key (DeepInfra takes priority)
  static String? get aiApiKey => deepInfraApiKey ?? togetherApiKey;
  
  /// Returns the API base URL based on which key is configured
  static String get aiBaseUrl {
    if (deepInfraApiKey != null) {
      return 'https://api.deepinfra.com/v1/openai';
    } else if (togetherApiKey != null) {
      return 'https://api.together.xyz/v1';
    }
    return 'https://api.deepinfra.com/v1/openai'; // Default
  }
  
  /// Returns the model to use based on provider
  static String get aiModel {
    if (togetherApiKey != null && deepInfraApiKey == null) {
      return 'meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo';
    }
    return 'meta-llama/Meta-Llama-3.1-70B-Instruct';
  }
  
  /// Whether the app is running in demo mode (no AI API configured)
  static bool get isDemoMode => aiApiKey == null || aiApiKey!.isEmpty;
  
  /// Whether Supabase is configured
  static bool get hasSupabase => 
      supabaseUrl != null && 
      supabaseUrl!.isNotEmpty && 
      supabaseAnonKey != null && 
      supabaseAnonKey!.isNotEmpty;
}
