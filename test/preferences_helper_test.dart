import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triviapp/data/preferences_helper.dart';

void main() {
  group('Preferences Helper Tests', () {
    // This runs before every single test to ensure a clean slate
    setUp(() async {
      // Simulate an empty device storage
      SharedPreferences.setMockInitialValues({});
      await PreferencesHelper.init();
    });

    test('isFirstTime should default to true when no data exists', () {
      final isFirst = PreferencesHelper.isFirstTime;
      expect(isFirst, true);
    });

    test('setFirstTimeCompleted should change isFirstTime to false', () async {
      await PreferencesHelper.setFirstTimeCompleted();
      final isFirst = PreferencesHelper.isFirstTime;

      expect(isFirst, false);
    });

    test('nickname should default to Anonymous', () {
      final nickname = PreferencesHelper.nickname;
      expect(nickname, 'Anonymous');
    });

    test('setNickname should save and return the new nickname', () async {
      await PreferencesHelper.setNickname('FlutterMaster');
      final nickname = PreferencesHelper.nickname;

      expect(nickname, 'FlutterMaster');
    });

    // --- Session Token Tests ---
    test('sessionToken should default to null when no data exists', () {
      final token = PreferencesHelper.sessionToken;
      expect(token, isNull);
    });

    test('setSessionToken should save the session token', () async {
      await PreferencesHelper.setSessionToken('mock_token_123');
      final token = PreferencesHelper.sessionToken;

      expect(token, 'mock_token_123');
    });

    test('clearSessionToken should remove the session token', () async {
      await PreferencesHelper.setSessionToken('mock_token_123');
      await PreferencesHelper.clearSessionToken();
      final token = PreferencesHelper.sessionToken;

      expect(token, isNull);
    });

    // --- Notifications Enabled Tests ---
    test('notificationsEnabled should default to true when no data exists', () {
      final enabled = PreferencesHelper.notificationsEnabled;
      expect(enabled, true);
    });

    test('setNotificationsEnabled should save the toggle state', () async {
      await PreferencesHelper.setNotificationsEnabled(false);
      final enabled = PreferencesHelper.notificationsEnabled;

      expect(enabled, false);
    });

    // --- Last Notification Time Tests ---
    test('getLastNotificationTime should default to 0 when no data exists', () {
      final lastTime = PreferencesHelper.getLastNotificationTime(9);
      expect(lastTime, 0);
    });

    test('setLastNotificationTime should save the timestamp for a specific category', () async {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await PreferencesHelper.setLastNotificationTime(9, timestamp);
      final lastTime = PreferencesHelper.getLastNotificationTime(9);

      expect(lastTime, timestamp);

      // Verify it doesn't affect other categories
      final otherCategoryTime = PreferencesHelper.getLastNotificationTime(10);
      expect(otherCategoryTime, 0);
    });
  });
}
