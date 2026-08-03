/// Arquitectura de detectores de reps por cámara, uno por ejercicio.
///
/// Hoy solo existe lógica de conteo real para la sentadilla básica (vía
/// SquatCounter, ya calibrado para una sentadilla simétrica de dos
/// piernas). El resto de los ejercicios —incluidas otras variantes de
/// sentadilla como búlgara/sumo/silla, que SquatCounter no está
/// calibrado para reconocer— cuentan manual. Para agregar un detector
/// nuevo más adelante, solo hay que:
/// 1. Implementar DetectorEjercicio para ese ejercicio.
/// 2. Registrarlo en detectoresPorEjercicio con el nombre exacto tal
///    como está en la columna ejercicios.nombre.
library;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../squat_counter.dart';

/// Contrato común para un contador de reps basado en cámara.
abstract class DetectorEjercicio {
  int get reps;
  void procesarPose(Pose pose);
  void reset();

  /// Texto corto de diagnóstico para el panel de depuración (o null si
  /// este detector no expone nada). No afecta el conteo.
  String? get debugInfo;

  /// Ángulo de profundidad alcanzado en cada rep ya completada (en el
  /// mismo orden), para guardar el detalle en session_reps. Vacío si
  /// este detector no mide profundidad.
  List<double> get profundidadesPorRep;
}

class _DetectorSentadilla implements DetectorEjercicio {
  final _contador = SquatCounter();

  @override
  int get reps => _contador.reps;

  @override
  void procesarPose(Pose pose) => _contador.processPose(pose);

  @override
  void reset() => _contador.reset();

  @override
  String? get debugInfo {
    final der = _contador.debugRightKneeAngle?.toStringAsFixed(0) ?? '--';
    final izq = _contador.debugLeftKneeAngle?.toStringAsFixed(0) ?? '--';
    final cadera = _contador.debugHipDropRatio != null
        ? '${(_contador.debugHipDropRatio! * 100).toStringAsFixed(0)}%'
        : '--';
    final estado = _contador.debugFailureReason ?? 'OK';
    return 'Rodilla der: $der°  Rodilla izq: $izq°\nCadera bajó: $cadera\n$estado';
  }

  @override
  List<double> get profundidadesPorRep => _contador.profundidadesPorRep;
}

/// nombre de ejercicio (tal como está en ejercicios.nombre) -> fábrica
/// de su detector por cámara.
final Map<String, DetectorEjercicio Function()> detectoresPorEjercicio = {
  'Sentadilla básica': () => _DetectorSentadilla(),
};

/// Devuelve un detector nuevo para [nombreEjercicio], o null si ese
/// ejercicio todavía no tiene detector automático (conteo manual).
DetectorEjercicio? crearDetectorPara(String nombreEjercicio) {
  return detectoresPorEjercicio[nombreEjercicio]?.call();
}
