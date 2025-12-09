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

  // Rimuoviamo la lista statica _screens.
  // La costruiremo dinamicamente nel build.

  @override
  Widget build(BuildContext context) {
    // Logica per forzare il refresh della Dashboard
    final screens = [
      // Usiamo UniqueKey() solo se siamo sulla tab 0 per forzare il ricaricamento
      // Oppure, più semplicemente, lasciamo che DashboardScreen gestisca il fetch nel didUpdateWidget
      // Ma per l'MVP, ricreare il widget è la via più sicura per avere dati freschi.
      const DashboardScreen(key: ValueKey('dashboard')), 
      const StatsScreen(),     
      const AcademyScreen(),   
      const ProfileScreen(),   
    ];

    return Scaffold(
      // Usiamo un IndexedStack per mantenere lo stato SE volessimo preservarlo,
      // ma noi VOGLIAMO il refresh quando torniamo sulla Home da Profilo.
      // Quindi usare body: screens[_currentIndex] va bene, MA:
      
      // FIX PROPOSTO:
      // Se vieni dalla tab Profilo (index 3) alla Home (index 0), 
      // i dati finanziari potrebbero essere cambiati.
      body: screens[_currentIndex],
      
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: Theme.of(context).primaryColor.withOpacity(0.2),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              // Se clicco sulla Home ed ero già sulla Home, forzo un refresh?
              // Per ora cambio solo pagina.
              _currentIndex = index;
            });
          },
          backgroundColor: const Color(0xFF1E1E1E), 
          height: 65,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Cockpit', // Rinominato per coerenza
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