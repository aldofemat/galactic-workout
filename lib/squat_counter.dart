import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Cuenta repeticiones de sentadilla midiendo el ángulo
/// cadera-rodilla-tobillo de ambas piernas en tiempo real.
///
/// Lógica:
/// - Ángulo grande (~170°) = pierna extendida = posición "arriba"
/// - Ángulo pequeño (<100°) = pierna flexionada = posición "abajo"
/// - Una repetición se cuenta al pasar de "abajo" a "arriba" de nuevo
///
/// Anti-falsos-positivos: para entrar a "abajo" (y por lo tanto poder
/// contar la rep) se requiere que AMBAS rodillas estén flexionadas a la
/// vez Y que la cadera haya bajado verticalmente respecto a su posición
/// de pie. Esto evita contar una rep cuando solo se levanta una rodilla.
class SquatCounter {
  int reps = 0;
  String stage = 'arriba'; // 'arriba' | 'abajo'
  double? lastAngle;

  /// Ángulo más profundo (mínimo) alcanzado en cada rep ya completada,
  /// en el mismo orden en que se completaron. Se usa para guardar el
  /// detalle por repetición en session_reps.profundidad_grados.
  List<double> profundidadesPorRep = [];
  double? _minAnguloEnBajadaActual;

  // Umbrales de ángulo, ajustables según lo que veas en pruebas reales.
  static const double downThreshold = 100;
  static const double upThreshold = 160;

  // Qué tanto debe bajar la cadera (como fracción del largo del torso
  // hombro-cadera, para que funcione sin importar la distancia a la
  // cámara) para considerar que hubo una sentadilla real.
  static const double hipDropRatioThreshold = 0.15;

  static const double _minConfidence = 0.6;

  // Baseline de altura (y de imagen) de la cadera de pie. Se captura
  // promediando ~1s mientras ambas rodillas están extendidas (> upThreshold)
  // y luego se congela: NO se recalcula frame a frame, porque hacerlo
  // hacía que el baseline siempre quedara igual al frame actual y la
  // "bajada de cadera" diera 0% siempre.
  double? _standingHipY;
  DateTime? _standingCaptureStart;
  double _standingHipYSum = 0;
  int _standingHipYSamples = 0;
  static const Duration _standingCaptureWindow = Duration(seconds: 1);

  // --- Diagnóstico en vivo (no afecta la lógica de conteo, solo se
  // exponen para poder mostrarlos en pantalla y depurar). ---
  double? debugLeftKneeAngle;
  double? debugRightKneeAngle;
  double? debugLeftLegConfidence;
  double? debugRightLegConfidence;
  double? debugHipDropRatio; // cuánto bajó la cadera, como fracción del torso
  double debugHipDropRequired = hipDropRatioThreshold;
  String? debugFailureReason; // null = no hay bloqueo activo

  /// Calcula el ángulo en grados entre tres puntos (b es el vértice).
  double _angleBetween(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final radians = atan2(c.y - b.y, c.x - b.x) - atan2(a.y - b.y, a.x - b.x);
    var angle = (radians * 180.0 / pi).abs();
    if (angle > 180) angle = 360 - angle;
    return angle;
  }

  bool _confident(PoseLandmark? landmark) =>
      landmark != null && landmark.likelihood >= _minConfidence;

  /// Menor likelihood entre los landmarks dados (0 si alguno falta).
  double _minLikelihood(List<PoseLandmark?> landmarks) {
    double worst = 1.0;
    for (final l in landmarks) {
      final likelihood = l?.likelihood ?? 0.0;
      if (likelihood < worst) worst = likelihood;
    }
    return worst;
  }

  /// Nombre del landmark con menor confianza de una pierna, para mensajes
  /// de diagnóstico como "rodilla izquierda".
  String _worstLandmarkLabel(
    bool isLeft,
    PoseLandmark? hip,
    PoseLandmark? knee,
    PoseLandmark? ankle,
  ) {
    final fem = isLeft ? 'izquierda' : 'derecha';
    final masc = isLeft ? 'izquierdo' : 'derecho';
    final candidates = <MapEntry<String, double>>[
      MapEntry('cadera $fem', hip?.likelihood ?? 0.0),
      MapEntry('rodilla $fem', knee?.likelihood ?? 0.0),
      MapEntry('tobillo $masc', ankle?.likelihood ?? 0.0),
    ];
    candidates.sort((a, b) => a.value.compareTo(b.value));
    return candidates.first.key;
  }

