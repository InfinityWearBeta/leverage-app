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

  // Lista delle pagine
  final List<Widget> _screens = [
    const DashboardScreen(), 
    const StatsScreen(),     
    const AcademyScreen(),   
    const ProfileScreen(),   
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // MODIFICA QUI: Usiamo direttamente la schermata corrente.
      // Questo costringe Flutter a ricaricare i dati (initState) ogni volta che cambi tab.
      body: _screens[_currentIndex],
      
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
          backgroundColor: const Color(0xFF1E1E1E), 
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