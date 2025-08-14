import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flowchart_thesis/config/constants/theme_switch.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:user_repository/user_repository.dart';
import 'config/firebase/firebase_options.dart';
import 'myapp.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setUrlStrategy(const HashUrlStrategy());
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Configura una sola volta i provider di autenticazione
  FirebaseUIAuth.configureProviders([
    GoogleProvider(
      clientId: '641983601905-5m4om4subv34s6irtpejhjpd9u3d41e1.apps.googleusercontent.com',
    ),
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(FirebaseUserRepo()),
    ),
  );
}