  /// Procesa una pose detectada y actualiza el conteo si corresponde.
  /// Devuelve el ángulo promedio de rodilla (izquierda+derecha) actual,
  /// o null si no hay landmarks suficientes y confiables en ambas piernas.
  double? processPose(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    // --- Diagnóstico: se calcula siempre que existan los landmarks,
    // aunque su confianza sea baja, para poder ver qué está pasando. ---
    debugLeftLegConfidence = _minLikelihood([leftHip, leftKnee, leftAnkle]);
    debugRightLegConfidence = _minLikelihood([rightHip, rightKnee, rightAnkle]);
    debugLeftKneeAngle =
        (leftHip != null && leftKnee != null && leftAnkle != null)
            ? _angleBetween(leftHip, leftKnee, leftAnkle)
            : null;
    debugRightKneeAngle =
        (rightHip != null && rightKnee != null && rightAnkle != null)
            ? _angleBetween(rightHip, rightKnee, rightAnkle)
            : null;

    final hasLeftLeg =
        _confident(leftHip) && _confident(leftKnee) && _confident(leftAnkle);
    final hasRightLeg =
        _confident(rightHip) && _confident(rightKnee) && _confident(rightAnkle);

    // Requerimos ambas piernas visibles y confiables: es justo lo que
    // permite detectar "solo se flexionó una rodilla" como falso positivo.
    if (!hasLeftLeg || !hasRightLeg) {
      debugHipDropRatio = null;
      if (!hasLeftLeg && !hasRightLeg) {
        debugFailureReason = 'FALLA: ambas piernas con baja confianza';
      } else if (!hasLeftLeg) {
        final worst = _worstLandmarkLabel(true, leftHip, leftKnee, leftAnkle);
        debugFailureReason = 'FALLA: $worst baja confianza';
      } else {
        final worst =
            _worstLandmarkLabel(false, rightHip, rightKnee, rightAnkle);
        debugFailureReason = 'FALLA: $worst baja confianza';
      }
      return null;
    }

    final leftAngle = debugLeftKneeAngle!;
    final rightAngle = debugRightKneeAngle!;
    final avgAngle = (leftAngle + rightAngle) / 2;
    lastAngle = avgAngle;

    final bothKneesDown =
        leftAngle < downThreshold && rightAngle < downThreshold;
    final bothKneesUp = leftAngle > upThreshold && rightAngle > upThreshold;

    final hipY = (leftHip!.y + rightHip!.y) / 2;

    // Largo de torso (hombro-cadera) para normalizar cuánto debe bajar
    // la cadera, sin importar qué tan cerca/lejos esté la cámara.
    double? torsoLength;
    if (_confident(leftShoulder) && _confident(rightShoulder)) {
      final shoulderY = (leftShoulder!.y + rightShoulder!.y) / 2;
      torsoLength = (hipY - shoulderY).abs();
    }

    // Captura del baseline de pie: promedia la altura de cadera durante
    // ~1s mientras ambas rodillas están extendidas, y luego lo congela.
    // Solo se recaptura (reemplaza) la próxima vez que vuelva a estar de
    // pie de forma estable; mientras tanto el baseline se mantiene fijo,
    // incluso durante toda la bajada y subida de la sentadilla.
    if (bothKneesUp) {
      final now = DateTime.now();
      _standingCaptureStart ??= now;
      _standingHipYSum += hipY;
      _standingHipYSamples++;
      if (now.difference(_standingCaptureStart!) >= _standingCaptureWindow) {
        _standingHipY = _standingHipYSum / _standingHipYSamples;
        _standingCaptureStart = null;
        _standingHipYSum = 0;
        _standingHipYSamples = 0;
      }
    } else {
      // Ya no está de pie: descarta cualquier captura en progreso. El
      // baseline ya congelado (si existe) se conserva sin tocar.
      _standingCaptureStart = null;
      _standingHipYSum = 0;
      _standingHipYSamples = 0;
    }

    double? hipDropRatio;
    if (_standingHipY != null && torsoLength != null && torsoLength > 0) {
      hipDropRatio = (hipY - _standingHipY!) / torsoLength;
    }
    debugHipDropRatio = hipDropRatio;

    final hipDroppedEnough =
        hipDropRatio != null && hipDropRatio > hipDropRatioThreshold;

    // Mensaje de diagnóstico: qué condición específica está bloqueando
    // el conteo en este frame (solo informativo, no cambia la lógica).
    if (stage == 'abajo') {
      debugFailureReason = bothKneesUp
          ? null
          : 'Esperando extender ambas rodillas para contar la rep';
    } else if (!bothKneesDown) {
      debugFailureReason = 'FALLA: rodillas no flexionadas lo suficiente '
          '(izq=${leftAngle.toStringAsFixed(0)}°, der=${rightAngle.toStringAsFixed(0)}°, '
          'se requiere <${downThreshold.toStringAsFixed(0)}°)';
    } else if (torsoLength == null) {
      debugFailureReason = 'FALLA: hombros no visibles/confiables '
          '(no se puede medir la bajada de cadera)';
    } else if (!hipDroppedEnough) {
      final dropPct = ((hipDropRatio ?? 0) * 100).toStringAsFixed(0);
      final reqPct = (hipDropRatioThreshold * 100).toStringAsFixed(0);
      debugFailureReason = 'FALLA: cadera no baja lo suficiente '
          '($dropPct% de $reqPct% requerido)';
    } else {
      debugFailureReason = null;
    }

    if (bothKneesDown && hipDroppedEnough) {
      stage = 'abajo';
    } else if (bothKneesUp && stage == 'abajo') {
      stage = 'arriba';
      reps++;
      profundidadesPorRep.add(_minAnguloEnBajadaActual ?? avgAngle);
      _minAnguloEnBajadaActual = null;
    }

    // Registra el ángulo más profundo mientras dure la fase "abajo" de
    // esta rep (se guarda al completarla, arriba).
    if (stage == 'abajo') {
      final actual = _minAnguloEnBajadaActual;
      _minAnguloEnBajadaActual =
          actual == null ? avgAngle : (avgAngle < actual ? avgAngle : actual);
    }

    return avgAngle;
  }

  void reset() {
    reps = 0;
    stage = 'arriba';
    lastAngle = null;
    profundidadesPorRep = [];
    _minAnguloEnBajadaActual = null;
    _standingHipY = null;
    _standingCaptureStart = null;
    _standingHipYSum = 0;
    _standingHipYSamples = 0;
    debugLeftKneeAngle = null;
    debugRightKneeAngle = null;
    debugLeftLegConfidence = null;
    debugRightLegConfidence = null;
    debugHipDropRatio = null;
    debugFailureReason = null;
  }
}
