/// Paso 2B del motor de rutinas: mapear profiles.dias_entrena_semana a
/// un número de días de plan (3-6) y armar la distribución de tipos de
/// día (Fuerza / Cardio / Movilidad) de la semana.
library;

/// Tipo de día dentro de una semana de rutina. El texto (`valor`) es el
/// que se guarda en rutina_dias.tipo_dia.
enum TipoDia {
  fuerza('fuerza'),
  cardio('cardio'),
  movilidad('movilidad');

  const TipoDia(this.valor);

  final String valor;
}

/// dias_entrena_semana (0-7) -> días de plan (3-6).
/// 0-3 => 3 ; 4 => 4 ; 5 => 5 ; 6-7 => 6.
int diasPlanDesdeFrecuencia(int diasEntrenaSemana) {
  if (diasEntrenaSemana <= 3) return 3;
  if (diasEntrenaSemana == 4) return 4;
  if (diasEntrenaSemana == 5) return 5;
  return 6; // 6 o 7
}

/// Distribución fija de tipos de día según cuántos días tenga el plan.
const Map<int, List<TipoDia>> _distribucionPorDiasPlan = {
  3: [TipoDia.fuerza, TipoDia.cardio, TipoDia.movilidad],
  4: [TipoDia.fuerza, TipoDia.cardio, TipoDia.fuerza, TipoDia.movilidad],
  5: [
    TipoDia.fuerza,
    TipoDia.cardio,
    TipoDia.fuerza,
    TipoDia.cardio,
    TipoDia.movilidad,
  ],
  6: [
    TipoDia.fuerza,
    TipoDia.cardio,
    TipoDia.fuerza,
    TipoDia.movilidad,
    TipoDia.fuerza,
    TipoDia.cardio,
  ],
};

/// Devuelve la lista ordenada de tipos de día (índice 0 = día 1, etc.)
/// para un plan de [diasPlan] días (debe ser 3, 4, 5 o 6).
List<TipoDia> calendarioSemanal(int diasPlan) {
  final distribucion = _distribucionPorDiasPlan[diasPlan];
  if (distribucion == null) {
    throw ArgumentError.value(
      diasPlan,
      'diasPlan',
      'Debe ser 3, 4, 5 o 6 (dias_entrena_semana ya se mapea a uno de esos)',
    );
  }
  return distribucion;
}
