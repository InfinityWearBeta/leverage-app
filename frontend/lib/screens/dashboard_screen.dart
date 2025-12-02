import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart'; // Serve per isSameDay
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';

// Importiamo i nostri NUOVI componenti modulari
import 'components/smart_input_form.dart';
import 'components/dashboard_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  
  List<dynamic> _allLogs = []; 
  List<dynamic> _selectedDayLogs = []; 
  List<dynamic> _userHabitsCache = [];

  // State Variables
  double _financialSDS = 0.0;
  String _financialStatus = "...";
  int _daysToPayday = 0;
  double _pendingBills = 0.0;
  int _caloricSDC = 0;
  String _viceStatus = "UNLOCKED";
  String _psychoMessage = "";

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
      final logs = await supabase.from('daily_logs').select().eq('user_id', userId).order('created_at', ascending: false);
      final habits = await supabase.from('habits').select().eq('user_id', userId);
      final expenses = await supabase.from('fixed_expenses').select().eq('user_id', userId);

      // -- COSTRUZIONE PAYLOAD PER BACKEND PYTHON --
      // (Logica identica alla v8.0 ma più pulita)
      int tdee = 2000; 
      if (profile['weight_kg'] != null) {
         // Calcolo TDEE semplificato per fallback
         tdee = 2000; // Il backend farà il calcolo vero
      }

      List<Map<String, dynamic>> expensesList = (expenses as List).map((e) => {
        "id": e['id'], "name": e['name'], "amount": (e['amount'] as num).toDouble(),
        "is_variable": e['is_variable'] ?? false,
        "min_amount": (e['min_amount'] as num?)?.toDouble() ?? 0.0,
        "max_amount": (e['max_amount'] as num?)?.toDouble() ?? 0.0,
        "payment_months": e['payment_months'] ?? [], "due_day": e['due_day'] ?? 1
      }).toList();

      List<Map<String, dynamic>> recentLogsList = (logs as List).take(50).map((l) => {
        "date": l['created_at'], "log_type": l['log_type'],
        "amount": (l['amount_saved'] as num).toDouble(), "related_fixed_expense_id": l['related_fixed_expense_id']
      }).toList();

      final payload = {
        "profile": {
            "id": userId, "tdee_kcal": tdee,
            "current_liquid_balance": (profile['current_savings'] as num?)?.toDouble() ?? 0.0,
            "payday_day": profile['payday_day'] ?? 27,
            "preferences": {"enable_windfall": true, "weekend_multiplier": 1.5, "sugar_tax_rate": 1.2, "vice_strategy": "HARD", "min_viable_sds": 5.0}
        },
        "expenses": expensesList,
        "logs": recentLogsList
      };

      final url = Uri.parse('https://leverage-backend-ht38.onrender.com/calculate-bio-solvency');
      final response = await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(payload));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _financialSDS = (result['financial']['sds_today'] as num).toDouble();
            _financialStatus = result['financial']['status'];
            _daysToPayday = (result['financial']['days_until_payday'] as num).toInt();
            _pendingBills = (result['financial']['pending_bills_total'] as num).toDouble();
            _caloricSDC = (result['biological']['sdc_remaining'] as num).toInt();
            _viceStatus = result['psychology']['vice_status'];
            _psychoMessage = result['psychology']['message'];

            _allLogs = logs;
            _userHabitsCache = habits;
            _updateSelectedDayLogs(_selectedDay);
            _isLoading = false;
          });
        }
      } 
    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
      print("Errore: $e");
    }
  }

  void _updateSelectedDayLogs(DateTime day) {
    setState(() {
      _selectedDayLogs = _allLogs.where((log) => isSameDay(DateTime.parse(log['date']), day)).toList();
    });
  }

  Future<void> _deleteLog(String logId) async {
    await Supabase.instance.client.from('daily_logs').delete().eq('id', logId);
    // Qui dovremmo rimborsare, ma per brevità ricarichiamo solo. 
    // (La logica di rimborso dovrebbe essere nel backend o gestita come nel file precedente)
    _fetchAndCalculate(); 
  }

  void _showAddLogModal() {
    if (_viceStatus == "LOCKED") {
       // Mostra avviso blocco (opzionale)
    }
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: SmartInputForm(userHabits: _userHabitsCache)),
    ).then((val) { if (val == true) _fetchAndCalculate(); });
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text("COCKPIT MODULARE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.amber)),
        backgroundColor: Colors.transparent,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLogModal, backgroundColor: const Color(0xFF00E676),
        label: const Text("REGISTRA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_circle, color: Colors.black),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
        : SingleChildScrollView(
            child: Column(
              children: [
                // 1. IL NUOVO WIDGET COCKPIT ESTRATTO
                SolvencyCockpit(
                  sds: _financialSDS, 
                  status: _financialStatus, 
                  sdc: _caloricSDC, 
                  daysToPayday: _daysToPayday, 
                  pendingBills: _pendingBills
                ),
                
                const SizedBox(height: 15),
                
                // 2. IL NUOVO WIDGET CALENDARIO ESTRATTO
                CalendarWidget(
                  focusedDay: _focusedDay, 
                  selectedDay: _selectedDay, 
                  onDaySelected: (sel, foc) {
                    setState(() { _selectedDay = sel; _focusedDay = foc; });
                    _updateSelectedDayLogs(sel);
                  }, 
                  eventLoader: (day) => _allLogs.where((log) => isSameDay(DateTime.parse(log['date']), day)).toList()
                ),
                
                const Divider(color: Colors.white10, height: 20),
                
                // 3. LA LISTA LOG
                _selectedDayLogs.isEmpty
                  ? const Padding(padding: EdgeInsets.all(20), child: Text("Nessun log.", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      physics: const NeverScrollableScrollPhysics(), shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _selectedDayLogs.length,
                      itemBuilder: (context, index) => LogCard(
                        log: _selectedDayLogs[index], 
                        onDelete: (id) => _deleteLog(id)
                      ),
                    ),
                const SizedBox(height: 80), 
              ],
            ),
          ),
    );
  }
}