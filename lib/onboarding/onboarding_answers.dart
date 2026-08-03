/// Respuestas acumuladas durante el cuestionario de onboarding. Se
/// mutan directamente pantalla a pantalla y se guardan todas juntas
/// en profiles al terminar.
class OnboardingAnswers {
  String? genero;
  int? edad;
  double? pesoKg;
  double? estaturaCm;

  int? diasEntrenaSemana;

  bool? tieneLesion;
  Set<String> zonasLesion = {};
  String? lesionOtraTexto;

  Set<String> equipo = {};

  bool? sentadillasPuede;
  int? sentadillasReps;

  bool? lagartijasPuede;
  int? lagartijasReps;

  bool? dominadasPuede;
  int? dominadasReps;

  bool? corre;
  String? correTiempo;

  bool? paradaManos;
  String? paradaManosTiempo;

  /// P9 solo se pregunta a quien ya muestra un nivel avanzado en las
  /// tres pruebas base.
  bool get calificaParaP9 =>
      (dominadasReps ?? 0) >= 20 &&
      (lagartijasReps ?? 0) >= 30 &&
      (sentadillasReps ?? 0) >= 30;

  Map<String, dynamic> toProfileMap(String userId) {
    return {
      'id': userId,
      'genero': genero,
      'edad': edad,
      'peso_kg': pesoKg,
      'estatura_cm': estaturaCm,
      'dias_entrena_semana': diasEntrenaSemana,
      'tiene_lesion': tieneLesion,
      'zonas_lesion': zonasLesion.toList(),
      'lesion_otra_texto': lesionOtraTexto,
      'equipo': equipo.toList(),
      'sentadillas_puede': sentadillasPuede,
      'sentadillas_reps': sentadillasReps,
      'lagartijas_puede': lagartijasPuede,
      'lagartijas_reps': lagartijasReps,
      'dominadas_puede': dominadasPuede,
      'dominadas_reps': dominadasReps,
      'corre': corre,
      'corre_tiempo': correTiempo,
      'parada_manos': paradaManos,
      'parada_manos_tiempo': paradaManosTiempo,
      'onboarding_completado': true,
    };
  }
}
