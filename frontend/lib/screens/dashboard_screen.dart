import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _benchmarkController = TextEditingController();
  final TextEditingController _moduleController = TextEditingController();
  
  final ApiService _apiService = ApiService();
  
  bool _isLoading = false;
  Map<String, dynamic>? _result;

  // Funzione helper per convertire qualsiasi numero in Double in modo sicuro
  // Questo impedisce crash se il server manda "10" (int) invece di "10.0" (double)
  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0.0;
  }

  Future<void> _calculateWealth() async {
    // Nascondi la tastiera quando premi calcola
    FocusScope.of(context).unfocus();

    final benchmark = double.tryParse(_benchmarkController.text.replaceAll(',', '.'));
    final module = double.tryParse(_moduleController.text.replaceAll(',', '.'));

    if (benchmark == null || module == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Inserisci dei numeri validi! Usa il punto per i decimali.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _result = null;
    });

    try {
      final response = await _apiService.calculateWealth(
        benchmarkCost: benchmark,
        moduleCost: module,
      );

      setState(() {
        _result = response;
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore: ${e.toString()}")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LEVERAGE', style: TextStyle(letterSpacing: 2.0, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Inserisci i costi per calcolare il tuo futuro.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 30),

            _buildInputCard(
              title: "BENCHMARK",
              subtitle: "Cosa stai sacrificando? (es. Fast Food)",
              icon: Icons.fastfood,
              color: Colors.redAccent,
              controller: _benchmarkController,
            ),

            const SizedBox(height: 20),

            _buildInputCard(
              title: "MODULO",
              subtitle: "La tua alternativa (es. Tonno)",
              icon: Icons.fitness_center,
              color: const Color(0xFF00E676),
              controller: _moduleController,
            ),

            const SizedBox(height: 40),

            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
                : ElevatedButton(
                    onPressed: _calculateWealth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "CALCOLA IMPATTO",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
            
            const SizedBox(height: 40),

            if (_result != null && _result!['success'] == true) 
              _buildResultCard(_result!['analysis']),
              
            if (_result != null && _result!['success'] == false)
              Text(
                _result!['message'] ?? "Errore sconosciuto",
                style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: "€ ",
              prefixStyle: TextStyle(color: color, fontSize: 24),
              hintText: "0.00",
              hintStyle: const TextStyle(color: Colors.white24),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> analysis) {
    final projections = analysis['roi_projections'];
    
    // CORREZIONE QUI: Usiamo le chiavi corrette (10_years) e la funzione _safeDouble
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade900.withOpacity(0.5), Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E676), width: 1),
      ),
      child: Column(
        children: [
          const Text("POTENZIALE GENERATO", style: TextStyle(color: Colors.white70, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Text(
            "€ ${_safeDouble(analysis['daily_saving']).toStringAsFixed(2)} / giorno",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Divider(color: Colors.white24, height: 30),
          
          // Qui usiamo i nomi delle chiavi che il tuo backend sta realmente inviando
          // E usiamo _safeDouble per evitare crash se arrivano numeri interi
          _buildRow("10 Anni", _safeDouble(projections['10_years'] ?? projections['years_10'])), 
          _buildRow("20 Anni", _safeDouble(projections['20_years'] ?? projections['years_20'])),
          
          const SizedBox(height: 15),
          Text("TRA 30 ANNI", style: TextStyle(color: const Color(0xFF00E676), fontWeight: FontWeight.bold)),
          Text(
            "€ ${_safeDouble(projections['30_years'] ?? projections['years_30']).toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: const Color(0xFF00E676)),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text("€ ${value.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}