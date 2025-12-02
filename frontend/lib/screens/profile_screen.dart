import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  List<dynamic> _investments = [];
  List<dynamic> _expenses = [];

  // Metriche Calcolate
  double _totalNetWorth = 0.0; // Tutto (Liquido + Bloccato)
  double _liquidAssets = 0.0;  // Solo quello disponibile
  double _monthlyFixedBurn = 0.0; 
  double _freeCashFlow = 0.0;     

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final profile = await Supabase.instance.client.from('profiles').select().eq('id', userId).single();
      final investments = await Supabase.instance.client.from('investments').select().eq('user_id', userId);
      final expenses = await Supabase.instance.client.from('fixed_expenses').select().eq('user_id', userId).order('name', ascending: true);

      // --- CALCOLI AVANZATI ---
      
      double totalInvested = 0.0;
      double lockedInvested = 0.0;

      for (var item in investments) {
        double val = (item['amount'] as num).toDouble();
        totalInvested += val;
        if (item['is_locked'] == true) {
          lockedInvested += val;
        }
      }

      double currentSavings = (profile['current_savings'] as num?)?.toDouble() ?? 0.0;
      
      // Calcolo Liquidità Reale (Risparmi + Investimenti NON bloccati)
      double liquidAssets = currentSavings + (totalInvested - lockedInvested);
      
      // Calcolo Patrimonio Totale (Inclusi i bloccati)
      double totalNetWorth = currentSavings + totalInvested; // Nota: Non sommiamo la pensione qui se vuoi tenerla proprio a parte, ma tecnicamente è Net Worth.

      // Burn Rate Mensile
      double monthlyBurn = 0.0;
      for (var item in expenses) {
        double amount = 0.0;
        if (item['is_variable'] == true) {
          double min = (item['min_amount'] as num?)?.toDouble() ?? 0.0;
          double max = (item['max_amount'] as num?)?.toDouble() ?? 0.0;
          amount = (min + max) / 2;
        } else {
          amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
        }
        List<dynamic> months = item['payment_months'] ?? [];
        int paymentsPerYear = months.isNotEmpty ? months.length : 12; 
        monthlyBurn += (amount * paymentsPerYear) / 12;
      }

      double income = (profile['monthly_income'] as num?)?.toDouble() ?? 0.0;
      double freeCash = income - monthlyBurn;

      if (mounted) {
        setState(() {
          _profile = profile;
          _investments = investments;
          _expenses = expenses;
          _totalNetWorth = totalNetWorth;
          _liquidAssets = liquidAssets;
          _monthlyFixedBurn = monthlyBurn;
          _freeCashFlow = freeCash;
          _isLoading = false;
        });
      }
    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
      print("Errore fetch profile: $e");
    }
  }

  // --- AZIONI ---

  Future<void> _updateProfileField(String field, String label, String currentValue, {bool isText = false}) async {
    final controller = TextEditingController(text: currentValue.toString());
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("Modifica $label", style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: isText ? TextInputType.text : TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Nuovo valore",
            labelStyle: const TextStyle(color: Colors.grey),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676))),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
            onPressed: () async {
              try {
                final userId = Supabase.instance.client.auth.currentUser!.id;
                dynamic value = isText ? controller.text : (double.tryParse(controller.text) ?? 0.0);
                await Supabase.instance.client.from('profiles').update({field: value}).eq('id', userId);
                Navigator.pop(context);
                _fetchAllData();
              } catch (e) { print(e); }
            }, 
            child: const Text("Salva", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  // --- MODAL INVESTIMENTO (CON CHECKBOX "BLOCCATO") ---
  void _showInvestmentDialog({Map<String, dynamic>? existingItem}) {
    final isEditing = existingItem != null;
    final nameCtrl = TextEditingController(text: existingItem?['name'] ?? '');
    final amountCtrl = TextEditingController(text: existingItem?['amount']?.toString() ?? '');
    String category = existingItem?['category'] ?? 'Azioni';
    
    // Nuovo Stato Locale per il Checkbox
    bool isLocked = existingItem?['is_locked'] ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder( // StatefulBuilder serve per aggiornare il checkbox nel dialog
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Text(isEditing ? "Modifica Investimento" : "Nuovo Investimento", style: const TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome", labelStyle: TextStyle(color: Colors.grey))),
                TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Valore (€)", labelStyle: TextStyle(color: Colors.grey))),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(color: Colors.white),
                  items: ['Azioni', 'ETF', 'Obbligazioni', 'Crypto', 'Liquidità', 'Immobili', 'Pensione Integrativa', 'Altro'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setDialogState(() => category = v!),
                  decoration: const InputDecoration(labelText: "Categoria"),
                ),
                const SizedBox(height: 15),
                
                // SWITCH BLOCCATO
                SwitchListTile(
                  title: const Text("Fondi Bloccati?", style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text("Attiva se non puoi prelevare questi soldi oggi (es. Vincolo, Staking, Pensione).", style: TextStyle(color: Colors.grey, fontSize: 10)),
                  value: isLocked,
                  activeThumbColor: Colors.orangeAccent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setDialogState(() => isLocked = val),
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annulla")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
                onPressed: () async {
                  final data = {
                    'user_id': Supabase.instance.client.auth.currentUser!.id,
                    'name': nameCtrl.text,
                    'amount': double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0,
                    'category': category,
                    'is_locked': isLocked // Salviamo lo stato
                  };
                  
                  if (isEditing) {
                    await Supabase.instance.client.from('investments').update(data).eq('id', existingItem['id']);
                  } else {
                    await Supabase.instance.client.from('investments').insert(data);
                  }
                  Navigator.pop(ctx);
                  _fetchAllData();
                }, 
                child: const Text("Salva", style: TextStyle(color: Colors.black))
              )
            ],
          );
        }
      ),
    );
  }

  void _showExpenseDialog({Map<String, dynamic>? existingItem}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ExpenseForm(
          existingItem: existingItem, 
          onSave: () {
            Navigator.pop(context);
            _fetchAllData();
          }
        ),
      ),
    );
  }

  Future<void> _deleteItem(String table, String id) async {
    await Supabase.instance.client.from(table).delete().eq('id', id);
    _fetchAllData();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));

    final birthDate = DateTime.tryParse(_profile?['birth_date'] ?? '') ?? DateTime.now();
    final age = DateTime.now().year - birthDate.year;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text("ASSETTO FINANZIARIO", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: _logout)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER USER
            Center(
              child: Column(
                children: [
                  CircleAvatar(radius: 40, backgroundColor: const Color(0xFF1E1E1E), child: const Icon(Icons.person, size: 40, color: Color(0xFF00E676))),
                  const SizedBox(height: 10),
                  Text(Supabase.instance.client.auth.currentUser?.email ?? "Utente", style: const TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 1. DASHBOARD FLUSSO DI CASSA
            _sectionHeader("SITUAZIONE ATTUALE", Icons.account_balance_wallet, const Color(0xFF00E676)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  // Prima Riga: Liquidità vs Totale
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("DISPONIBILE OGGI", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text("€ ${_liquidAssets.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))
                      ]),
                      Container(width: 1, height: 30, color: Colors.white24),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text("PATRIMONIO TOTALE", style: TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold)),
                        Text("€ ${_totalNetWorth.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))
                      ]),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 30),
                  // Seconda Riga: Stipendio
                  _buildProfileTile("Stipendio Netto", "€ ${_profile?['monthly_income'] ?? 0}", Icons.attach_money, 
                    () => _updateProfileField('monthly_income', 'Stipendio (€)', (_profile?['monthly_income'] ?? 0).toString())),
                  _divider(),
                  _buildProfileTile("Risparmi C/C", "€ ${_profile?['current_savings'] ?? 0}", Icons.savings, 
                    () => _updateProfileField('current_savings', 'Risparmi (€)', (_profile?['current_savings'] ?? 0).toString())),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 2. INVESTIMENTI (Con indicatore Bloccato)
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_sectionTitle("Portafoglio Investimenti", Icons.pie_chart), IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF00E676)), onPressed: () => _showInvestmentDialog())]),
            if (_investments.isEmpty) const Text("Nessun investimento.", style: TextStyle(color: Colors.grey)),
            ..._investments.map((inv) => _investmentTile(inv)),

            const SizedBox(height: 30),

            // 3. SPESE FISSE
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_sectionTitle("Spese Fisse & Ricorrenti", Icons.credit_card), IconButton(icon: const Icon(Icons.add_circle, color: Colors.redAccent), onPressed: () => _showExpenseDialog())]),
            if (_expenses.isEmpty) const Text("Nessuna spesa fissa.", style: TextStyle(color: Colors.grey)),
            ..._expenses.map((exp) => _expenseTile(exp)),

            const SizedBox(height: 30),

            // 4. BIOMETRIA
            _sectionHeader("ASSETTO BIOMETRICO", Icons.accessibility_new, Colors.blueAccent),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _buildProfileTile("Peso", "${_profile?['weight_kg'] ?? 0} Kg", Icons.monitor_weight, () => _updateProfileField('weight_kg', 'Peso (Kg)', (_profile?['weight_kg'] ?? 0).toString())),
                  _divider(),
                  _buildProfileTile("Altezza", "${_profile?['height_cm'] ?? 0} cm", Icons.height, () => _updateProfileField('height_cm', 'Altezza (cm)', (_profile?['height_cm'] ?? 0).toString())),
                  _divider(),
                  _buildProfileTile("Età", "$age Anni", Icons.cake, null), 
                ],
              ),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // WIDGET HELPER
  Widget _sectionHeader(String title, IconData icon, Color color) => Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 8), Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5))]);
  Widget _sectionTitle(String title, IconData icon) => Row(children: [Icon(icon, color: Colors.grey, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))]);
  Widget _divider() => const Divider(color: Colors.white10, height: 1);

  Widget _buildProfileTile(String title, String value, IconData icon, VoidCallback? onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white54, size: 20),
      title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), if (onTap != null) ...[const SizedBox(width: 10), const Icon(Icons.edit, color: Colors.white30, size: 16)]]),
      onTap: onTap,
    );
  }

  Widget _investmentTile(Map<String, dynamic> item) {
    bool isLocked = item['is_locked'] == true;
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(isLocked ? Icons.lock : Icons.lock_open, color: isLocked ? Colors.orange : const Color(0xFF00E676)),
        title: Text(item['name'] ?? "Investimento", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(item['category'] ?? "Generico", style: const TextStyle(color: Colors.grey)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text("€ ${item['amount']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 20), onPressed: () => _showInvestmentDialog(existingItem: item)), 
          IconButton(icon: const Icon(Icons.delete, color: Colors.white30, size: 20), onPressed: () => _deleteItem('investments', item['id'])),
        ]),
      ),
    );
  }

  Widget _expenseTile(Map<String, dynamic> item) {
    String costText = "€ ${item['amount']}";
    if (item['is_variable'] == true) {
      costText = "€ ${item['min_amount']} - ${item['max_amount']}";
    }
    
    List<dynamic> months = item['payment_months'] ?? [];
    String freqText = "Personalizzato";
    if (months.length == 12) {
      freqText = "Mensile";
    } else if (months.length == 1) freqText = "Annuale";
    else if (months.isNotEmpty) freqText = "${months.length} pagamenti/anno";
    else freqText = item['frequency'] ?? "Non specificato"; 

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: Colors.redAccent),
        title: Text(item['name'] ?? "Spesa", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text("$freqText • ${item['is_variable'] == true ? 'Variabile' : 'Fisso'}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(costText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 10),
          IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 20), onPressed: () => _showExpenseDialog(existingItem: item)),
          IconButton(icon: const Icon(Icons.delete, color: Colors.white30, size: 20), onPressed: () => _deleteItem('fixed_expenses', item['id'])),
        ]),
      ),
    );
  }
}

