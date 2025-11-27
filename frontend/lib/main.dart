import 'package:flutter/material.dart';
import 'package:frontend/screens/dashboard_screen.dart'; // Importiamo la nuova schermata

void main() {
  runApp(const LeverageApp());
}

class LeverageApp extends StatelessWidget {
  const LeverageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leverage',
      debugShowCheckedModeBanner: false, // Rimuove la scritta DEBUG in alto
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00E676),
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00E676),
          secondary: const Color(0xFF03DAC6),
          surface: const Color(0xFF1E1E1E),
        ),
      ),
      home: const DashboardScreen(), // Qui colleghiamo la dashboard
    );
  }
}