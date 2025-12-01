import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_layout.dart'; // <--- Importante: Importiamo il layout con il menu

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // --- DATI BIOMETRICI ---
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  String _gender = 'M';
  String _activityLevel = 'Sedentary';

  // --- DATI VIZIO ---
  final _habitNameController = TextEditingController();
  final _habitCostController = TextEditingController();
  final _habitQtyController = TextEditingController();

  // --- LOGICA DI SALVATAGGIO SICURA ---
  Future<void> _submitData() async {
    setState(() => _isLoading = true);

    final user = Supabase.instance.client.auth.currentUser;
    
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sessione scaduta. Effettua di nuovo il login.")),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
      setState(() => _isLoading = false);
      return;
    }

    final userId = user.id;

    try {
      // 1. Aggiorna Profilo
      final int age = int.tryParse(_ageController.text) ?? 30;
      final birthDate = DateTime.now().subtract(Duration(days: 365 * age));

      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
        'birth_date': birthDate.toIso8601String(),
        'gender': _gender,
        'weight_kg': double.tryParse(_weightController.text) ?? 70.0,
        'height_cm': double.tryParse(_heightController.text) ?? 175.0,
        'activity_level': _activityLevel,
      });

      // 2. Crea il Vizio
      await Supabase.instance.client.from('habits').insert({
        'user_id': userId,
        'name': _habitNameController.text.isEmpty ? 'Generico' : _habitNameController.text,
        'cost_per_unit': double.tryParse(_habitCostController.text) ?? 0.0,
        'current_daily_quantity': int.tryParse(_habitQtyController.text) ?? 0,
        'target_daily_quantity': 0, 
      });

      // 3. FINE -> Vai al MainLayout (Menu + Dashboard)
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainLayout()), // <--- QUI CAMBIA TUTTO
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
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentPage + 1) / 3,
              backgroundColor: Colors.white10,
              color: const Color(0xFF00E676),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildHealthStep(),
                  _buildWealthStep(),
                  _buildFinalStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("ANALISI BIOMETRICA", style: TextStyle(color: Color(0xFF00E676), letterSpacing: 2)),
          const SizedBox(height: 10),
          const Text("Costruiamo il tuo gemello digitale.", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          _buildInput("Età", _ageController, TextInputType.number),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _buildInput("Peso (Kg)", _weightController, TextInputType.number)),
              const SizedBox(width: 15),
              Expanded(child: _buildInput("Altezza (cm)", _heightController, TextInputType.number)),
            ],
          ),
          const SizedBox(height: 20),
          const Text("Sesso Biologico", style: TextStyle(color: Colors.grey)),
          Row(
            children: [
              _buildRadio("Uomo", 'M', _gender, (val) => setState(() => _gender = val)),
              _buildRadio("Donna", 'F', _gender, (val) => setState(() => _gender = val)),
            ],
          ),
          const Spacer(),
          _buildNavButton("AVANTI", () {
            _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
            setState(() => _currentPage = 1);
          }),
        ],
      ),
    );
  }

  Widget _buildWealthStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("IDENTIFICAZIONE NEMICO", style: TextStyle(color: Colors.redAccent, letterSpacing: 2)),
          const SizedBox(height: 10),
          const Text("Qual è il vizio che vuoi distruggere?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          _buildInput("Nome Vizio (es. Sigarette)", _habitNameController, TextInputType.text),
          const SizedBox(height: 15),
          _buildInput("Costo Unitario (€)", _habitCostController, const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 15),
          _buildInput("Quantità al Giorno", _habitQtyController, TextInputType.number),
          const Spacer(),
          _buildNavButton("AVANTI", () {
            _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
            setState(() => _currentPage = 2);
          }),
        ],
      ),
    );
  }

  Widget _buildFinalStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 80, color: Color(0xFF00E676)),
          const SizedBox(height: 20),
          const Text("Dati Acquisiti", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text(
            "L'algoritmo è pronto a calcolare il tuo potenziale di ricchezza e salute.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 40),
          _isLoading
              ? const CircularProgressIndicator(color: Color(0xFF00E676))
              : ElevatedButton(
                  onPressed: _submitData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  ),
                  child: const Text("GENERA IL PIANO", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, TextInputType type) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white10,
      ),
    );
  }

  Widget _buildRadio(String label, String val, String groupVal, Function(String) onTap) {
    return Row(
      children: [
        Radio(
          value: val,
          groupValue: groupVal,
          onChanged: (v) => onTap(v.toString()),
          activeColor: const Color(0xFF00E676),
        ),
        Text(label),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildNavButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}