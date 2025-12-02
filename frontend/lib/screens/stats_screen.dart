import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'login_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _isLoading = true;
  
  double _netWorth = 0.0;
  double _liquidAssets = 0.0;
  double _lockedAssets = 0.0;

  double _monthlyIncome = 0.0;
  double _monthlyFixedBurn = 0.0;

  List<FlSpot> _savingsTrend = [];
  double _totalSavedFromHabits = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final supabase = Supabase.instance.client;

      final results = await Future.wait<dynamic>([
        supabase.from('profiles').select().eq('id', userId).single(),
        supabase.from('investments').select().eq('user_id', userId),
        supabase.from('fixed_expenses').select().eq('user_id', userId),
        supabase.from('daily_logs').select().eq('user_id', userId).order('created_at', ascending: true)
      ]);
      
      final profile = results[0] as Map<String, dynamic>;
      final investments = results[1] as List<dynamic>;
      final expenses = results[2] as List<dynamic>;
      final logs = results[3] as List<dynamic>;

      // --- 1. PATRIMONIO (Liquido vs Bloccato) ---
      double savings = (profile['current_savings'] as num?)?.toDouble() ?? 0.0;
      double pension = (profile['pension_fund'] as num?)?.toDouble() ?? 0.0; // Pension è sempre bloccata
      
      double investedLiquid = 0.0;
      double investedLocked = 0.0;

      for (var inv in investments) {
        double val = (inv['amount'] as num).toDouble();
        if (inv['is_locked'] == true) {
          investedLocked += val;
        } else {
          investedLiquid += val;
        }
      }

      // Totale Liquidità = Conto Corrente + Investimenti Sbloccati
      double totalLiquid = savings + investedLiquid;
      
      // Totale Bloccato = Fondi Pensione + Investimenti Bloccati
      double totalLocked = pension + investedLocked;

      // --- 2. CASH FLOW ---
      double monthlyBurn = 0.0;
      for (var item in expenses) {
        double amount = 0.0;
        if (item['is_variable'] == true) {
          amount = ((item['min_amount'] as num) + (item['max_amount'] as num)) / 2;
        } else {
          amount = (item['amount'] as num).toDouble();
        }
        List<dynamic> months = item['payment_months'] ?? [];
        int paymentsPerYear = months.isNotEmpty ? months.length : 12;
        monthlyBurn += (amount * paymentsPerYear) / 12;
      }

      double income = (profile['monthly_income'] as num?)?.toDouble() ?? 0.0;

      // --- 3. TREND ---
      List<FlSpot> spots = [];
      double cumulative = 0.0;
      int index = 0;
      if (logs.isEmpty) spots.add(const FlSpot(0, 0));

      for (var log in logs) {
        if (log['log_type'] == 'vice_avoided' || log['log_type'] == 'vice_consumed') {
           cumulative += (log['amount_saved'] as num).toDouble();
           spots.add(FlSpot(index.toDouble(), cumulative));
           index++;
        }
      }

      if (mounted) {
        setState(() {
          _liquidAssets = totalLiquid;
          _lockedAssets = totalLocked;
          _netWorth = totalLiquid + totalLocked;
          
          _monthlyIncome = income;
          _monthlyFixedBurn = monthlyBurn;

          _savingsTrend = spots;
          _totalSavedFromHabits = cumulative;
          
          _isLoading = false;
        });
      }

    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text("ANALYTICS", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: _logout)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const Text("PATRIMONIO NETTO TOTALE", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 2)),
                  const SizedBox(height: 5),
                  Text("€ ${_netWorth.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            // PIE CHART: LIQUIDO VS BLOCCATO
            const Text("COMPOSIZIONE PATRIMONIO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: _netWorth == 0 
                ? _buildEmptyChart("Nessun dato finanziario.") 
                : Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: [
                              PieChartSectionData(color: Colors.blueAccent, value: _liquidAssets, title: '', radius: 50),
                              PieChartSectionData(color: Colors.orangeAccent, value: _lockedAssets, title: '', radius: 50),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _legendItem("Disponibile (Liquido)", Colors.blueAccent, _liquidAssets),
                          const SizedBox(height: 15),
                          _legendItem("Vincolato (Bloccato)", Colors.orangeAccent, _lockedAssets),
                        ],
                      )
                    ],
                  ),
            ),

            const SizedBox(height: 40),

            // LINE CHART (Disciplina)
            const Text("IMPATTO SCELTE QUOTIDIANE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 20),
            Container(
              height: 250,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
              child: _savingsTrend.isEmpty || _savingsTrend.length < 2
                  ? _buildEmptyChart("Registra attività per vedere il trend.")
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _savingsTrend,
                            isCurved: true,
                            color: const Color(0xFF00E676),
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: const Color(0xFF00E676).withOpacity(0.1)),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color, double value) {
    return Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text("€ ${value.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))])]);
  }

  Widget _buildEmptyChart(String msg) => Center(child: Text(msg, style: const TextStyle(color: Colors.white30)));
}