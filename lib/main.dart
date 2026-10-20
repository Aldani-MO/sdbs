import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'auth/login.dart';
import 'theme/app_theme.dart';
import 'providers/user_provider.dart';
import 'services/auth_service.dart';
import 'services/transit_service.dart';
import 'services/wallet_service.dart';
import 'services/decision_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => TransitService()),
        Provider(create: (_) => WalletService()),
        Provider(create: (_) => DecisionService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SDBS',
        theme: AppTheme.themeData,
        home: const LoginPage(),
      ),
    );
  }
}
