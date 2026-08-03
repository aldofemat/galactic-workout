import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_gate.dart';
import 'theme.dart';

// Lista global de cámaras disponibles en el dispositivo.
late List<CameraDescription> cameras;

// Credenciales de Supabase. La "publishable key" está pensada para vivir
// en el cliente (equivalente a la anon key clásica) — el acceso real a
// los datos lo controlan las políticas de RLS en la base de datos.
const _supabaseUrl = 'https://ldmqidsrrdvbnshtspda.supabase.co';
const _supabasePublishableKey =
    'sb_publishable_i42fm64JUkcOY2J2s_5mDg_qpN9zIam';

/// Acceso corto al cliente de Supabase desde cualquier parte de la app.
final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
  cameras = await availableCameras();
  runApp(const WorkoutApp());
}

class WorkoutApp extends StatelessWidget {
  const WorkoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout App - Fase 1',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}
