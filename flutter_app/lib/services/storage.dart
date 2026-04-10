import 'package:shared_preferences/shared_preferences.dart';
import '../models/data.dart';

const String kDefaultApiBaseUrl = 'https://card-bookkeeping-api.ywu1286.workers.dev';

class StorageService {
  static const _dataKey = 'cardBookkeeping_v3';
  static const _roleKey = 'myRole';
  static const _pinKey = 'workspacePin';
  static const _apiUrlKey = 'apiUrl';

  static Future<AppData> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dataKey);
    if (raw != null) return AppData.fromJsonString(raw);
    return AppData();
  }

  static Future<void> saveData(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dataKey, data.toJsonString());
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<void> setRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  static Future<String> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) ?? '1234';
  }

  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
  }

  static Future<String> getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiUrlKey) ?? kDefaultApiBaseUrl;
  }

  static Future<void> setApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiUrlKey, url);
  }
}
