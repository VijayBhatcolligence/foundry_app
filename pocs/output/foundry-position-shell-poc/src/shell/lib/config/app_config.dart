// Simple Backend Configuration
// Purpose: Centralized backend URL configuration

class AppConfig {
  // Backend Configuration
  // Flutter native code CAN reach the real backend (no WebView restrictions)
  static const String BACKEND_URL = 'http://192.168.0.163:3000';
  static const String BACKEND_API_BASE = '$BACKEND_URL/api';

  // Convenience Getters
  static String get transactionsUrl => '$BACKEND_API_BASE/transactions';
}
