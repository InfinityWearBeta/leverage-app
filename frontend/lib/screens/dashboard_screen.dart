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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Nero ancora più profondo
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER: Saluto e Avatar
                        _buildHeader(),
                        const SizedBox(height: 30),

                        // MAIN CARD: Visa Infinite Style
                        _buildWealthCard(),
                        
                        const SizedBox(height: 30),

                        // WEEKLY TRACKER (Visual Only per ora)
                        _buildWeeklyTracker(),

                        const SizedBox(height: 30),

                        // QUICK STATS
                        const Text("METRICHE CHIAVE", style: TextStyle(color: Colors.white54, letterSpacing: 1.5, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        _buildStatsGrid(),
                        
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
    );
  }

  // 1. HEADER MODERNO
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Benvenuto,", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16)),
            const Text("Investitore", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        InkWell(
          onTap: _logout,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.logout, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  // 2. WEALTH CARD (Stile Carta di Credito Premium)
  Widget _buildWealthCard() {
    final wealth = _data!['wealth_projection'];
    
    return Container(
      width: double.infinity,
      height: 220,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00E676), Color(0xFF00693E)], // Gradiente Verde Lussuoso
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                child: const Text("PROIEZIONE 30 ANNI", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const Icon(Icons.show_chart, color: Colors.white54),
            ],
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("€ ${wealth['roi_30_years']}", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
              const Text("+7% Compound Interest", style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("SPRECO ANNUO", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  Text("€ ${wealth['annual_saving']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              // Bottone azione finto sulla carta
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward, color: Color(0xFF00693E), size: 20),
              )
            ],
          )
        ],
      ),
    );
  }

  // 3. WEEKLY TRACKER (Elemento visuale per riempire)
  Widget _buildWeeklyTracker() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Streak Settimanale", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text("🔥 3 Giorni", style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ["L", "M", "M", "G", "V", "S", "D"].map((day) {
              bool isActive = day == "L" || day == "M" || day == "M"; // Finto stato attivo
              return Container(
                width: 35,
                height: 35,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF00E676) : Colors.white10,
                  shape: BoxShape.circle,
                ),
                child: Text(day, style: TextStyle(color: isActive ? Colors.black : Colors.grey, fontWeight: FontWeight.bold)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 4. STATS GRID
  Widget _buildStatsGrid() {
    final health = _data!['user_analysis'];
    final impact = _data!['health_projection'];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.5,
      children: [
        _miniCard("TDEE", "${health['tdee']} Kcal", Icons.local_fire_department, Colors.orange),
        _miniCard("Vita Persa", "${impact['daily_life_minutes_saved']} min", Icons.timelapse, Colors.redAccent),
        _miniCard("Risparmio", "€ ${_data!['wealth_projection']['daily_saving']}/die", Icons.savings, Colors.blueAccent),
        _miniCard("ROI 10y", "€ ${_data!['wealth_projection']['roi_10_years']}", Icons.rocket_launch, Colors.purpleAccent),
      ],
    );
  }

  Widget _miniCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
        ],
      ),
    );
  }
}