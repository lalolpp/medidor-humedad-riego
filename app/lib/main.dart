import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:medidor_humedad/screens/home_screen.dart';
import 'package:medidor_humedad/screens/login_screen.dart';
import 'package:medidor_humedad/services/app_firebase.dart';
import 'package:medidor_humedad/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppFirebase.initialize();
  runApp(const MedidorHumedadApp());
}

class MedidorHumedadApp extends StatelessWidget {
  const MedidorHumedadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medidor de Humedad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppFirebase.configured) return const LoginScreen();
    return StreamBuilder<User?>(
      stream: AuthService.instance.userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        return const HomeScreen();
      },
    );
  }
}
