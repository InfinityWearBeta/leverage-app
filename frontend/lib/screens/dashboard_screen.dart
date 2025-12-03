import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';

/// ============================================================================
/// DASHBOARD SCREEN (COCKPIT DI SOLVIBILITÀ v8.0)
/// ============================================================================
/// Questa classe gestisce lo stato (data fetching, ricaricamento log) e 
/// funge da ORCHESTRATORE tra il Backend Python e i Widget di visualizzazione.
///
/// LINGUAGGIO CHIAVE: Dart (Flutter)
/// ARCHITETTURA: Stateful Widget (Controller) + Logica Anidata
/// ============================================================================

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
  
  // --- CACHE DATI SUPABASE ---
  List<dynamic> _allLogs = []; 
  List<dynamic> _selectedDayLogs = []; 
  List<dynamic> _userHabitsCache = [];
  List<dynamic> _expensesCache = []; // Spese fisse (necessarie per il form Pagamento Bollette)

  // --- KPI FINANZIARI E BIOLOGICI (Vengono dal Backend Python) ---
  double _financialSDS = 0.0;
  String _financialStatus = "...";
  int _daysToPayday = 0;
  double _pendingBills = 0.0;
  int _caloricSDC = 0;
  
  // Variabili Grafici (Calcolate localmente per le barre)
  double _moneySpentToday = 0.0;
  int _caloriesConsumedToday = 0;

  // Variabili Psicologia (Gamification)
  String _viceStatus = "UNLOCKED";
  String _psychoMessage = "";

  @override
  void initState() {
    super.initState();
    _fetchAndCalculate(); // Avvia la sincronizzazione
  }

  // Funzioni di utilità per i tipi di dato (Evita TypeError: null)
  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0.0;
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }

  /// --------------------------------------------------------------------------
  /// CORE: INVIO STATO AL BACKEND (Solvency Manager)
  /// --------------------------------------------------------------------------
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

      // 2. PRE-PROCESSING LOCALE (Calcolo Spese di Oggi)
      double spentToday = 0.0;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      for (var log in logs) {
        if (log['date'].toString().startsWith(todayStr) && log['log_type'] == 'expense') {
             spentToday += _safeDouble(log['amount_saved']);
        }
      }

      // 3. COSTRUZIONE PAYLOAD v8.0 (Mapping complesso per Python)
      List<Map<String, dynamic>> expensesList = (expensesRaw as List).map((e) => {
        "id": e['id'], "name": e['name'], "amount": _safeDouble(e['amount']),
        "is_variable": e['is_variable'] ?? false, "min_amount": _safeDouble(e['min_amount']),
        "max_amount": _safeDouble(e['max_amount']), "payment_months": e['payment_months'] ?? [], "due_day": e['due_day'] ?? 1
      }).toList();

      List<Map<String, dynamic>> logsList = (logs as List).take(100).map((l) => {
        "date": l['created_at'], "log_type": l['log_type'], "amount": _safeDouble(l['amount_saved']), 
        "calories": 0, "category": l['category'], "related_fixed_expense_id": l['related_fixed_expense_id']
      }).toList();

      final payload = {
        "profile": {
            "id": userId, "tdee_kcal": 2000, "current_liquid_balance": _safeDouble(profile['current_savings']),
            "payday_day": profile['payday_day'] ?? 27,
            "preferences": {"enable_windfall": true, "weekend_multiplier": 1.5, "sugar_tax_rate": 1.2, "vice_strategy": "HARD", "min_viable_sds": 5.0}
        },
        "expenses": expensesList,
        "logs": logsList
      };

      // 4. CHIAMATA API (Il server risponde con i KPI aggiornati)
      final url = Uri.parse('https://leverage-backend-ht38.onrender.com/calculate-bio-solvency');
      final response = await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(payload));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            // MAPPING SICURO DELLA RISPOSTA (Assegnazione ai KPI)
            _financialSDS = _safeDouble(result['financial']['sds_today']);
            _financialStatus = result['financial']['status'] ?? "N/A";
            _daysToPayday = _safeInt(result['financial']['days_until_payday']);
            _pendingBills = _safeDouble(result['financial']['pending_bills_total']);
            _caloricSDC = _safeInt(result['biological']['sdc_remaining']);
            _viceStatus = result['psychology']['vice_status'] ?? "UNLOCKED";
            _psychoMessage = result['psychology']['message'] ?? "";
            
            _moneySpentToday = spentToday;
            _expensesCache = expensesRaw; 
            _allLogs = logs;
            _userHabitsCache = habits;
            _updateSelectedDayLogs(_selectedDay);
            _isLoading = false;
          });
        }
      } else { throw Exception('API Error: ${response.statusCode}'); }

    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
      print("Errore Critico Dashboard: $e");
    }
  }

  // --- LOGICA CANCELLAZIONE LOG CON RIMBORSO ---
  Future<void> _deleteLog(String logId, String type, double amount) async {
    try {
      if (type == 'expense' || (type == 'vice_consumed' && amount < 0)) {
        await _refundUserBalance(amount); // Rimborso
      }
      await Supabase.instance.client.from('daily_logs').delete().eq('id', logId);
      _fetchAndCalculate(); // Ricalcola tutto
    } catch (e) { print(e); }
  }

  Future<void> _refundUserBalance(double amount) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final profile = await Supabase.instance.client.from('profiles').select('current_savings').eq('id', userId).single();
    double current = _safeDouble(profile['current_savings']);
    await Supabase.instance.client.from('profiles').update({'current_savings': current + amount}).eq('id', userId);
  }

  // --- GESTIONE INTERAZIONE UI ---
  void _updateSelectedDayLogs(DateTime day) {
    setState(() {
      _selectedDayLogs = _allLogs.where((log) => isSameDay(DateTime.parse(log['date']), day)).toList();
    });
  }

  void _showAddLogModal() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        // Passiamo i dati necessari allo SmartForm
        child: SmartInputForm(userHabits: _userHabitsCache, userExpenses: _expensesCache),
      ),
    ).then((val) { if (val == true) _fetchAndCalculate(); });
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  // --- WIDGET PRINCIPALE ---

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
                _buildSolvencyCockpit(),
                const SizedBox(height: 15),
                _buildDailyProgress(),
                const SizedBox(height: 15),
                _buildCalendar(),
                const Divider(color: Colors.white10, height: 20),
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
                        itemBuilder: (context, index) => _buildLogCard(_selectedDayLogs[index]),
                      ),
                const SizedBox(height: 80), 
              ],
            ),
          ),
    );
  }

  // --- WIDGETS ESTRATTI (Design) ---

  Widget _buildSolvencyCockpit() {
    Color statusColor = const Color(0xFF00E676);
    if (_financialStatus == "CRITICO") statusColor = Colors.orange;
    if (_financialStatus == "INSOLVENTE") statusColor = Colors.redAccent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withOpacity(0.5), width: 1),
        boxShadow: [BoxShadow(color: statusColor.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("BUDGET SICURO (SDS)", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(_financialStatus, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("€ ${_financialSDS.toStringAsFixed(2)}", style: TextStyle(color: statusColor, fontSize: 40, fontWeight: FontWeight.w900)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.bolt, color: Colors.blueAccent, size: 24),
                  Text("$_caloricSDC Kcal", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text("SDC Residuo", style: TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              )
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: 1.0, backgroundColor: Colors.white10, color: statusColor, minHeight: 4),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Bollette: € ${_pendingBills.toStringAsFixed(0)}", style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
              Text("Payday: $_daysToPayday gg", style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          )
        ],
      ),
    );
  }

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
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  moneyPct < 0.5 ? "Ottimo ritmo! Stai risparmiando." : "Attenzione, stai esaurendo il budget giornaliero.",
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20)),
      child: TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1), lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay, selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: CalendarFormat.week, availableCalendarFormats: const {CalendarFormat.week: 'Settimana'},
        onDaySelected: (selectedDay, focusedDay) {
          setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
          _updateSelectedDayLogs(selectedDay);
        },
        eventLoader: (day) => _allLogs.where((log) => isSameDay(DateTime.parse(log['date']), day)).toList(),
        calendarStyle: const CalendarStyle(
          defaultTextStyle: TextStyle(color: Colors.white), weekendTextStyle: TextStyle(color: Colors.white70),
          todayDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
          selectedDecoration: BoxDecoration(color: Color(0xFF00E676), shape: BoxShape.circle),
          markerDecoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true, titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white), rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white)),
      ),
    );
  }

  Widget _buildLogsList() {
    return _selectedDayLogs.isEmpty
        ? const Padding(padding: EdgeInsets.all(20), child: Text("Nessun log.", style: TextStyle(color: Colors.grey)))
        : ListView.builder(
            physics: const NeverScrollableScrollPhysics(), shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _selectedDayLogs.length,
            itemBuilder: (context, index) => _buildLogCard(_selectedDayLogs[index]),
          );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    IconData icon = Icons.circle; Color color = Colors.grey; String title = "Attività"; String subtitle = "";
    
    if (log['log_type'] == 'vice_consumed') {
      double saved = _safeDouble(log['amount_saved']);
      if (saved > 0) { icon = Icons.trending_up; color = const Color(0xFF00E676); title = "${log['sub_type']}"; subtitle = "Risparmio: €${saved.toStringAsFixed(2)}"; }
      else if (saved < 0) { icon = Icons.warning_amber_rounded; color = Colors.orangeAccent; title = "${log['sub_type']}"; subtitle = "Extra: €${(saved * -1).toStringAsFixed(2)}"; }
      else { icon = Icons.horizontal_rule; color = Colors.grey; title = "${log['sub_type']}"; subtitle = "Budget neutro"; }
    } else if (log['log_type'] == 'expense') {
      icon = Icons.money_off; color = Colors.redAccent; title = "${log['category']}"; subtitle = "Spesa €${_safeDouble(log['amount_saved']).toStringAsFixed(2)}";
    } else if (log['log_type'] == 'workout') {
      icon = Icons.fitness_center; color = Colors.blueAccent; title = "${log['sub_type']}"; subtitle = "${log['duration_min']} min";
    }

    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color, size: 20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.white30, size: 18), 
          onPressed: () => _deleteLog(log['id'], log['log_type'] ?? '', _safeDouble(log['amount_saved']))
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.edit_note, size: 50, color: Colors.white.withOpacity(0.1)), const SizedBox(height: 10), const Text("Nessun log oggi.", style: TextStyle(color: Colors.grey))]));
  }
}

