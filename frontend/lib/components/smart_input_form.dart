import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SmartInputForm extends StatefulWidget {
  final List<dynamic> userHabits; 
  // NUOVO v8.1: Lista spese fisse per il pagamento
  final List<dynamic> userExpenses; 

  const SmartInputForm({
    super.key, 
    required this.userHabits,
    required this.userExpenses
  });

  @override
  State<SmartInputForm> createState() => _SmartInputFormState();
}

class _SmartInputFormState extends State<SmartInputForm> {
  // Stati UI
  String _selectedType = 'vice_consumed'; // Default
  bool _isSaving = false;

  // --- CONTROLLERS ---
  // Vizi
  String? _selectedHabitId; 
  String _customHabitName = "Caffè"; 
  double _unitCost = 1.0;
  final _consumedQtyController = TextEditingController(text: "1");
  final _customCostController = TextEditingController(text: "1.00");

  // Spese & Bollette
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _expenseCategory = 'Svago';
  bool _isNecessary = false;
  
  // NUOVO v8.1: ID Bolletta selezionata
  String? _selectedBillId; 

  // Sport
  String _workoutType = 'Palestra';
  int _duration = 30;

  @override
  void initState() {
    super.initState();
    // Pre-selezione del primo vizio se esiste
    if (widget.userHabits.isNotEmpty) {
      _selectUserHabit(widget.userHabits[0]);
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

  Future<void> _saveLog() async {
    setState(() => _isSaving = true);
    final userId = Supabase.instance.client.auth.currentUser!.id;

    Map<String, dynamic> data = {
      'user_id': userId,
      'log_type': _selectedType,
      'date': DateTime.now().toIso8601String(),
      'note': _noteController.text,
    };

    double amountToDecrement = 0.0; 

    // --- LOGICA 1: VIZI (Bio-Finance) ---
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
      
      // Se consumo un vizio, pago il costo reale
      amountToDecrement = consumed * _unitCost;

    // --- LOGICA 2: SPESA GENERICA ---
    } else if (_selectedType == 'expense') {
      double amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
      data['amount_saved'] = amount; 
      data['category'] = _expenseCategory;
      data['is_necessary'] = _isNecessary;
      amountToDecrement = amount;

    // --- LOGICA 3: PAGAMENTO BOLLETTA (Core v8.1) ---
    } else if (_selectedType == 'bill_payment') {
       if (_selectedBillId == null) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Seleziona la bolletta da pagare!")));
         setState(() => _isSaving = false);
         return;
       }
       double amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
       
       // Salviamo come 'expense' ma con il puntatore speciale
       data['log_type'] = 'expense'; 
       data['amount_saved'] = amount;
       data['category'] = 'Bollette';
       data['related_fixed_expense_id'] = _selectedBillId; // <--- IL LINK AL BACKEND
       data['is_necessary'] = true;
       
       amountToDecrement = amount;
    
    // --- LOGICA 4: SPORT ---
    } else if (_selectedType == 'workout') {
      data['sub_type'] = _workoutType;
      data['duration_min'] = _duration;
    }

    try {
      // 1. Inserimento Log
      await Supabase.instance.client.from('daily_logs').insert(data);
      
      // 2. Aggiornamento Atomico Saldo (RPC)
      if (amountToDecrement > 0) {
        await Supabase.instance.client.rpc('decrement_balance', params: {
          'user_id': userId, 
          'amount': amountToDecrement
        });
      }

      if (mounted) Navigator.pop(context, true); // Chiude e ricarica
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Errore: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      height: 700, 
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("REGISTRA ATTIVITÀ", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          
          // BARRA DI SELEZIONE TIPO
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _typeButton("Vizio", Icons.smoke_free, 'vice_consumed', const Color(0xFF00E676)),
              const SizedBox(width: 10),
              _typeButton("Spesa", Icons.euro, 'expense', Colors.redAccent),
              const SizedBox(width: 10),
              _typeButton("Bolletta", Icons.receipt_long, 'bill_payment', Colors.orange), // TASTO v8.1
              const SizedBox(width: 10),
              _typeButton("Sport", Icons.fitness_center, 'workout', Colors.blueAccent),
            ]),
          ),
          
          const Divider(color: Colors.white10, height: 30),
          
