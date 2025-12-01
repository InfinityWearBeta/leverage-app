import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/config/theme.dart';
import 'package:frontend/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bcmssszngmhzhcvhwomo.supabase.co',
    // ECCOLA QUI SOTTO:
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJjbXNzc3puZ21oemhjdmh3b21vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ0MzIxMzIsImV4cCI6MjA4MDAwODEzMn0.4XrEu76H9NNe-HRNynUJHEbrg3xAO8ScCAZu4qC5ojM', 
  );

  runApp(const LeverageApp());
}

class LeverageApp extends StatelessWidget {
  const LeverageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leverage',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, // Il tema scuro che abbiamo appena creato
      home: const LoginScreen(), 
    );
  }
}