/// ============================================================================
/// SMART INPUT FORM (WIDGET MODULARE)
/// ============================================================================
/// Responsabile di raccogliere l'input e di eseguire la transazione con Supabase.
/// Nota: Questa classe DEVE essere inclusa nel file 'dashboard_screen.dart' per funzionare.
/// ============================================================================

class SmartInputForm extends StatefulWidget {
  final List<dynamic> userHabits; 
  final List<dynamic> userExpenses; 
  const SmartInputForm({super.key, required this.userHabits, required this.userExpenses});

  @override
  State<SmartInputForm> createState() => _SmartInputFormState();
}

class _SmartInputFormState extends State<SmartInputForm> {
  String _selectedType = 'vice_consumed'; 
  
  String? _selectedHabitId; 
  String _customHabitName = "Caffè"; 
  double _unitCost = 1.0;
  final _consumedQtyController = TextEditingController(text: "1");
  final _customCostController = TextEditingController(text: "1.00");
  final List<String> _commonSuggestions = ['Caffè', 'Sigaretta', 'Birra', 'Fast Food', 'Dolci', 'Scommesse'];

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _expenseCategory = 'Svago';
  bool _isNecessary = false;
  String _workoutType = 'Palestra';
  int _duration = 30;
  String? _selectedBillId;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.userHabits.isNotEmpty) {
      _selectUserHabit(widget.userHabits[0]);
    } else {
      _selectedHabitId = null; 
    }
  }

  void _selectUserHabit(Map<String, dynamic> habit) {
    setState(() {
      _selectedHabitId = habit['id'];
      _customHabitName = habit['name'];
      _unitCost = (habit['cost_per_unit'] as num).toDouble();
      _customCostController.text = _unitCost.toString();
    });
  }

  // --- MOTORE DI AGGIORNAMENTO SALDO (RPC) ---
  Future<void> _updateUserBalance(String userId, double amountSpent) async {
    // Chiama la funzione RPC creata nel database.
    await Supabase.instance.client.rpc('decrement_balance', params: {
      'user_id': userId, 
      'amount': amountSpent
    });
  }

  Future<void> _saveLog() async {
    setState(() => _isSaving = true);
    final userId = Supabase.instance.client.auth.currentUser!.id;

    Map<String, dynamic> data = {
      'user_id': userId,
      'log_type': _selectedType,
      'date': DateTime.now().toIso8601String(),
      'note': _noteController.text,
    };

    double amountSpentReal = 0.0; 
    String? relatedFixedExpenseId;

    if (_selectedType == 'vice_consumed') {
      int baseline = 0;
      if (_selectedHabitId != null) {
        final habit = widget.userHabits.firstWhere((h) => h['id'] == _selectedHabitId);
        baseline = (habit['current_daily_quantity'] as num).toInt();
        _unitCost = (habit['cost_per_unit'] as num).toDouble();
      } else {
        _unitCost = double.tryParse(_customCostController.text.replaceAll(',', '.')) ?? 0.0;
      }
      final int consumed = int.tryParse(_consumedQtyController.text) ?? 1;
      final int delta = baseline - consumed; 
      
      data['amount_saved'] = delta * _unitCost; 
      data['sub_type'] = _customHabitName;
      data['category'] = 'Vizio';
      amountSpentReal = consumed * _unitCost;

    } else if (_selectedType == 'expense') {
      double amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
      data['amount_saved'] = amount; 
      data['category'] = _expenseCategory;
      data['is_necessary'] = _isNecessary;
      amountSpentReal = amount;
    } else if (_selectedType == 'bill_payment') {
      if (_selectedBillId == null) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Seleziona la bolletta!")));
         setState(() => _isSaving = false); return;
      }
      double amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
      data['log_type'] = 'expense'; 
      data['amount_saved'] = amount;
      data['category'] = 'Bollette';
      data['is_necessary'] = true;
      amountSpentReal = amount;
      relatedFixedExpenseId = _selectedBillId;
      
    } else if (_selectedType == 'workout') {
      data['sub_type'] = _workoutType;
      data['duration_min'] = _duration;
    }

    try {
      if (relatedFixedExpenseId != null) {
        data['related_fixed_expense_id'] = relatedFixedExpenseId;
      }
      await Supabase.instance.client.from('daily_logs').insert(data);
      
      // DEBITO: Se c'è un'uscita di cassa, aggiorna il saldo
      if (amountSpentReal > 0) {
        await _updateUserBalance(userId, amountSpentReal);
      }

      if (mounted) Navigator.pop(context, true); 
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Errore: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 650, 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("REGISTRA ATTIVITÀ", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          Row(children: [
            _typeButton("Vizio", Icons.smoke_free, 'vice_consumed', const Color(0xFF00E676)),
            const SizedBox(width: 10),
            _typeButton("Spesa", Icons.euro, 'expense', Colors.redAccent),
            const SizedBox(width: 10),
            _typeButton("Bolletta", Icons.receipt_long, 'bill_payment', Colors.orange), // TASTO BOLLETTA
            const SizedBox(width: 10),
            _typeButton("Sport", Icons.fitness_center, 'workout', Colors.blueAccent),
          ]),
          const Divider(color: Colors.white10, height: 30),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // UI VIZI
                  if (_selectedType == 'vice_consumed') ...[
                    if (widget.userHabits.isNotEmpty) ...[
                      DropdownButtonFormField<String>(value: _selectedHabitId, dropdownColor: const Color(0xFF1E1E1E), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Vizi Tracciati", border: OutlineInputBorder()), items: [...widget.userHabits.map((h) => DropdownMenuItem(value: h['id'].toString(), child: Text(h['name']))), const DropdownMenuItem(value: null, child: Text("+ Altro"))], onChanged: (v) { if (v != null) _selectUserHabit(widget.userHabits.firstWhere((h) => h['id'] == v)); else setState(() { _selectedHabitId = null; }); }),
                      const SizedBox(height: 15),
                    ],
                    if (_selectedHabitId == null) ...[
                      TextField(onChanged: (v) => _customHabitName = v, controller: TextEditingController(text: _customHabitName), decoration: const InputDecoration(labelText: "Nome Vizio", border: OutlineInputBorder()), style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 10),
                      TextField(controller: _customCostController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Costo (€)", border: OutlineInputBorder()), style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 20),
                    ],
                    TextField(controller: _consumedQtyController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 30), textAlign: TextAlign.center, decoration: const InputDecoration(labelText: "Quantità", border: OutlineInputBorder())),
                  ],
                  // UI SPESA GENERICA
                  if (_selectedType == 'expense') ...[
                    TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Importo (€)", border: OutlineInputBorder()), style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(value: _expenseCategory, dropdownColor: const Color(0xFF1E1E1E), style: const TextStyle(color: Colors.white), items: ['Cibo', 'Trasporti', 'Svago', 'Bollette'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _expenseCategory = v!), decoration: const InputDecoration(labelText: "Categoria", border: OutlineInputBorder())),
                    SwitchListTile(title: const Text("Era necessaria?", style: TextStyle(color: Colors.white)), value: _isNecessary, activeColor: const Color(0xFF00E676), onChanged: (v) => setState(() => _isNecessary = v)),
                  ],
                  // UI PAGAMENTO BOLLETTA
                  if (_selectedType == 'bill_payment') ...[
                    if (widget.userExpenses.isEmpty)
                      const Text("Nessuna spesa fissa configurata.", style: TextStyle(color: Colors.grey))
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedBillId,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "Quale Bolletta stai pagando?", border: OutlineInputBorder()),
                        items: widget.userExpenses.map((e) => DropdownMenuItem(value: e['id'].toString(), child: Text("${e['name']} (Stima: €${e['max_amount'] ?? e['amount']})"))).toList(),
                        onChanged: (v) => setState(() => _selectedBillId = v),
                      ),
                    const SizedBox(height: 15),
                    TextField(controller: _amountController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Importo Reale Pagato (€)", border: OutlineInputBorder())),
                  ],
                  // UI SPORT
                  if (_selectedType == 'workout') ...[
                    DropdownButtonFormField<String>(value: _workoutType, dropdownColor: const Color(0xFF1E1E1E), style: const TextStyle(color: Colors.white), items: ['Palestra', 'Corsa', 'Nuoto', 'Yoga'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _workoutType = v!), decoration: const InputDecoration(labelText: "Attività", border: OutlineInputBorder())),
                    const SizedBox(height: 20),
                    Slider(value: _duration.toDouble(), min: 10, max: 180, divisions: 17, activeColor: Colors.blueAccent, onChanged: (v) => setState(() => _duration = v.toInt())),
                    Text("Durata: $_duration min", style: const TextStyle(color: Colors.white)),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _isSaving ? null : _saveLog, style: ElevatedButton.styleFrom(backgroundColor: Colors.white), child: _isSaving ? const CircularProgressIndicator() : const Text("REGISTRA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))))
        ],
      ),
    );
  }

  Widget _typeButton(String label, IconData icon, String type, Color color) {
    bool isSelected = _selectedType == type;
    return Expanded(child: GestureDetector(onTap: () => setState(() => _selectedType = type), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isSelected ? color.withOpacity(0.2) : Colors.white10, border: Border.all(color: isSelected ? color : Colors.transparent), borderRadius: BorderRadius.circular(10)), child: Column(children: [Icon(icon, color: isSelected ? color : Colors.grey), const SizedBox(height: 5), Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))]))));
  }
}