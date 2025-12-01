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
    print("--- INIZIO DEBUG DASHBOARD ---"); // DEBUG LOG
    
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      print("ERRORE: Utente non loggato");
      return;
    }

    try {
      // 1. RECUPERA DATI DA SUPABASE
      print("1. Recupero profilo da Supabase...");
      final profile = await supabase.from('profiles').select().eq('id', userId).single();
      print("   Profilo OK: ${profile['id']}");

      print("2. Recupero vizio da Supabase...");
      final habitResponse = await supabase.from('habits').select().eq('user_id', userId).limit(1);
      
      if (habitResponse.isEmpty) {
        print("   ERRORE: Nessun vizio trovato.");
        setState(() {
          _errorMessage = "Nessun vizio trovato. Rifai l'onboarding.";
          _isLoading = false;
        });
        return;
      }
      final habit = habitResponse[0];
      print("   Vizio OK: ${habit['name']}");

      // 2. PREPARA IL PACCHETTO
      // Parsing sicuro della data
      final birthDate = DateTime.parse(profile['birth_date']);
      final age = DateTime.now().year - birthDate.year;

      final Map<String, dynamic> payload = {
        "age": age,
        "gender": profile['gender'],
        // Forziamo la conversione a double per sicurezza
        "weight_kg": (profile['weight_kg'] as num).toDouble(),
        "height_cm": (profile['height_cm'] as num).toDouble(),
        "activity_level": profile['activity_level'],
        
        "body_fat_percent": profile['body_fat_percent'], // Può essere null
        "avg_daily_steps": profile['avg_daily_steps'],   // Può essere null

        "habit_name": habit['name'],
        // Forziamo conversione numeri
        "habit_cost": (habit['cost_per_unit'] as num).toDouble(),
        "daily_quantity": (habit['current_daily_quantity'] as num).toInt(),
      };

      print("3. Payload pronto per Python: $payload");

      // 3. CHIAMA IL BACKEND
      final url = Uri.parse('https://leverage-backend-ht38.onrender.com/calculate-projection');
      
      print("4. Invio richiesta HTTP a: $url");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      print("5. Risposta ricevuta. Status Code: ${response.statusCode}");
      print("   Body Risposta: ${response.body}"); // VEDIAMO COSA RISPONDE DAVVERO

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          _data = result;
          _isLoading = false;
        });
        print("--- DEBUG COMPLETATO CON SUCCESSO ---");
      } else {
        throw Exception('Server Error (${response.statusCode}): ${response.body}');
      }

    } catch (e) {
      print("!!! ECCEZIONE CATTURATA !!!");
      print(e.toString());
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
      appBar: AppBar(
        title: const Text("IL TUO PIANO"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : _errorMessage != null
              ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHealthCard(),
                      const SizedBox(height: 20),
                      _buildWealthCard(),
                      const SizedBox(height: 30),
                      Text(
                        // Uso safely del null check
                        "Metodo Analisi: ${_data?['user_analysis']?['method'] ?? 'N/A'}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHealthCard() {
    // Accesso sicuro ai dati con ? e ?? per evitare crash se mancano chiavi
    final health = _data?['user_analysis'] ?? {};
    final impact = _data?['health_projection'] ?? {};
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: Colors.blueAccent.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.monitor_heart, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text("METABOLISMO & SALUTE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(height: 30, color: Colors.white10),
          
          _row("TDEE (Mantenimento)", "${health['tdee']} Kcal"),
          _row("BMR (Basale)", "${health['bmr']} Kcal"),
          
          const SizedBox(height: 20),
          const Text("IMPATTO DEL VIZIO (al giorno):", style: TextStyle(color: Colors.grey, fontSize: 12)),
          
          _row("Kcal Risparmiabili", "${impact['daily_kcal_saved']} Kcal", isBad: false),
          
          // Controllo se esiste la chiave prima di usarla
          if (impact['daily_life_minutes_saved'] != null && impact['daily_life_minutes_saved'] > 0)
             _row("Vita Persa Stimata", "${impact['daily_life_minutes_saved']} min/giorno", isBad: true),
        ],
      ),
    );
  }

  Widget _buildWealthCard() {
    final wealth = _data?['wealth_projection'] ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF00E676).withOpacity(0.1), Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.attach_money, color: Color(0xFF00E676)),
              SizedBox(width: 10),
              Text("PROIEZIONE RICCHEZZA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(height: 30, color: Colors.white10),
          
          _row("Spreco Giornaliero", "€ ${wealth['daily_saving']}", isBad: true),
          _row("Spreco Annuale", "€ ${wealth['annual_saving']}", isBad: true),
          
          const SizedBox(height: 20),
          const Text("POTENZIALE INVESTITO (7% Annuo):", style: TextStyle(color: Colors.grey, fontSize: 12)),
          
          _row("Tra 10 Anni", "€ ${wealth['roi_10_years']}"),
          
          const SizedBox(height: 15),
          Center(
            child: Column(
              children: [
                const Text("TRA 30 ANNI", style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, letterSpacing: 2)),
                Text(
                  "€ ${wealth['roi_30_years']}",
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool? isBad}) {
    Color valColor = Colors.white;
    if (isBad == true) valColor = Colors.redAccent;
    if (isBad == false) valColor = const Color(0xFF00E676);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: valColor)),
        ],
      ),
    );
  }
}