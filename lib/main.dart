import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flowchart_thesis/config/constants/theme_switch.dart';
import 'package:flowchart_thesis/screens/settings/widgets/settings_provider.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_repository/user_repository.dart';
import 'config/firebase/firebase_options.dart';
import 'config/services/gemini_service.dart';
import 'myapp.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  setUrlStrategy(const HashUrlStrategy());
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(seconds: 10),
    minimumFetchInterval: const Duration(hours: 1),
  ));
  await remoteConfig.fetchAndActivate();

  // Inizializza GeminiService per l'AI Chat
  await GeminiService.instance.initialize();

  final googleClientId = remoteConfig.getString('google_web_client_id');
  if (googleClientId.isNotEmpty) {
    FirebaseUIAuth.configureProviders([
      GoogleProvider(clientId: googleClientId),
    ]);
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          Provider<UserRepository>(
            create: (_) => FirebaseUserRepo(googleClientId: googleClientId),
          ),
        ],
        child: const MyApp(),
      ),
    );
  } else {
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: const MyApp(),
      ),
    );
  }
}