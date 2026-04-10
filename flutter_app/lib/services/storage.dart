import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/data.dart';

const String kDefaultApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

class StorageService {
  static const String _dataKey = 'cardBookkeeping_v4';
  static const String _legacyDataKey = 'cardBookkeeping_v3';
  static const String _roleKey = 'cardBookkeeping_role';
  static const String _configKey = 'cardBookkeeping_config';

  static Future<AppData> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dataKey) ?? prefs.getString(_legacyDataKey);
    if (raw == null) return AppData.initial();
    return AppData.fromJsonString(raw);
  }

  static Future<void> saveData(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dataKey, data.toJsonString());
  }

  static Future<AppConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);
    if (raw == null || raw.isEmpty) {
      return AppConfig(apiBaseUrl: kDefaultApiBaseUrl);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppConfig.fromJson(decoded);
      }
      if (decoded is Map) {
        return AppConfig.fromJson(decoded.map((key, dynamic value) => MapEntry(key.toString(), value)));
      }
      return AppConfig(apiBaseUrl: kDefaultApiBaseUrl);
    } catch (_) {
      return AppConfig(apiBaseUrl: kDefaultApiBaseUrl);
    }
  }

  static Future<void> saveConfig(AppConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<void> setRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  @visibleForTesting
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dataKey);
    await prefs.remove(_legacyDataKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_configKey);
  }
}
