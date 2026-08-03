import 'package:flutter/material.dart';
import 'camino_screen.dart';
import 'motor/rutina_debug_screen.dart';
import 'novedades_screen.dart';
import 'progreso_screen.dart';
import 'retos_screen.dart';
import 'theme.dart';

/// Pantalla principal tras login + onboarding: navegación inferior de
/// 4 pestañas (Entrenamiento / Novedades / Retos / Perfil), compacta y
/// solo con íconos. El ícono de debug (acceso a la pantalla de debug
/// del motor de rutinas, temporal, no se borra) flota sobre el
/// contenido en la esquina superior derecha en vez de ocupar una
/// franja fija. Sin título de AppBar en Entrenamiento/Novedades/Retos
/// — cada una ya trae su propio encabezado interno.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _tab == 3 ? AppBar(title: const Text('Perfil')) : null,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _tab,
              children: const [
                CaminoScreen(),
                NovedadesScreen(),
                RetosScreen(),
                ProgresoScreen(),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                iconSize: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.build_circle_outlined,
                  color: AppColors.brandBright,
                ),
                tooltip: 'Debug: motor de rutinas',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RutinaDebugScreen()),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Entrenamiento'),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            label: 'Novedades',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'Retos',
          ),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}
