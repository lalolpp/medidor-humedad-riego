import 'package:flutter/material.dart';
import 'package:medidor_humedad/screens/home_screen.dart';

void main() {
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
      home: const HomeScreen(),
    );
  }
}