          // AREA INPUT DINAMICA
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  
                  // UI VIZI
                  if (_selectedType == 'vice_consumed') ...[
                    if (widget.userHabits.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedHabitId,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDeco("Seleziona Vizio"),
                        items: [...widget.userHabits.map((h) => DropdownMenuItem(value: h['id'].toString(), child: Text(h['name']))), const DropdownMenuItem(value: null, child: Text("+ Altro"))], 
                        onChanged: (v) { 
                          if (v != null) _selectUserHabit(widget.userHabits.firstWhere((h) => h['id'] == v)); 
                          else setState(() { _selectedHabitId = null; }); 
                        }
                      ),
                      const SizedBox(height: 15),
                    ],
                    if (_selectedHabitId == null) ...[
                      TextField(onChanged: (v) => _customHabitName = v, controller: TextEditingController(text: _customHabitName), decoration: _inputDeco("Nome Vizio"), style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 10),
                      TextField(controller: _customCostController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _inputDeco("Costo Unitario (€)"), style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 20),
                    ],
                    TextField(controller: _consumedQtyController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold), textAlign: TextAlign.center, decoration: _inputDeco("Quantità")),
                  ],

                  // UI BOLLETTE (v8.1)
                  if (_selectedType == 'bill_payment') ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                      child: const Row(children: [
                        Icon(Icons.lock_open, color: Colors.orange, size: 20),
                        SizedBox(width: 10),
                        Expanded(child: Text("Pagando una bolletta specifica sblocchi la differenza tra la stima pessimistica e il reale.", style: TextStyle(color: Colors.orangeAccent, fontSize: 12)))
                      ]),
                    ),
                    const SizedBox(height: 20),
                    if (widget.userExpenses.isEmpty)
                      const Text("Nessuna spesa fissa configurata.", style: TextStyle(color: Colors.grey))
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedBillId,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDeco("Quale Bolletta?"),
                        items: widget.userExpenses.map((e) => DropdownMenuItem(value: e['id'].toString(), child: Text("${e['name']} (Max €${e['max_amount']})"))).toList(),
                        onChanged: (v) => setState(() => _selectedBillId = v),
                      ),
                    const SizedBox(height: 15),
                    TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: _inputDeco("Importo Reale Pagato (€)")),
                  ],

                  // UI SPESA GENERICA
                  if (_selectedType == 'expense') ...[
                    TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _inputDeco("Importo (€)"), style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _expenseCategory,
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white),
                      items: ['Cibo', 'Trasporti', 'Svago', 'Bollette'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _expenseCategory = v!),
                      decoration: _inputDeco("Categoria")
                    ),
                    SwitchListTile(title: const Text("Era necessaria?", style: TextStyle(color: Colors.white)), value: _isNecessary, activeColor: const Color(0xFF00E676), onChanged: (v) => setState(() => _isNecessary = v)),
                  ],

                  // UI SPORT
                  if (_selectedType == 'workout') ...[
                    DropdownButtonFormField<String>(value: _workoutType, dropdownColor: const Color(0xFF2C2C2C), style: const TextStyle(color: Colors.white), items: ['Palestra', 'Corsa', 'Nuoto', 'Yoga'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _workoutType = v!), decoration: _inputDeco("Attività")),
                    const SizedBox(height: 20),
                    Slider(value: _duration.toDouble(), min: 10, max: 180, divisions: 17, activeColor: Colors.blueAccent, onChanged: (v) => setState(() => _duration = v.toInt())),
                    Text("Durata: $_duration min", style: const TextStyle(color: Colors.white)),
                  ],
                ],
              ),
            ),
          ),
          
          // BOTTONE REGISTRA
          Container(
            padding: const EdgeInsets.only(bottom: 20, top: 10),
            width: double.infinity, 
            height: 80, 
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveLog, 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), 
              child: _isSaving 
                ? const CircularProgressIndicator() 
                : const Text("REGISTRA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16))
            )
          )
        ],
      ),
    );
  }

  // Helper per lo stile
  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label, labelStyle: const TextStyle(color: Colors.grey),
      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white10), borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF00E676)), borderRadius: BorderRadius.circular(10)),
      filled: true, fillColor: Colors.white.withOpacity(0.05)
    );
  }

  Widget _typeButton(String label, IconData icon, String type, Color color) {
    bool isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type), 
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), 
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.white10, 
          border: Border.all(color: isSelected ? color : Colors.transparent), 
          borderRadius: BorderRadius.circular(10)
        ), 
        child: Column(children: [
          Icon(icon, color: isSelected ? color : Colors.grey, size: 24), 
          const SizedBox(height: 5), 
          Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))
        ])
      )
    );
  }
}