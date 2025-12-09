import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

// 1. WIDGET COCKPIT (Aggiornato: Cash vs SDS)
class SolvencyCockpit extends StatelessWidget {
  final double sds;            // Safe Daily Spend
  final double liquidCash;     // Cash Reale (Saldo)
  final String status;
  final int sdc;               // Calorie
  final int daysToPayday;
  final double pendingBills;
  final VoidCallback onInfoTap; // Callback per il popup info

  const SolvencyCockpit({
    super.key, 
    required this.sds, 
    required this.liquidCash,
    required this.status, 
    required this.sdc, 
    required this.daysToPayday, 
    required this.pendingBills,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = const Color(0xFF00E676);
    if (status == "CRITICO") statusColor = Colors.orange;
    if (status == "INSOLVENTE") statusColor = Colors.redAccent;

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
          // Header: Titolo + Info + Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("SOLVIBILITÀ", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onInfoTap,
                    child: const Icon(Icons.info_outline, color: Colors.white30, size: 16),
                  )
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 15),
          
          // BODY: Due Colonne (Budget vs Cash)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Colonna SX: SDS (Budget Giornaliero)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("€ ${sds.toStringAsFixed(2)}", style: TextStyle(color: statusColor, fontSize: 32, fontWeight: FontWeight.w900)),
                  const Text("Budget / Giorno", style: TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
              // Separatore Verticale
              Container(width: 1, height: 40, color: Colors.white10),
              // Colonna DX: Cash Reale
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("€ ${liquidCash.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text("Cash Reale", style: TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              )
            ],
          ),
          
          const SizedBox(height: 15),
          ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: 1.0, backgroundColor: Colors.white10, color: statusColor, minHeight: 4)),
          const SizedBox(height: 10),
          
          // Footer: Calorie e Bollette
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                 const Icon(Icons.bolt, color: Colors.blueAccent, size: 14),
                 const SizedBox(width: 4),
                 Text("$sdc Kcal", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
              Text("Bollette Future: -€${pendingBills.toStringAsFixed(0)}", style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
            ],
          )
        ],
      ),
    );
  }
}

// 2. WIDGET CALENDARIO (Invariato)
class CalendarWidget extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final Function(DateTime, DateTime) onDaySelected;
  final List<dynamic> Function(DateTime) eventLoader;

  const CalendarWidget({
    super.key, required this.focusedDay, required this.selectedDay, required this.onDaySelected, required this.eventLoader
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20)),
      child: TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1), lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: focusedDay, selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        calendarFormat: CalendarFormat.week, availableCalendarFormats: const {CalendarFormat.week: 'Settimana'},
        onDaySelected: onDaySelected,
        eventLoader: eventLoader,
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
}

// 3. CARD LOG (Invariato)
class LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final Function(String) onDelete;

  const LogCard({super.key, required this.log, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.circle; Color color = Colors.grey; String title = "Attività"; String subtitle = "";
    
    if (log['log_type'] == 'vice_consumed') {
      icon = Icons.warning_amber_rounded; color = Colors.orangeAccent; title = "${log['sub_type'] ?? 'Vizio'}"; subtitle = "Consumato";
    } else if (log['log_type'] == 'expense') {
      icon = Icons.money_off; color = Colors.redAccent; title = "${log['category'] ?? 'Spesa'}"; subtitle = "- €${log['amount_saved']}";
    } else if (log['log_type'] == 'workout') {
      icon = Icons.fitness_center; color = Colors.blueAccent; title = "${log['sub_type'] ?? 'Sport'}"; subtitle = "Allenamento";
    }

    return Card(
      color: Colors.white.withOpacity(0.05),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.white30), onPressed: () => onDelete(log['id'])),
      ),
    );
  }
}