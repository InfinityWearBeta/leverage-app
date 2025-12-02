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
      final expenses = await Supabase.instance.client.from('fixed_expenses').select().eq('user_id', userId);

      if (mounted) {
        setState(() {
          _profile = profile;
          _investments = investments;
          _expenses = expenses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
      print("Errore: $e");
    }
  }

  // --- LOGICA AGGIORNAMENTO ---
  Future<void> _updateField(String table, String field, dynamic value, {String? id}) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    try {
      if (table == 'profiles') {
        await Supabase.instance.client.from('profiles').update({field: value}).eq('id', userId);
      }
      _fetchAllData();
    } catch (e) {
      print(e);
    }
  }

  Future<void> _deleteItem(String table, String id) async {
    await Supabase.instance.client.from(table).delete().eq('id', id);
    _fetchAllData();
  }

  // --- MODAL AGGIUNGI INVESTIMENTO ---
  void _showAddInvestment() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = 'Azioni'; // Default

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Nuovo Investimento", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome (es. Apple)", labelStyle: TextStyle(color: Colors.grey))),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Valore (€)", labelStyle: TextStyle(color: Colors.grey))),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: category,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white),
              items: ['Azioni', 'ETF', 'Obbligazioni', 'Crypto', 'Materie Prime', 'Immobili', 'Altro']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => category = v!,
              decoration: const InputDecoration(labelText: "Categoria", border: OutlineInputBorder()),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annulla")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
            onPressed: () async {
              await Supabase.instance.client.from('investments').insert({
                'user_id': Supabase.instance.client.auth.currentUser!.id,
                'name': nameCtrl.text,
                'amount': double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0,
                'category': category
              });
              Navigator.pop(ctx);
              _fetchAllData();
            }, 
            child: const Text("Salva", style: TextStyle(color: Colors.black))
          )
        ],
      ),
    );
  }

  // --- MODAL AGGIUNGI SPESA FISSA ---
  void _showAddExpense() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String frequency = 'Mensile'; // Default

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Spesa Fissa / Abbonamento", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome (es. Spotify)", labelStyle: TextStyle(color: Colors.grey))),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Costo (€)", labelStyle: TextStyle(color: Colors.grey))),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: frequency,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white),
              items: ['Mensile', 'Bimestrale', 'Trimestrale', 'Semestrale', 'Annuale']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => frequency = v!,
              decoration: const InputDecoration(labelText: "Ogni quanto?", border: OutlineInputBorder()),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annulla")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await Supabase.instance.client.from('fixed_expenses').insert({
                'user_id': Supabase.instance.client.auth.currentUser!.id,
                'name': nameCtrl.text,
                'amount': double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0,
                'frequency': frequency
              });
              Navigator.pop(ctx);
              _fetchAllData();
            }, 
            child: const Text("Salva", style: TextStyle(color: Colors.white))
          )
        ],
      ),
    );
  }

  // --- BUILD UI ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(title: const Text("ASSETTO FINANZIARIO"), backgroundColor: Colors.transparent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. PATRIMONIO BASE
            _sectionTitle("Liquidità & Fondi", Icons.account_balance),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _editableTile("Stipendio Netto", "€ ${_profile!['monthly_income']}", (val) => _updateProfileField('monthly_income', val)),
                  _divider(),
                  _editableTile("Risparmi Attuali", "€ ${_profile!['current_savings']}", (val) => _updateProfileField('current_savings', val)),
                  _divider(),
                  _editableTile("Fondo Pensione", "€ ${_profile!['pension_fund']}", (val) => _updateProfileField('pension_fund', val)),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 2. INVESTIMENTI DETTAGLIATI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle("Portafoglio Investimenti", Icons.pie_chart),
                IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF00E676)), onPressed: _showAddInvestment)
              ],
            ),
            if (_investments.isEmpty) 
              const Text("Nessun investimento registrato.", style: TextStyle(color: Colors.grey)),
            ..._investments.map((inv) => _investmentTile(inv)).toList(),

            const SizedBox(height: 30),

            // 3. SPESE FISSE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle("Spese Fisse & Abbonamenti", Icons.credit_card),
                IconButton(icon: const Icon(Icons.add_circle, color: Colors.redAccent), onPressed: _showAddExpense)
              ],
            ),
            if (_expenses.isEmpty) 
              const Text("Nessuna spesa fissa.", style: TextStyle(color: Colors.grey)),
            ..._expenses.map((exp) => _expenseTile(exp)).toList(),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER ---

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [Icon(icon, color: Colors.grey, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))]),
    );
  }

  Widget _editableTile(String title, String value, Function(String) onSave) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white70)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          const Icon(Icons.edit, size: 16, color: Colors.white30)
        ],
      ),
      onTap: () {
        final ctrl = TextEditingController();
        showDialog(context: context, builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: TextField(controller: ctrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
          actions: [
            ElevatedButton(onPressed: () { onSave(ctrl.text); Navigator.pop(ctx); }, child: const Text("Salva"))
          ],
        ));
      },
    );
  }

  Future<void> _updateProfileField(String field, String value) async {
    final val = double.tryParse(value) ?? 0.0;
    await _updateField('profiles', field, val);
  }

  Widget _investmentTile(Map<String, dynamic> item) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.trending_up, color: Color(0xFF00E676)),
        title: Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(item['category'], style: const TextStyle(color: Colors.grey)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("€ ${item['amount']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.delete, color: Colors.white30, size: 20), onPressed: () => _deleteItem('investments', item['id'])),
          ],
        ),
      ),
    );
  }

  Widget _expenseTile(Map<String, dynamic> item) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: Colors.redAccent),
        title: Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(item['frequency'], style: const TextStyle(color: Colors.grey)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("€ ${item['amount']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.delete, color: Colors.white30, size: 20), onPressed: () => _deleteItem('fixed_expenses', item['id'])),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(color: Colors.white10, height: 1);
}