/// Orquestador del motor de rutinas: junta nivel_calculator (2A),
/// calendario_semanal (2B) y seleccion_ejercicios (2C), y guarda el
/// resultado en Supabase (rutinas_semana, rutina_dias,
/// rutina_dia_ejercicios).
library;

import 'dart:math';
import '../main.dart';
import 'calendario_semanal.dart';
import 'modelos.dart';
import 'nivel_calculator.dart';
import 'seleccion_ejercicios.dart';
import 'zonas_lesion.dart';
import '../constants.dart'; // ← Importa la constante

double calcularDuracionSesion(
  List<EjercicioAsignado> sesion,
  NivelConfig cfg,
) {
  // Contar por tipo
  int ejerciciosTiempo = 0;
  int ejerciciosReps = 0;

  for (final asignado in sesion) {
    if (asignado.ejercicio.modalidad == 'tiempo') {
      ejerciciosTiempo++;
    } else if (asignado.ejercicio.modalidad == 'reps') {
      // ← Explícito
      ejerciciosReps++;
    }
  }

  // Convertir a segundos
  final tiempoTrabajoTiempo = ejerciciosTiempo * cfg.trabajoSeg;
  final tiempoTrabajoReps = (ejerciciosReps *
      cfg.trabajoReps *
      WorkoutConstants.segundosPorRep); // ← Usa constante
  final tiempoDescansoTotal =
      (ejerciciosTiempo + ejerciciosReps) * cfg.descansoSeg;

  final totalSegundos =
      tiempoTrabajoTiempo + tiempoTrabajoReps + tiempoDescansoTotal;
  return totalSegundos / 60;
}

/// Genera la semana de rutinas del usuario [userId] a partir de su
/// perfil y la guarda en Supabase. Desactiva cualquier semana anterior
/// que tuviera activa=true. Devuelve el id de la nueva rutinas_semana.
Future<String> generarRutinaSemanal(String userId) async {
  final perfil =
      await supabase.from('profiles').select().eq('id', userId).single();

  // --- 2A: nivel ---
  final nivelResultado = calcularNivelDesdePerfil(perfil);
  final nivel = nivelResultado.nivel;

  // --- 2B: calendario ---
  final diasEntrenaSemana = perfil['dias_entrena_semana'] as int? ?? 3;
  final diasPlan = diasPlanDesdeFrecuencia(diasEntrenaSemana);
  final calendario = calendarioSemanal(diasPlan);

  // --- Datos para 2C ---
  final cfgMap =
      await supabase.from('nivel_config').select().eq('nivel', nivel).single();
  final cfg = NivelConfig.fromMap(cfgMap);

  final catalogoMaps =
      await supabase.from('ejercicios').select().eq('activo', true);
  final catalogo = (catalogoMaps as List)
      .map((m) => Ejercicio.fromMap(m as Map<String, dynamic>))
      .toList();

  final equipoUsuario = Set<String>.from(
    (perfil['equipo'] as List? ?? const []).map((e) => e.toString()),
  );
  final zonasOnboarding = (perfil['zonas_lesion'] as List? ?? const []).map(
    (e) => e.toString(),
  );
  final zonasCatalogo = zonasLesionCatalogo(zonasOnboarding);

  final catalogoElegible = filtrarElegibles(
    catalogo,
    nivelUsuario: nivel,
    equipoUsuario: equipoUsuario,
    zonasLesionCatalogo: zonasCatalogo,
  );

  // --- 2C: una sesión por día, evitando repetir dentro del mismo
  // tipo de día a lo largo de la semana ---
  final random = Random();
  final usadosPorTipoDia = {for (final t in TipoDia.values) t: <String>{}};

  final sesiones = <List<EjercicioAsignado>>[];
  for (final tipoDia in calendario) {
    final sesion = generarSesionDia(
      catalogoElegible: catalogoElegible,
      tipoDia: tipoDia,
      cfg: cfg,
      usadosMismoTipoDia: usadosPorTipoDia[tipoDia]!,
      random: random,
    );
    sesiones.add(sesion);
    usadosPorTipoDia[tipoDia]!.addAll(sesion.map((a) => a.ejercicio.id));
  }

  // --- Guardado ---
  await supabase
      .from('rutinas_semana')
      .update({'activa': false})
      .eq('user_id', userId)
      .eq('activa', true);

  final semanaInsertada = await supabase
      .from('rutinas_semana')
      .insert({
        'user_id': userId,
        'nivel_usuario': nivel,
        'dias_plan': diasPlan,
        'activa': true,
      })
      .select()
      .single();
  final semanaId = semanaInsertada['id'] as String;

  for (var i = 0; i < calendario.length; i++) {
    final tipoDia = calendario[i];
    final duracion =
        calcularDuracionSesion(sesiones[i], cfg); // ← AGREGA ESTA LÍNEA

    final diaInsertado = await supabase
        .from('rutina_dias')
        .insert({
          'semana_id': semanaId,
          'dia_numero': i + 1,
          'tipo_dia': tipoDia.valor,
          'duracion_calculada_min': duracion, // ← AGREGA ESTE CAMPO
        })
        .select()
        .single();
    final diaId = diaInsertado['id'] as String;

    final filas = sesiones[i]
        .map(
          (asignado) => {
            'dia_id': diaId,
            'orden': asignado.orden,
            'ejercicio_id': asignado.ejercicio.id,
            'bloque': asignado.bloque,
            'dosis_tipo': asignado.dosisTipo,
            'dosis_valor': asignado.dosisValor,
            'lado': asignado.lado,
          },
        )
        .toList();

    if (filas.isNotEmpty) {
      await supabase.from('rutina_dia_ejercicios').insert(filas);
    }
  }

  return semanaId;
}
