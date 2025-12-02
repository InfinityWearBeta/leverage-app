import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SmartInputForm extends StatefulWidget {
  final List<dynamic> userHabits; 
  const SmartInputForm({super.key, required this.userHabits});

  @override
  State<SmartInputForm> createState() => _SmartInputFormState();
}

class _SmartInputFormState extends State<SmartInputForm> {
  String _selectedType = 'vice_consumed'; 
  
  // Dati Vizio
  String? _selectedHabitId; 
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

  // AGGIORNAMENTO SALDO (Spostato qui per pulizia)
  Future<void> _updateUserBalance(String userId, double amountSpent) async {
    final profile = await Supabase.instance.client.from('profiles').select('current_savings').eq('id', userId).single();
    double current = (profile['current_savings'] as num).toDouble();
    double newBalance = current - amountSpent;
    await Supabase.instance.client.from('profiles').update({'current_savings': newBalance}).eq('id', userId);
  }

  Future<void> _checkHiddenPattern(String habitName, String userId) async {
    // Logica Pattern Recognition semplificata
    // ... (implementazione pattern recognition se necessaria, per ora focus su stabilità)
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
      
      // Se delta è negativo (ho speso extra), calcoliamo la spesa
      // O più semplicemente: se consumo un vizio, pago.
      amountSpentReal = consumed * _unitCost;

    } else if (_selectedType == 'expense') {
      double amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
      data['amount_saved'] = amount; 
      data['category'] = _expenseCategory;
      data['is_necessary'] = _isNecessary;
      amountSpentReal = amount;
    } else if (_selectedType == 'workout') {
      data['sub_type'] = _workoutType;
      data['duration_min'] = _duration;
    }

    try {
      await Supabase.instance.client.from('daily_logs').insert(data);
      
      // AGGIORNA IL SALDO SU SUPABASE
      if (amountSpentReal > 0) {
        await _updateUserBalance(userId, amountSpentReal);
      }

      // Ritorna TRUE per dire alla Dashboard di ricaricare tutto
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
            _typeButton("Sport", Icons.fitness_center, 'workout', Colors.blueAccent),
          ]),
          const Divider(color: Colors.white10, height: 30),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
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
                  if (_selectedType == 'expense') ...[
                    TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Importo (€)", border: OutlineInputBorder()), style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(value: _expenseCategory, dropdownColor: const Color(0xFF1E1E1E), style: const TextStyle(color: Colors.white), items: ['Cibo', 'Trasporti', 'Svago', 'Bollette'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _expenseCategory = v!), decoration: const InputDecoration(labelText: "Categoria", border: OutlineInputBorder())),
                    SwitchListTile(title: const Text("Era necessaria?", style: TextStyle(color: Colors.white)), value: _isNecessary, activeColor: const Color(0xFF00E676), onChanged: (v) => setState(() => _isNecessary = v)),
                  ],
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