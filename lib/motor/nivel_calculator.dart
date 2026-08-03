/// Paso 2A del motor de rutinas: calcular el nivel general (0-4) del
/// usuario a partir de su perfil.
///
/// Regla del "eslabón más débil": se calcula un nivel individual para
/// sentadillas, lagartijas y dominadas, y el nivel final del usuario es
/// el MÍNIMO de los tres. El cardio no participa en este cálculo.
library;

/// Resultado del cálculo, con el detalle por ejercicio base para poder
/// depurar por qué salió cierto nivel (por ejemplo, en pantalla o logs).
class NivelResultado {
  const NivelResultado({
    required this.nivel,
    required this.nivelSentadillas,
    required this.nivelLagartijas,
    required this.nivelDominadas,
    required this.cumpleRequisitosElite,
  });

  /// Nivel final del usuario (0-4): el mínimo de sentadillas/lagartijas/
  /// dominadas, salvo que ese mínimo sea 4 y no se cumplan los requisitos
  /// extra de Élite — en ese caso queda topado en 3.
  final int nivel;
  final int nivelSentadillas;
  final int nivelLagartijas;
  final int nivelDominadas;

  /// null si el mínimo de los tres ejercicios de fuerza no llegó a 4
  /// (el requisito de Élite ni siquiera aplica). true/false si sí aplicó.
  final bool? cumpleRequisitosElite;

  @override
  String toString() =>
      'NivelResultado(nivel: $nivel, sentadillas: $nivelSentadillas, '
      'lagartijas: $nivelLagartijas, dominadas: $nivelDominadas, '
      'cumpleRequisitosElite: $cumpleRequisitosElite)';
}

/// Tabla de reps -> nivel para sentadillas y lagartijas (misma tabla
/// para ambas): 0 reps o "no puede" => 0; 1-9 => 1; 10-19 => 2;
/// 20-29 => 3; 30+ => 4.
int _nivelPorRepsBasico(bool? puede, int? reps) {
  final r = (puede == true) ? (reps ?? 0) : 0;
  if (r <= 0) return 0;
  if (r <= 9) return 1;
  if (r <= 19) return 2;
  if (r <= 29) return 3;
  return 4;
}

/// Dominadas usa una tabla distinta: 0 dominadas NO es "cero absoluto",
/// es "principiante" (nivel 1) — salvo que sentadillas Y lagartijas
/// sean ambas 0/no puede, en cuyo caso dominadas tampoco puede sacar al
/// usuario de nivel 0 por sí sola.
int _nivelDominadas(
  bool? puede,
  int? reps, {
  required bool sentadillasYLagartijasEnCero,
}) {
  final r = (puede == true) ? (reps ?? 0) : 0;

  final int nivelBase;
  if (r <= 0) {
    nivelBase = 1; // 0 dominadas = principiante, no cero absoluto.
  } else if (r <= 3) {
    nivelBase = 1;
  } else if (r <= 9) {
    nivelBase = 2;
  } else if (r <= 19) {
    nivelBase = 3;
  } else {
    nivelBase = 4;
  }

  // Excepción: si no puede ni sentadillas ni lagartijas, no tiene caso
  // que dominadas lo saque de "cero absoluto" con un simple nivel 1.
  if (sentadillasYLagartijasEnCero && nivelBase == 1) {
    return 0;
  }
  return nivelBase;
}

/// Nivel 4 (Élite) exige, además del mínimo de fuerza en 4, aguantar
/// trotando más de 40 min Y pararse de manos más de 1 min (cualquier
/// tiempo salvo 'menos_1min'). Faltando cualquiera de las dos, el
/// usuario se queda en Avanzado (nivel 3).
bool _cumpleRequisitosElite({
  required String? correTiempo,
  required bool? paradaManos,
  required String? paradaManosTiempo,
}) {
  final correOk = correTiempo == 'mas_40';
  final paradaOk = paradaManos == true &&
      paradaManosTiempo != null &&
      paradaManosTiempo != 'menos_1min';
  return correOk && paradaOk;
}

/// Calcula el nivel (0-4) a partir de los campos de habilidad del
/// perfil. Es una función pura: no toca Supabase ni guarda nada — el
/// guardado del nivel resultante ocurre al generar la semana (Paso 2C,
/// columna rutinas_semana.nivel_usuario), para no tener que recalcularlo
/// cada vez que el motor necesita saber el nivel del usuario.
NivelResultado calcularNivel({
  required bool? sentadillasPuede,
  required int? sentadillasReps,
  required bool? lagartijasPuede,
  required int? lagartijasReps,
  required bool? dominadasPuede,
  required int? dominadasReps,
  required String? correTiempo,
  required bool? paradaManos,
  required String? paradaManosTiempo,
}) {
  final nivelSentadillas =
      _nivelPorRepsBasico(sentadillasPuede, sentadillasReps);
  final nivelLagartijas = _nivelPorRepsBasico(lagartijasPuede, lagartijasReps);

  final sentadillasYLagartijasEnCero =
      nivelSentadillas == 0 && nivelLagartijas == 0;
  final nivelDominadas = _nivelDominadas(
    dominadasPuede,
    dominadasReps,
    sentadillasYLagartijasEnCero: sentadillasYLagartijasEnCero,
  );

  final niveles = [nivelSentadillas, nivelLagartijas, nivelDominadas];
  final nivelBase = niveles.reduce((a, b) => a < b ? a : b);

  // El requisito extra de Élite solo aplica (y solo puede bajar el
  // nivel) cuando el mínimo de fuerza ya llegó a 4.
  final esEliteBase = nivelBase == 4;
  final cumpleElite = esEliteBase
      ? _cumpleRequisitosElite(
          correTiempo: correTiempo,
          paradaManos: paradaManos,
          paradaManosTiempo: paradaManosTiempo,
        )
      : null;

  final nivel = (esEliteBase && cumpleElite == false) ? 3 : nivelBase;

  return NivelResultado(
    nivel: nivel,
    nivelSentadillas: nivelSentadillas,
    nivelLagartijas: nivelLagartijas,
    nivelDominadas: nivelDominadas,
    cumpleRequisitosElite: cumpleElite,
  );
}

/// Conveniencia: calcula el nivel directamente desde una fila de
/// profiles tal como la devuelve Supabase (Map<String, dynamic>).
NivelResultado calcularNivelDesdePerfil(Map<String, dynamic> perfil) {
  return calcularNivel(
    sentadillasPuede: perfil['sentadillas_puede'] as bool?,
    sentadillasReps: perfil['sentadillas_reps'] as int?,
    lagartijasPuede: perfil['lagartijas_puede'] as bool?,
    lagartijasReps: perfil['lagartijas_reps'] as int?,
    dominadasPuede: perfil['dominadas_puede'] as bool?,
    dominadasReps: perfil['dominadas_reps'] as int?,
    correTiempo: perfil['corre_tiempo'] as String?,
    paradaManos: perfil['parada_manos'] as bool?,
    paradaManosTiempo: perfil['parada_manos_tiempo'] as String?,
  );
}