// (La classe ExpenseForm rimane identica a quella che ti ho dato nel messaggio precedente,
// ma per sicurezza la includo qui per avere un file unico funzionante)

class ExpenseForm extends StatefulWidget {
  final Map<String, dynamic>? existingItem;
  final VoidCallback onSave;
  const ExpenseForm({super.key, this.existingItem, required this.onSave});

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  
  bool _isVariable = false;
  List<int> _selectedMonths = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  final List<String> _monthsLabels = ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      _nameCtrl.text = widget.existingItem!['name'];
      _isVariable = widget.existingItem!['is_variable'] ?? false;
      _selectedMonths = List<int>.from(widget.existingItem!['payment_months'] ?? []);
      
      if (_isVariable) {
        _minCtrl.text = widget.existingItem!['min_amount'].toString();
        _maxCtrl.text = widget.existingItem!['max_amount'].toString();
      } else {
        _amountCtrl.text = widget.existingItem!['amount'].toString();
      }
    }
  }

  Future<void> _save() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    
    Map<String, dynamic> data = {
      'user_id': userId,
      'name': _nameCtrl.text,
      'is_variable': _isVariable,
      'payment_months': _selectedMonths,
      'frequency': 'Custom'
    };

    if (_isVariable) {
      data['min_amount'] = double.tryParse(_minCtrl.text.replaceAll(',', '.')) ?? 0.0;
      data['max_amount'] = double.tryParse(_maxCtrl.text.replaceAll(',', '.')) ?? 0.0;
      data['amount'] = 0;
    } else {
      data['amount'] = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    }

    if (widget.existingItem != null) {
      await Supabase.instance.client.from('fixed_expenses').update(data).eq('id', widget.existingItem!['id']);
    } else {
      await Supabase.instance.client.from('fixed_expenses').insert(data);
    }
    
    widget.onSave();
  }

  void _toggleMonth(int index) {
    setState(() {
      if (_selectedMonths.contains(index + 1)) {
        _selectedMonths.remove(index + 1);
      } else {
        _selectedMonths.add(index + 1);
        _selectedMonths.sort();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existingItem != null ? "MODIFICA SPESA" : "NUOVA SPESA FISSA", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome", prefixIcon: Icon(Icons.edit, color: Colors.grey))),
          const SizedBox(height: 15),
          SwitchListTile(title: const Text("Importo Variabile?", style: TextStyle(color: Colors.white)), value: _isVariable, activeThumbColor: const Color(0xFF00E676), onChanged: (v) => setState(() => _isVariable = v)),
          const SizedBox(height: 10),
          if (_isVariable) 
            Row(children: [Expanded(child: TextField(controller: _minCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Min (€)", prefixIcon: Icon(Icons.arrow_downward, color: Colors.green)))), const SizedBox(width: 10), Expanded(child: TextField(controller: _maxCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Max (€)", prefixIcon: Icon(Icons.arrow_upward, color: Colors.redAccent))))])
          else
            TextField(controller: _amountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Importo Fisso (€)", prefixIcon: Icon(Icons.euro, color: Colors.white))),
          const SizedBox(height: 20),
          const Text("Mesi di Pagamento", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: List.generate(12, (index) { bool isSelected = _selectedMonths.contains(index + 1); return FilterChip(label: Text(_monthsLabels[index]), selected: isSelected, selectedColor: const Color(0xFF00E676).withOpacity(0.3), checkmarkColor: const Color(0xFF00E676), labelStyle: TextStyle(color: isSelected ? const Color(0xFF00E676) : Colors.grey), backgroundColor: Colors.white10, onSelected: (_) => _toggleMonth(index)); })),
          const Spacer(),
          ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: Colors.white), child: const Text("SALVA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))
        ],
      ),
    );
  }
}