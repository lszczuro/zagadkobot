import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyModelPath = 'selected_model_path';

  static Future<String?> getModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyModelPath);
  }

  static Future<void> saveModelPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyModelPath, path);
  }
}
