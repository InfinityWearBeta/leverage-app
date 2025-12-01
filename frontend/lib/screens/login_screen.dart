import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding_screen.dart';
import 'main_layout.dart'; // <--- Importante: Importiamo il layout con il menu

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true; 

  Future<void> _authenticate() async {
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // 1. ESEGUI AUTENTICAZIONE
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account creato!")),
          );
        }
      }

      // 2. CONTROLLO INTELLIGENTE
      // Controlliamo se l'utente ha già compilato il profilo
      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        // SE IL PROFILO È INCOMPLETO -> VAI ALL'ONBOARDING
        if (data == null || data['height_cm'] == null) {
          print("Profilo incompleto: Vado all'Onboarding");
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        } else {
          // SE IL PROFILO ESISTE -> VAI AL MAIN LAYOUT (Menu + Dashboard)
          print("Profilo trovato: Vado al MainLayout");
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainLayout()), // <--- QUI CAMBIA TUTTO
          );
        }
      }

    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.show_chart, size: 80, color: Color(0xFF00E676)),
              const SizedBox(height: 20),
              const Text(
                "LEVERAGE",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 10),
              Text(
                _isLogin ? "Bentornato, investitore." : "Crea il tuo futuro.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),

              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
                  : ElevatedButton(
                      onPressed: _authenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _isLogin ? "ACCEDI" : "CREA ACCOUNT",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
              
              const SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(
                  _isLogin ? "Non hai un account? Registrati" : "Hai già un account? Accedi",
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}