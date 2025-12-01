import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String? _errorMessage;

  // Variabili per i testi dinamici
  String _habitName = "";
  double _dailySaving = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchAndCalculate();
  }

  Future<void> _fetchAndCalculate() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return;

    try {
      final profile = await supabase.from('profiles').select().eq('id', userId).single();
      final habitResponse = await supabase.from('habits').select().eq('user_id', userId).limit(1);
      
      if (habitResponse.isEmpty) {
        setState(() {
          _errorMessage = "Nessun vizio trovato. Rifai l'onboarding.";
          _isLoading = false;
        });
        return;
      }
      final habit = habitResponse[0];

      // Salviamo dati locali per la UI
      _habitName = habit['name'];
      _dailySaving = (habit['cost_per_unit'] as num).toDouble() * (habit['current_daily_quantity'] as num).toInt();

      final birthDate = DateTime.parse(profile['birth_date']);
      final age = DateTime.now().year - birthDate.year;

      final Map<String, dynamic> payload = {
        "age": age,
        "gender": profile['gender'],
        "weight_kg": (profile['weight_kg'] as num).toDouble(),
        "height_cm": (profile['height_cm'] as num).toDouble(),
        "activity_level": profile['activity_level'],
        "body_fat_percent": profile['body_fat_percent'],
        "avg_daily_steps": profile['avg_daily_steps'],
        "habit_name": habit['name'],
        "habit_cost": (habit['cost_per_unit'] as num).toDouble(),
        "daily_quantity": (habit['current_daily_quantity'] as num).toInt(),
      };

      final url = Uri.parse('https://leverage-backend-ht38.onrender.com/calculate-projection');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        setState(() {
          _data = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }

    } catch (e) {
      setState(() {
        _errorMessage = "Errore: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // Funzione per mostrare le spiegazioni
  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Ho Capito", style: TextStyle(color: Color(0xFF00E676))),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text("IL TUO PIANO", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchAndCalculate),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. IL COACH MESSAGE (Spiegazione narrativa)
                        _buildCoachMessage(),
                        
                        const SizedBox(height: 25),

                        // 2. WEALTH CARD (Interattiva)
                        _buildSectionTitle("PROIEZIONE RICCHEZZA", 
                          "Come i piccoli risparmi diventano capitali grazie all'interesse composto."),
                        const SizedBox(height: 10),
                        _buildWealthCard(),
                        
                        const SizedBox(height: 30),

                        // 3. HEALTH CARD (Spiegata)
                        _buildSectionTitle("METABOLISMO & SALUTE", 
                          "Analisi del tuo dispendio energetico basata sui dati biometrici."),
                        const SizedBox(height: 10),
                        _buildHealthCard(),

                        const SizedBox(height: 30),
                        
                        // 4. METRICHE CHIAVE
                        const Text("DETTAGLI", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        const SizedBox(height: 15),
                        _buildStatsGrid(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSectionTitle(String title, String info) {
    return Row(
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => _showInfoDialog(title, info),
          child: const Icon(Icons.info_outline, color: Colors.grey, size: 18),
        )
      ],
    );
  }

  Widget _buildCoachMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: const Color(0xFF00E676), width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("L'ANALISI DELL'ESPERTO", style: TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white70, height: 1.5),
              children: [
                const TextSpan(text: "Ciao! Attualmente stai spendendo "),
                TextSpan(text: "€ $_dailySaving al giorno", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                TextSpan(text: " in $_habitName. "),
                const TextSpan(text: "\nSe investi questa somma invece di spenderla, tra 30 anni avrai un capitale che lavora per te. I grafici sotto mostrano questa trasformazione."),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWealthCard() {
    final wealth = _data!['wealth_projection'];
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00E676), Color(0xFF00693E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00E676).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("CAPITALE POTENZIALE (30 ANNI)", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text("€ ${wealth['roi_30_years']}", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _whiteStat("Risparmio Annuo", "€ ${wealth['annual_saving']}"),
              _whiteStat("Rendimento", "+7% Medio"),
            ],
          )
        ],
      ),
    );
  }

  Widget _whiteStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildHealthCard() {
    final health = _data!['user_analysis'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text("FABISOGNO (TDEE)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              Text("${health['tdee']} Kcal", style: const TextStyle(color: Colors.blueAccent, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(color: Colors.white10, height: 30),
          Text(
            "Questo è il carburante che il tuo corpo brucia ogni giorno ${health['activity_source'].toString().toLowerCase()}. Se mangi più di questo, ingrassi.",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final impact = _data!['health_projection'];
    final wealth = _data!['wealth_projection'];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.5,
      children: [
        _miniCard("ROI 10 Anni", "€ ${wealth['roi_10_years']}", Icons.trending_up, Colors.purpleAccent, 
          "Il valore del tuo risparmio investito tra 10 anni."),
        _miniCard("Vita Salvata", "${impact['daily_life_minutes_saved']} min", Icons.timelapse, Colors.redAccent, 
          "Stima statistica dei minuti di vita persi per ogni sigaretta."),
        _miniCard("Kcal Risparmiate", "${impact['daily_kcal_saved']}", Icons.no_food, Colors.orange, 
          "Le calorie che eviti non assumendo il vizio oggi."),
        _miniCard("Costo Vizio", "€ $_dailySaving", Icons.money_off, Colors.grey, 
          "Quanto spendi ogni giorno per il tuo vizio."),
      ],
    );
  }

  Widget _miniCard(String title, String value, IconData icon, Color color, String description) {
    return InkWell(
      onTap: () => _showInfoDialog(title, description),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }
}