/// Modelos de datos del motor de rutinas: representan filas de
/// ejercicios y nivel_config tal como las devuelve Supabase, y el
/// resultado de asignarle un ejercicio a un lugar concreto de una
/// sesión (bloque, orden y dosis).
library;

/// Fila de la tabla `ejercicios`.
class Ejercicio {
  const Ejercicio({
    required this.id,
    required this.nombre,
    required this.nivelMinimo,
    required this.bloques,
    required this.patron,
    required this.modalidad,
    required this.equipo,
    required this.posicion,
    required this.prohibidoLesion,
    this.unilateral = false,
  });

  final String id;
  final String nombre;
  final int nivelMinimo;

  /// Bloques a los que pertenece este ejercicio (p. ej. {activación,
  /// core}). Un ejercicio puede servir para más de un bloque.
  final List<String> bloques;

  /// empuje / jalón / piernas / core / cardio / movilidad.
  final String patron;

  /// tiempo / reps / ambas.
  final String modalidad;

  /// Slug de equipo requerido, o 'peso_corporal' si ninguno.
  final String equipo;

  /// de pie / colgado / apoyo / piso.
  final String posicion;

  /// Zonas de lesión (vocabulario del catálogo, no el del onboarding —
  /// ver zonas_lesion.dart) que excluyen este ejercicio si el usuario
  /// las tiene marcadas.
  final List<String> prohibidoLesion;

  /// Se hace un lado del cuerpo a la vez (plancha lateral, pistol,
  /// desplantes, etc.): al asignarse a una sesión genera DOS pasos
  /// consecutivos (izquierdo y derecho) en vez de uno solo.
  final bool unilateral;

  factory Ejercicio.fromMap(Map<String, dynamic> map) {
    return Ejercicio(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      nivelMinimo: map['nivel_minimo'] as int,
      bloques: List<String>.from(map['bloques'] as List? ?? const []),
      patron: map['patron'] as String,
      modalidad: map['modalidad'] as String,
      equipo: map['equipo'] as String,
      posicion: map['posicion'] as String,
      prohibidoLesion: List<String>.from(
        map['prohibido_lesion'] as List? ?? const [],
      ),
      unilateral: map['unilateral'] as bool? ?? false,
    );
  }
}

/// Fila de la tabla `nivel_config`: parámetros de trabajo/descanso/
/// rondas/duración para un nivel (0-4).
class NivelConfig {
  const NivelConfig({
    required this.nivel,
    required this.trabajoSeg,
    required this.trabajoReps,
    required this.descansoSeg,
    required this.rondas,
    required this.duracionMin,
  });

  final int nivel;
  final int trabajoSeg;
  final int trabajoReps;
  final int descansoSeg;
  final int rondas;
  final int duracionMin;

  factory NivelConfig.fromMap(Map<String, dynamic> map) {
    return NivelConfig(
      nivel: map['nivel'] as int,
      trabajoSeg: map['trabajo_seg'] as int,
      trabajoReps: map['trabajo_reps'] as int,
      descansoSeg: map['descanso_seg'] as int,
      rondas: map['rondas'] as int,
      duracionMin: map['duracion_min'] as int,
    );
  }
}

/// Un ejercicio ya asignado a un lugar concreto de la sesión de un día:
/// su bloque en ESA sesión, su posición (orden) y su dosis.
class EjercicioAsignado {
  const EjercicioAsignado({
    required this.ejercicio,
    required this.orden,
    required this.bloque,
    required this.dosisTipo,
    required this.dosisValor,
    this.lado,
  });

  final Ejercicio ejercicio;
  final int orden;
  final String bloque;
  final String dosisTipo; // 'tiempo' | 'reps'
  final int dosisValor;

  /// 'izquierdo' | 'derecho' | null. No-null solo cuando
  /// ejercicio.unilateral generó este paso como parte de un par.
  final String? lado;
}
