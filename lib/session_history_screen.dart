import 'package:flutter/material.dart';
import 'main.dart';

class WorkoutSession {
  WorkoutSession({
    required this.id,
    required this.ejercicio,
    required this.repsTotales,
    required this.fecha,
  });

  final String id;
  final String ejercicio;
  final int repsTotales;
  final DateTime fecha;

  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    return WorkoutSession(
      id: map['id'] as String,
      ejercicio: map['ejercicio'] as String,
      repsTotales: map['reps_totales'] as int,
      fecha: DateTime.parse(map['fecha'] as String).toLocal(),
    );
  }
}

/// Lista de entrenamientos guardados (workout_sessions) del usuario
/// autenticado, más reciente primero. RLS ya limita la consulta a las
/// filas del usuario actual, así que no hace falta filtrar por user_id
/// aquí.
class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  late Future<List<WorkoutSession>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _fetchSessions();
  }

  Future<List<WorkoutSession>> _fetchSessions() async {
    final data = await supabase
        .from('workout_sessions')
        .select()
        .order('fecha', ascending: false);
    return (data as List)
        .map((row) => WorkoutSession.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  String _formatFecha(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de entrenamientos')),
      body: FutureBuilder<List<WorkoutSession>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('No se pudo cargar el historial: ${snapshot.error}'),
            );
          }

          final sessions = snapshot.data ?? [];
          if (sessions.isEmpty) {
            return const Center(
              child: Text(
                'Aún no tienes entrenamientos',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text(session.ejercicio),
                subtitle: Text(_formatFecha(session.fecha)),
                trailing: Text(
                  '${session.repsTotales} reps',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
