/// Parte 3D: qué le falta al usuario para subir de nivel, en lenguaje
/// directo. Usa las mismas tablas de reps->nivel que nivel_calculator.
library;

import 'nivel_calculator.dart';

const nombresNivel = {
  0: 'Cero absoluto',
  1: 'Principiante',
  2: 'Intermedio',
  3: 'Avanzado',
  4: 'Élite',
};

/// Reps mínimas para alcanzar el nivel [tier] en cada ejercicio (mismas
/// tablas que _nivelPorRepsBasico/_nivelDominadas en nivel_calculator).
int _minRepsParaTier(String ejercicio, int tier) {
  if (tier <= 0) return 0;
  if (ejercicio == 'dominadas') {
    const tabla = {1: 0, 2: 4, 3: 10, 4: 20};
    return tabla[tier] ?? 0;
  }
  const tabla = {1: 1, 2: 10, 3: 20, 4: 30};
  return tabla[tier] ?? 0;
}

/// Mensaje directo de qué le falta al usuario para el siguiente nivel.
/// Cubre el caso especial de "fuerza ya es Élite pero falta el gate
/// extra" (cardio + parada de manos) y el caso de ya ser Élite del todo.
String calcularMensajeFaltante({
  required NivelResultado nivel,
  required int sentadillasReps,
  required int lagartijasReps,
  required int dominadasReps,
  required String? correTiempo,
  required bool? paradaManos,
  required String? paradaManosTiempo,
}) {
  final nivelBaseFuerza = [
    nivel.nivelSentadillas,
    nivel.nivelLagartijas,
    nivel.nivelDominadas,
  ].reduce((a, b) => a < b ? a : b);

  // Ya cumple los 3 de fuerza (nivel base 4) pero el gate extra de
  // Élite lo topó en 3 (Avanzado).
  if (nivelBaseFuerza >= 4 && nivel.nivel < 4) {
    final faltantes = <String>[];
    if (correTiempo != 'mas_40') {
      faltantes.add('correr 40 min seguidos');
    }
    final paradaOk = paradaManos == true &&
        paradaManosTiempo != null &&
        paradaManosTiempo != 'menos_1min';
    if (!paradaOk) {
      faltantes.add('pararte de manos 1 minuto');
    }
    return 'Tu fuerza ya es de Élite. Te falta: ${faltantes.join(' y ')}. '
        'El cardio y el equilibrio también entrenan.';
  }

  if (nivel.nivel >= 4) {
    return '¡Ya eres Élite en los 5 requisitos! Nivel máximo alcanzado.';
  }

  final siguiente = nivel.nivel + 1;
  final faltantes = <String>[];

  void agregarSiFalta(String nombre, int nivelActual, int repsActuales) {
    if (nivelActual >= siguiente) return;
    final minimo = _minRepsParaTier(nombre, siguiente);
    final faltan = minimo - repsActuales;
    if (faltan > 0) faltantes.add('$faltan $nombre más');
  }

  agregarSiFalta('sentadillas', nivel.nivelSentadillas, sentadillasReps);
  agregarSiFalta('lagartijas', nivel.nivelLagartijas, lagartijasReps);
  agregarSiFalta('dominadas', nivel.nivelDominadas, dominadasReps);

  if (faltantes.isEmpty) {
    return 'Estás a nada de subir de nivel.';
  }

  return 'Para ${nombresNivel[siguiente]} te faltan: ${faltantes.join(', ')}';
}
