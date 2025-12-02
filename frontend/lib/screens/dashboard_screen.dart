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
  DateTime? _selectedDay;
  Map<String, dynamic>? _profileData;
  
  // Qui salveremo i log scaricati dal DB per colorare il calendario
  List<dynamic> _dailyLogs = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchData();
  }

  Future<void> _fetchData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // 1. Scarica Profilo (per i calcoli totali)
    final profile = await Supabase.instance.client.from('profiles').select().eq('id', userId).single();
    
    // 2. Scarica i Log del mese corrente (per il calendario)
    final logs = await Supabase.instance.client
        .from('daily_logs')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        _profileData = profile;
        _dailyLogs = logs;
        _isLoading = false;
      });
    }
  }

  // Funzione per registrare una nuova azione
  void _showAddLogModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        height: 350,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("AGGIUNGI AL DIARIO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _actionButton("Vizio Evitato", Icons.check_circle, const Color(0xFF00E676), () => _logAction('vice_avoided')),
                _actionButton("Spesa", Icons.attach_money, Colors.redAccent, () => _logAction('expense')),
                _actionButton("Sport", Icons.fitness_center, Colors.blueAccent, () => _logAction('workout')),
              ],
            ),
            const SizedBox(height: 20),
            const Text("Registrare le tue azioni quotidiane è il primo passo per prendere il controllo.", 
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // Logica semplificata per inserire un dato (Mockup funzionale)
  Future<void> _logAction(String type) async {
    Navigator.pop(context); // Chiudi modale
    setState(() => _isLoading = true);
    
    final userId = Supabase.instance.client.auth.currentUser!.id;
    
    // Esempio: Registriamo una vittoria standard
    await Supabase.instance.client.from('daily_logs').insert({
      'user_id': userId,
      'log_type': type,
      'date': DateTime.now().toIso8601String(),
      'note': 'Inserimento rapido da Home',
      'amount_saved': type == 'vice_avoided' ? 5.0 : 0.0, // Valore fittizio per test
    });

    await _fetchData(); // Ricarica tutto
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Diario Aggiornato!")));
    }
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
        title: const Text("DASHBOARD", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLogModal,
        backgroundColor: const Color(0xFF00E676),
        label: const Text("REGISTRA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, color: Colors.black),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
        : SingleChildScrollView(
            child: Column(
              children: [
                // 1. CALENDARIO (L'Effetto Wow della consistenza)
                _buildCalendar(),
                
                const SizedBox(height: 20),
                
                // 2. SUMMARY CARDS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: _summaryCard("Vittorie", "${_dailyLogs.where((l) => l['log_type'] == 'vice_avoided').length}", const Color(0xFF00E676))),
                      const SizedBox(width: 15),
                      Expanded(child: _summaryCard("Attività", "${_dailyLogs.length}", Colors.blueAccent)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. DIARIO RECENTE (Lista)
                _buildRecentLogs(),
              ],
            ),
          ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.week, // Compatto
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        calendarStyle: const CalendarStyle(
          defaultTextStyle: TextStyle(color: Colors.white),
          weekendTextStyle: TextStyle(color: Colors.white70),
          todayDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
          selectedDecoration: BoxDecoration(color: Color(0xFF00E676), shape: BoxShape.circle),
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

  Widget _buildRecentLogs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("ATTIVITÀ RECENTI", style: TextStyle(color: Colors.white54, letterSpacing: 1.5, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ..._dailyLogs.take(5).map((log) {
            IconData icon = Icons.info;
            Color color = Colors.grey;
            String title = "Attività";

            if (log['log_type'] == 'vice_avoided') { icon = Icons.check_circle; color = const Color(0xFF00E676); title = "Vizio Evitato"; }
            if (log['log_type'] == 'workout') { icon = Icons.fitness_center; color = Colors.blueAccent; title = "Allenamento"; }
            if (log['log_type'] == 'expense') { icon = Icons.money_off; color = Colors.redAccent; title = "Spesa Registrata"; }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(DateFormat('dd/MM - HH:mm').format(DateTime.parse(log['created_at'])), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}