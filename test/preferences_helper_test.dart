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
  });
}
