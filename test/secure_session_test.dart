import 'package:arabic_academy/core/secure_session_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Session removal clears only encrypted authentication, preserving learning progress',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({
        'completed': ['l1'],
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = SecureSessionStorage();
      await storage.initialize();
      expect(await storage.hasAccessToken(), isFalse);
      await storage.persistSession('test-session-value');
      expect(await storage.accessToken(), 'test-session-value');
      expect(prefs.getString('bayna_supabase_session_v1'), isNull);
      await storage.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);
      expect(prefs.getStringList('completed'), ['l1']);
    },
  );
}
