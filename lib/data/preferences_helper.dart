import 'package:shared_preferences/shared_preferences.dart';

class PreferencesHelper {
  static late SharedPreferences _prefs;

  // Initialize the shared preferences instance.
  // This must be called in the main() function before running the app.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- 1. API Session Token ---

  // Get the current session token (returns null if it doesn't exist)
  static String? get sessionToken => _prefs.getString('session_token');

  // Save a new session token
  static Future<bool> setSessionToken(String token) async {
    return await _prefs.setString('session_token', token);
  }

  // Remove the session token (useful when we need a fresh start)
  static Future<bool> clearSessionToken() async {
    return await _prefs.remove('session_token');
  }

  // --- 2. First Time / Onboarding Status ---

  // Check if it's the user's first time opening the app (defaults to true)
  static bool get isFirstTime => _prefs.getBool('is_first_time') ?? true;

  // Call this when the user finishes the initial setup
  static Future<bool> setFirstTimeCompleted() async {
    return await _prefs.setBool('is_first_time', false);
  }

  // --- 3. User Nickname ---

  // Get the nickname (defaults to 'Anonymous')
  static String get nickname => _prefs.getString('nickname') ?? 'Anonymous';

  // Save a new nickname
  static Future<bool> setNickname(String name) async {
    return await _prefs.setString('nickname', name);
  }

  // --- 4. Global Notifications Toggle ---

  // Check if notifications are enabled globally (defaults to true)
  static bool get notificationsEnabled =>
      _prefs.getBool('notifications_enabled') ?? true;

  // Turn all notifications on or off
  static Future<bool> setNotificationsEnabled(bool enabled) async {
    return await _prefs.setBool('notifications_enabled', enabled);
  }
}
