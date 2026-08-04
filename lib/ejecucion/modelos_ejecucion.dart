/// Modelos usados por el flujo de ejecución de una rutina: el
/// ejercicio ya resuelto para la sesión, las fases del ciclo, y las
/// métricas calculadas para la pantalla de cierre.
library;

/// Un ejercicio ya resuelto para la sesión de hoy: lo mínimo que la
/// pantalla de ejecución necesita saber de él.
class EjercicioSesion {
  const EjercicioSesion({
    required this.ejercicioId,
    required this.nombre,
    required this.mediaUrl,
    required this.dosisTipo,
    required this.dosisValor,
  });

  /// id real en el catálogo `ejercicios`, para poder guardar
  /// session_ejercicio_tiempos con una referencia de verdad (no el
  /// nombre como texto suelto).
  final String ejercicioId;
  final String nombre;
  final String? mediaUrl;
  final String dosisTipo; // 'tiempo' | 'reps'
  final int dosisValor;
}

enum Fase { cuentaInicial, ejecucion, descanso, cierre }

/// Métricas ya calculadas para mostrar en la pantalla de cierre.
class MetricasCierre {
  const MetricasCierre({
    required this.duracion,
    required this.repsTotales,
    required this.porcentajeValidas,
    required this.comparacion,
    required this.racha,
  });

  final Duration duracion;
  final int repsTotales;
  final int? porcentajeValidas;
  final String comparacion;
  final int racha;
}
