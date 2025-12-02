import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  
  // Dati
  Map<String, dynamic>? _profileData;
  List<dynamic> _allLogs = []; 
  List<dynamic> _selectedDayLogs = []; 
  List<dynamic> _userHabitsCache = []; // Cache dei vizi per il form

  // Variabili Calcolate in locale per la Dashboard (Header)
  int _tdee = 0;
  double _potentialWealth30y = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // 1. Recupera tutto il necessario
      final profile = await supabase.from('profiles').select().eq('id', userId).single();
      final logs = await supabase.from('daily_logs').select().eq('user_id', userId).order('created_at', ascending: false);
      final habits = await supabase.from('habits').select().eq('user_id', userId);

      // --- CALCOLI LOCALI PER L'HEADER ---
      // Calcolo TDEE (Mifflin-St Jeor semplificato)
      double weight = (profile['weight_kg'] as num).toDouble();
      double height = (profile['height_cm'] as num).toDouble();
      int age = DateTime.now().year - DateTime.parse(profile['birth_date']).year;
      double bmr = (10 * weight) + (6.25 * height) - (5 * age) + (profile['gender'] == 'M' ? 5 : -161);
      double multiplier = profile['activity_level'] == 'Active' ? 1.55 : 1.2;
      int tdee = (bmr * multiplier).toInt();

      // Calcolo Potenziale Ricchezza (Basato sui vizi dichiarati nel profilo)
      double dailyWaste = 0.0;
      for (var h in habits) {
        dailyWaste += (h['cost_per_unit'] as num) * (h['current_daily_quantity'] as num);
      }
      double annualWaste = dailyWaste * 365;
      // Formula interesse composto 7% su 30 anni
      double wealth30y = annualWaste * (((1 + 0.07) * 30) - 1) / 0.07; // Approssimazione

      if (mounted) {
        setState(() {
          _profileData = profile;
          _allLogs = logs;
          _userHabitsCache = habits;
          _tdee = tdee;
          _potentialWealth30y = wealth30y;
          _updateSelectedDayLogs(_selectedDay);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Errore fetch: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  void _updateSelectedDayLogs(DateTime day) {
    setState(() {
      _selectedDayLogs = _allLogs.where((log) => isSameDay(DateTime.parse(log['date']), day)).toList();
    });
  }

  Future<void> _deleteLog(String logId) async {
    try {
      await Supabase.instance.client.from('daily_logs').delete().eq('id', logId);
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Log eliminato.")));
      }
    } catch (e) {}
  }

  void _showAddLogModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        // Passiamo i vizi caricati al form intelligente
        child: SmartInputForm(userHabits: _userHabitsCache),
      ),
    ).then((_) => _fetchData()); // Ricarica al ritorno
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
        title: const Text("DASHBOARD", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLogModal,
        backgroundColor: const Color(0xFF00E676),
        label: const Text("REGISTRA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.edit_note, color: Colors.black),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
        : Column(
            children: [
              // 1. HEADER STATS (TDEE & Soldi)
              _buildStatsHeader(),

              const SizedBox(height: 10),

              // 2. CALENDARIO
              _buildCalendar(),
              
              const Divider(color: Colors.white10, height: 20),
              
              // 3. TITOLO GIORNATA
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

              // 4. LISTA EVENTI
              Expanded(
                child: _selectedDayLogs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _selectedDayLogs.length,
                        itemBuilder: (context, index) => _buildLogCard(_selectedDayLogs[index]),
                      ),
              ),
            ],
          ),
    );
  }

  Widget _buildStatsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.bolt, color: Colors.blueAccent, size: 16), SizedBox(width: 5), Text("METABOLISMO", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 5),
                  Text("$_tdee Kcal", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text("TDEE Giornaliero", style: TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.trending_up, color: Color(0xFF00E676), size: 16), SizedBox(width: 5), Text("POTENZIALE", style: TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 5),
                  Text("€ ${( _potentialWealth30y / 1000).toStringAsFixed(1)}k", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text("In 30 anni (Stimato)", style: TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20)),
      child: TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: CalendarFormat.week,
        availableCalendarFormats: const {CalendarFormat.week: 'Settimana'},
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          _updateSelectedDayLogs(selectedDay);
        },
        eventLoader: (day) => _allLogs.where((log) => isSameDay(DateTime.parse(log['date']), day)).toList(),
        calendarStyle: const CalendarStyle(
          defaultTextStyle: TextStyle(color: Colors.white),
          weekendTextStyle: TextStyle(color: Colors.white70),
          todayDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
          selectedDecoration: BoxDecoration(color: Color(0xFF00E676), shape: BoxShape.circle),
          markerDecoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
          rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    IconData icon = Icons.circle;
    Color color = Colors.grey;
    String title = "Attività";
    String subtitle = "";
    
    if (log['log_type'] == 'vice_consumed') {
      double saved = (log['amount_saved'] as num).toDouble();
      if (saved > 0) { 
        icon = Icons.trending_up; 
        color = const Color(0xFF00E676); 
        title = "${log['sub_type']}: Risparmio"; 
        subtitle = "+ €${saved.toStringAsFixed(2)}"; 
      } else if (saved < 0) { 
        icon = Icons.warning_amber_rounded; 
        color = Colors.orangeAccent; 
        title = "${log['sub_type']}: Extra"; 
        subtitle = "- €${(saved * -1).toStringAsFixed(2)}"; 
      } else { 
        icon = Icons.horizontal_rule; 
        color = Colors.grey; 
        title = "${log['sub_type']}: Standard"; 
        subtitle = "0 €"; 
      }
    } else if (log['log_type'] == 'expense') {
      icon = Icons.money_off; 
      color = Colors.redAccent; 
      title = "Spesa: ${log['category']}"; 
      subtitle = "€${log['amount_saved']}";
    } else if (log['log_type'] == 'workout') {
      icon = Icons.fitness_center; 
      color = Colors.blueAccent; 
      title = "Sport: ${log['sub_type']}"; 
      subtitle = "${log['duration_min']} min";
    }

    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color, size: 20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white30, size: 18), onPressed: () => _deleteLog(log['id'])),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_note, size: 50, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 10),
          const Text("Nessun log.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// --- SMART INPUT FORM (CON AUTO-DISCOVERY) ---
class SmartInputForm extends StatefulWidget {
  final List<dynamic> userHabits; 
  const SmartInputForm({super.key, required this.userHabits});

  @override
  State<SmartInputForm> createState() => _SmartInputFormState();
}

class _SmartInputFormState extends State<SmartInputForm> {
  String _selectedType = 'vice_consumed'; 
  
  // Dati Vizio
  String? _selectedHabitId; // Null = Inserimento libero
  String _customHabitName = "Caffè"; 
  double _unitCost = 1.0;
  final _consumedQtyController = TextEditingController(text: "1");
  final _customCostController = TextEditingController(text: "1.00");

  final List<String> _commonSuggestions = ['Caffè', 'Sigaretta', 'Birra', 'Fast Food', 'Dolci', 'Scommesse'];

  // Dati Spesa/Sport
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _expenseCategory = 'Svago';
  bool _isNecessary = false;
  String _workoutType = 'Palestra';
  int _duration = 30;

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

  // --- PATTERN RECOGNITION ENGINE ---
  Future<void> _checkHiddenPattern(String habitName, String userId) async {
    final existing = widget.userHabits.any((h) => h['name'].toString().toLowerCase() == habitName.toLowerCase());
    if (existing) return;

    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final logs = await Supabase.instance.client
        .from('daily_logs')
        .select()
        .eq('user_id', userId)
        .eq('sub_type', habitName)
        .gte('created_at', sevenDaysAgo.toIso8601String());

    if (logs.length >= 2 && mounted) {
      _showDiscoveryDialog(habitName, userId);
    }
  }

  void _showDiscoveryDialog(String habitName, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(children: [Icon(Icons.visibility, color: Color(0xFF00E676)), SizedBox(width: 10), Text("Pattern Rilevato", style: TextStyle(color: Colors.white, fontSize: 18))]),
        content: Text(
          "L'algoritmo ha notato che hai inserito '$habitName' spesso.\nVuoi aggiungerlo al Piano Ufficiale?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.from('habits').insert({
                'user_id': userId,
                'name': habitName,
                'cost_per_unit': double.tryParse(_customCostController.text) ?? 1.0,
                'current_daily_quantity': 1,
                'target_daily_quantity': 0
              });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$habitName tracciato!")));
            }, 
            child: const Text("Sì, traccia", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
          )
        ],
      ),
    );
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
      data['note'] = "Consumati: $consumed (Media: $baseline)";
      data['category'] = 'Vizio';

    } else if (_selectedType == 'expense') {
      data['amount_saved'] = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
      data['category'] = _expenseCategory;
      data['is_necessary'] = _isNecessary;
    } else if (_selectedType == 'workout') {
      data['sub_type'] = _workoutType;
      data['duration_min'] = _duration;
    }

    try {
      await Supabase.instance.client.from('daily_logs').insert(data);
      
      if (_selectedType == 'vice_consumed') {
        await _checkHiddenPattern(_customHabitName, userId);
      }

      if (mounted) Navigator.pop(context); 
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
          
          Row(
            children: [
              _typeButton("Vizio", Icons.smoke_free, 'vice_consumed', const Color(0xFF00E676)),
              const SizedBox(width: 10),
              _typeButton("Spesa", Icons.euro, 'expense', Colors.redAccent),
              const SizedBox(width: 10),
              _typeButton("Sport", Icons.fitness_center, 'workout', Colors.blueAccent),
            ],
          ),
          
          const Divider(color: Colors.white10, height: 30),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  
                  // --- FORM VIZI IBRIDO ---
                  if (_selectedType == 'vice_consumed') ...[
                    if (widget.userHabits.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedHabitId,
                        dropdownColor: const Color(0xFF1E1E1E),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "Vizi Tracciati", border: OutlineInputBorder()),
                        items: [
                          ...widget.userHabits.map((h) => DropdownMenuItem(value: h['id'].toString(), child: Text(h['name']))),
                          const DropdownMenuItem(value: null, child: Text("+ Altro / Nuovo Vizio", style: TextStyle(color: Color(0xFF00E676)))),
                        ],
                        onChanged: (v) {
                          if (v != null) _selectUserHabit(widget.userHabits.firstWhere((h) => h['id'] == v));
                          else setState(() { _selectedHabitId = null; _customHabitName = ""; _customCostController.text = ""; });
                        },
                      ),
                      const SizedBox(height: 15),
                    ],

                    if (_selectedHabitId == null) ...[
                      const Text("Inserimento Libero", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        children: _commonSuggestions.map((s) => ActionChip(
                          label: Text(s),
                          backgroundColor: Colors.white10,
                          labelStyle: const TextStyle(color: Colors.white),
                          onPressed: () => setState(() => _customHabitName = s),
                        )).toList(),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        onChanged: (v) => _customHabitName = v,
                        controller: TextEditingController(text: _customHabitName),
                        decoration: const InputDecoration(labelText: "Nome Vizio", prefixIcon: Icon(Icons.edit, color: Colors.white70)),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _customCostController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: "Costo Singolo (€)", prefixIcon: Icon(Icons.euro, color: Colors.white70)),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                    ],

                    const Text("Consumo di Oggi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _consumedQtyController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers, color: Colors.white)),
                    ),
                  ],

                  // --- FORM SPESE ---
                  if (_selectedType == 'expense') ...[
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                      decoration: const InputDecoration(labelText: "Importo (€)", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _expenseCategory,
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white),
                      items: ['Cibo', 'Trasporti', 'Svago', 'Bollette', 'Shopping'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _expenseCategory = v!),
                      decoration: const InputDecoration(labelText: "Categoria", border: OutlineInputBorder()),
                    ),
                    SwitchListTile(
                      title: const Text("Era necessaria?", style: TextStyle(color: Colors.white)),
                      value: _isNecessary,
                      activeColor: const Color(0xFF00E676),
                      onChanged: (v) => setState(() => _isNecessary = v),
                    ),
                  ],

                  // --- FORM SPORT ---
                  if (_selectedType == 'workout') ...[
                    DropdownButtonFormField<String>(
                      value: _workoutType,
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white),
                      items: ['Palestra', 'Corsa', 'Nuoto', 'Yoga', 'Camminata'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _workoutType = v!),
                      decoration: const InputDecoration(labelText: "Attività", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),
                    Text("Durata: $_duration min", style: const TextStyle(color: Colors.white)),
                    Slider(
                      value: _duration.toDouble(),
                      min: 10, max: 180, divisions: 17,
                      activeColor: Colors.blueAccent,
                      onChanged: (v) => setState(() => _duration = v.toInt()),
                    ),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveLog,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              child: _isSaving ? const CircularProgressIndicator() : const Text("REGISTRA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _typeButton(String label, IconData icon, String type, Color color) {
    bool isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.white10,
            border: Border.all(color: isSelected ? color : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey),
              const SizedBox(height: 5),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}