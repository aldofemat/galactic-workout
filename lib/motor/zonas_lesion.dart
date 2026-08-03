/// Traduce las zonas de lesión tal como las guarda el onboarding
/// (profiles.zonas_lesion: 'Rodillas', 'Espalda baja', 'Hombros',
/// 'Muñecas', 'Otra') al vocabulario que usa ejercicios.prohibido_lesion
/// en el catálogo real ('rodilla'/'rodillas', 'espalda', 'hombro',
/// 'muñecas', 'piernas', 'tobillo', 'pantorrillas', 'pies').
///
/// Hace falta este mapeo porque ambos lados se cargaron con
/// vocabularios distintos (ver la nota al respecto en
/// supabase/schema_fase4.sql) — sin esto, comparar los strings tal
/// cual nunca haría match y el filtro de lesión no excluiría nada.
library;

/// zona de onboarding (en minúsculas) -> tokens equivalentes en el
/// catálogo de ejercicios. 'otra' no tiene mapeo: es texto libre
/// (lesion_otra_texto) y no se puede correlacionar automáticamente.
const Map<String, List<String>> _mapaZonasLesion = {
  'rodillas': ['rodilla', 'rodillas'],
  'espalda baja': ['espalda'],
  'hombros': ['hombro'],
  'muñecas': ['muñecas'],
};

/// Convierte las zonas de lesión del perfil (formato onboarding) al
/// conjunto de tokens del catálogo que deben excluir ejercicios.
Set<String> zonasLesionCatalogo(Iterable<String> zonasOnboarding) {
  final resultado = <String>{};
  for (final zona in zonasOnboarding) {
    final tokens = _mapaZonasLesion[zona.trim().toLowerCase()];
    if (tokens != null) resultado.addAll(tokens);
  }
  return resultado;
}
