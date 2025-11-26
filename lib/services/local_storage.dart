import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String _lastCityKey = 'last_city';
  static const String _weatherHistoryKey = 'weather_history';

  static Future<void> saveLastCity(String cityName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCityKey, cityName);
  }

  static Future<String?> getLastCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastCityKey);
  }

  // Add this method to get SharedPreferences instance
  static Future<SharedPreferences> getPrefs() async {
    return await SharedPreferences.getInstance();
  }
}