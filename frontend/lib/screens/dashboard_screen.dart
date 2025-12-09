import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';

// IMPORTIAMO I COMPONENTI ESTERNI (Best Practice)
import '../components/dashboard_widgets.dart'; 
import '../components/smart_input_form.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // --- STATO UI E CONTROLLO ---
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  
  // --- CACHE DATI ---
  List<dynamic> _allLogs = []; 
  List<dynamic> _selectedDayLogs = []; 
  List<dynamic> _userHabitsCache = [];
  List<dynamic> _expensesCache = []; 

  // --- KPI FINANZIARI E BIOLOGICI ---
  double _financialSDS = 0.0;          
  double _currentLiquidCash = 0.0;     // NUOVO: Cash Reale
  String _financialStatus = "...";
  int _daysToPayday = 0;
  double _pendingBills = 0.0;
  int _caloricSDC = 0;
  
  double _moneySpentToday = 0.0;
  String _psychoMessage = "";

  @override
  void initState() {
    super.initState();
    _fetchAndCalculate();
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _fetchAndCalculate() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // 1. FETCH DATI RAW
      final profile = await supabase.from('profiles').select().eq('id', userId).single();
      final logs = await supabase.from('daily_logs').select().eq('user_id', userId).order('created_at', ascending: false);
      final habits = await supabase.from('habits').select().eq('user_id', userId);
      final expensesRaw = await supabase.from('fixed_expenses').select().eq('user_id', userId);

      // 2. PRE-PROCESSING LOCALE (Preserviamo la tua logica per la progress bar)
      double spentToday = 0.0;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      for (var log in logs) {
        String logDate = log['created_at'].toString();
        if (logDate.startsWith(todayStr) && log['log_type'] == 'expense') {
             spentToday += _safeDouble(log['amount_saved']);
        }
      }

      final int userTdee = (profile['tdee_kcal'] as num?)?.toInt() ?? 2000; 

      // 3. COSTRUZIONE PAYLOAD AGGIORNATA
      List<Map<String, dynamic>> expensesList = (expensesRaw as List).map((e) => {
        "id": e['id'], "name": e['name'], "amount": _safeDouble(e['amount']),
        "is_variable": e['is_variable'] ?? false, "min_amount": _safeDouble(e['min_amount']),
        "max_amount": _safeDouble(e['max_amount']), "payment_months": e['payment_months'] ?? [], "due_day": e['due_day'] ?? 1
      }).toList();

      List<Map<String, dynamic>> logsList = (logs as List).take(100).map((l) => {
        "date": l['created_at'], 
        "log_type": l['log_type'], 
        "amount": _safeDouble(l['amount_saved']), 
        "calories": l['calories'] ?? 0, 
        "category": l['category'], 
        "sub_type": l['sub_type'], // CRUCIALE: Passiamo il sottotipo per le calorie
        "related_fixed_expense_id": l['related_fixed_expense_id']
      }).toList();

      final payload = {
        "profile": {
            "id": userId, 
            "tdee_kcal": userTdee, 
            "current_liquid_balance": _safeDouble(profile['current_savings']),
            "payday_day": profile['payday_day'] ?? 27,
            "preferences": {"enable_windfall": true, "weekend_multiplier": 1.5, "min_viable_sds": 5.0}
        },
        "expenses": expensesList,
        "logs": logsList
      };

      // 4. CHIAMATA API
      final url = Uri.parse('https://leverage-backend-ht38.onrender.com/calculate-bio-solvency');
      final response = await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(payload));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _financialSDS = _safeDouble(result['financial']['sds_today']);
            _currentLiquidCash = _safeDouble(result['financial']['current_liquid_balance']); // NUOVO
            _financialStatus = result['financial']['status'] ?? "N/A";
            _daysToPayday = _safeInt(result['financial']['days_until_payday']);
            _pendingBills = _safeDouble(result['financial']['pending_bills_total']);
            
            _caloricSDC = _safeInt(result['biological']['sdc_remaining']);
            _psychoMessage = result['psychology']['message'] ?? "";
            
            _moneySpentToday = spentToday;
            _expensesCache = expensesRaw; 
            _allLogs = logs;
            _userHabitsCache = habits;
            _updateSelectedDayLogs(_selectedDay);
            _isLoading = false;
          });
        }
      } else { 
        print('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('API Error'); 
      }

    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
      print("Errore Dashboard: $e");
    }
  }

  // --- POPUP SPIEGAZIONE MATEMATICA ---
  void _showMathExplanation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("La Matematica di Leverage", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Perché il mio budget scende piano se spendo tanto?", style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Il sistema protegge il tuo futuro 'spalmando' le spese sui giorni rimanenti.", style: TextStyle(color: Colors.white70, fontSize: 13)),
              const Divider(color: Colors.white24, height: 20),
              
              _mathRow("Saldo Reale (Oggi)", "€ ${_currentLiquidCash.toStringAsFixed(2)}"),
              _mathRow("- Bollette Future", "€ ${_pendingBills.toStringAsFixed(2)}"),
              const Divider(color: Colors.white24),
              _mathRow("= Soldi Liberi", "€ ${(_currentLiquidCash - _pendingBills).toStringAsFixed(2)}"),
              const SizedBox(height: 10),
              Text("Diviso per $_daysToPayday giorni allo stipendio:", style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic, fontSize: 12)),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF00E676).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TUO SDS:", style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                    Text("€ ${_financialSDS.toStringAsFixed(2)} / giorno", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Ho capito", style: TextStyle(color: Colors.white)))
        ],
      ),
    );
  }

  Widget _mathRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // --- ACTIONS ---
  Future<void> _deleteLog(String logId, String type, double amount) async {
    try {
      if (type == 'expense' || (type == 'vice_consumed')) {
         await _refundUserBalance(amount);
      }
      await Supabase.instance.client.from('daily_logs').delete().eq('id', logId);
      _fetchAndCalculate();
    } catch (e) { print(e); }
  }

   Future<void> _refundUserBalance(double amount) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    // RPC con importo negativo per aggiungere soldi
    await Supabase.instance.client.rpc('decrement_balance', params: {
      'user_id': userId, 
      'amount': -amount 
    }); 
  }

  void _showAddLogModal() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SmartInputForm(userHabits: _userHabitsCache, userExpenses: _expensesCache),
      ),
    ).then((val) { if (val == true) _fetchAndCalculate(); });
  }
  
  void _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  // --- HELPERS ---
  void _updateSelectedDayLogs(DateTime day) {
    setState(() {
      _selectedDayLogs = _allLogs.where((log) {
        DateTime logDate = DateTime.parse(log['created_at']);
        return isSameDay(logDate, day);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text("COCKPIT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLogModal, 
        backgroundColor: const Color(0xFF00E676),
        label: const Text("REGISTRA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_circle, color: Colors.black),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
        : SingleChildScrollView(
            child: Column(
              children: [
                SolvencyCockpit(
                  sds: _financialSDS,
                  liquidCash: _currentLiquidCash,
                  status: _financialStatus,
                  sdc: _caloricSDC,
                  daysToPayday: _daysToPayday,
                  pendingBills: _pendingBills,
                  onInfoTap: _showMathExplanation,
                ),
                const SizedBox(height: 15),
                _buildDailyProgress(),
                const SizedBox(height: 15),
                // Usiamo il CalendarWidget esterno
                CalendarWidget(
                   focusedDay: _focusedDay, 
                   selectedDay: _selectedDay, 
                   onDaySelected: (sel, foc) {
                      setState(() { _selectedDay = sel; _focusedDay = foc; });
                      _updateSelectedDayLogs(sel);
                   },
                   eventLoader: (day) => _allLogs.where((log) => isSameDay(DateTime.parse(log['created_at']), day)).toList()
                ),
                const Divider(color: Colors.white10, height: 20),
                _buildLogsListWrapper()
              ],
            ),
          ),
    );
  }

  // Manteniamo questi widget locali se hanno logica molto specifica
  Widget _buildDailyProgress() {
     double moneyPct = _financialSDS > 0 ? (_moneySpentToday / _financialSDS).clamp(0.0, 1.0) : 0.0;
     return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("BILANCIO ODIERNO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Spesi: €${_moneySpentToday.toStringAsFixed(0)}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
              Text("Limit: €${_financialSDS.toStringAsFixed(0)}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: moneyPct, backgroundColor: Colors.white10, color: moneyPct > 0.9 ? Colors.redAccent : const Color(0xFF00E676), minHeight: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsListWrapper() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Diario del ${DateFormat('dd MMM').format(_selectedDay)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text("${_selectedDayLogs.length} Log", style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _selectedDayLogs.isEmpty
            ? const Padding(padding: EdgeInsets.all(20), child: Text("Nessun log.", style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                physics: const NeverScrollableScrollPhysics(), shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _selectedDayLogs.length,
                itemBuilder: (context, index) => LogCard(
                  log: _selectedDayLogs[index], 
                  onDelete: (id) => _deleteLog(
                    id, 
                    _selectedDayLogs[index]['log_type'], 
                    _safeDouble(_selectedDayLogs[index]['amount_saved'])
                  )
                ),
              ),
        const SizedBox(height: 80), 
      ],
    );
  }
}