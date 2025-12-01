import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'stats_screen.dart';
import 'academy_screen.dart';
import 'profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  // Lista delle pagine: L'ordine deve corrispondere alle icone in basso
  final List<Widget> _screens = [
    const DashboardScreen(), // Home (quella che hai già fatto)
    const StatsScreen(),     // Grafici
    const AcademyScreen(),   // Educazione
    const ProfileScreen(),   // Impostazioni
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Mostra la pagina selezionata
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      
      // IL MENU DI NAVIGAZIONE
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: Theme.of(context).primaryColor.withOpacity(0.2),
          labelTextStyle: MaterialStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          backgroundColor: const Color(0xFF1E1E1E), // Grigio Scuro
          height: 65,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.show_chart),
              selectedIcon: Icon(Icons.trending_up),
              label: 'Stats',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: 'Academy',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profilo',
            ),
          ],
        ),
      ),
    );
  }
}