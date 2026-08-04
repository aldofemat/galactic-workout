/// Pantalla de cierre (Parte 3C): guarda la sesión en Supabase y
/// muestra las 4 métricas mientras ese guardado corre en segundo plano.
library;

import 'package:flutter/material.dart';
import '../../theme.dart';
import '../modelos_ejecucion.dart';

class PantallaCierre extends StatelessWidget {
  const PantallaCierre({
    super.key,
    required this.metricas,
    required this.error,
    required this.onReintentar,
    required this.onListo,
  });

  final MetricasCierre? metricas;
  final String? error;
  final VoidCallback onReintentar;
  final VoidCallback onListo;

  String _formatDuracion(Duration d) {
    final minutos = d.inMinutes;
    final segundos = d.inSeconds % 60;
    return minutos > 0 ? '$minutos min $segundos s' : '$segundos s';
  }

  @override
  Widget build(BuildContext context) {
    final err = error;
    if (err != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  err,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onReintentar,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final m = metricas;
    if (m == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.brandBright),
              SizedBox(height: 20),
              Text(
                'Guardando tu sesión...',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Rutina completada',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuracion(m.duracion),
                  style: const TextStyle(color: Colors.white70, fontSize: 20),
                ),
                const SizedBox(height: 28),
                Text(
                  m.porcentajeValidas != null
                      ? '${m.repsTotales} reps totales · ${m.porcentajeValidas}% válidas'
                      : '${m.repsTotales} reps totales',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  m.comparacion,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.brandBright,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '🔥 ${m.racha} ${m.racha == 1 ? 'día seguido' : 'días seguidos'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: onListo,
                    child: const Text('Listo'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
