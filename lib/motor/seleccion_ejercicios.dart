/// Paso 2C del motor de rutinas: dado un catálogo de ejercicios y el
/// perfil/nivel del usuario, arma la sesión de un día completa —
/// filtrado, cuántos ejercicios por bloque, cuáles ejercicios elegir,
/// en qué orden, y con qué dosis.
library;

import 'dart:math';

import 'calendario_semanal.dart';
import 'modelos.dart';
import 'package:flutter/foundation.dart';

/// Orden fijo de bloques dentro de TODA sesión, sin excepción.
const ordenBloques = ['activación', 'fuerza', 'core', 'habilidad', 'cierre'];

/// Orden de posición para minimizar transiciones dentro de un bloque:
/// de pie -> colgado -> apoyo -> piso.
const _ordenPosicion = ['de pie', 'colgado', 'apoyo', 'piso'];

// Rango de cantidad de ejercicios permitido por bloque (Activación 1-2,
// Fuerza 2-4, Core 2-4, Cierre 1-2). Habilidad no tiene rango: siempre
// es 1 (2 en día Movilidad), fijado aparte en distribuirBloques.
const _minActivacion = 1, _maxActivacion = 2;
const _minFuerza = 2, _maxFuerza = 4;
const _minCore = 2, _maxCore = 4;
const _minCierre = 1, _maxCierre = 2;

/// Total de ejercicios mínimo/máximo que puede tener una sesión, sumando
/// los rangos de todos los bloques (Habilidad cuenta 1 aquí; el caso de
/// 2 en día Movilidad se maneja aparte).
const totalMinSesion =
    _minActivacion + _minFuerza + _minCore + 1 + _minCierre; // 7
const totalMaxSesion =
    _maxActivacion + _maxFuerza + _maxCore + 1 + _maxCierre; // 13

/// ---------------------------------------------------------------
/// 1) FILTRADO: qué ejercicios puede usar este usuario en general.
/// ---------------------------------------------------------------
///
/// Reglas obligatorias:
/// - nivel_minimo <= nivel del usuario (puede usar su nivel o menores).
/// - equipo: 'peso_corporal', o el slug está en el equipo del usuario.
/// - lesión: si alguna zona de prohibido_lesion está en las zonas de
///   lesión del usuario (ya traducidas al vocabulario del catálogo, ver
///   zonas_lesion.dart), se excluye.
List<Ejercicio> filtrarElegibles(
  List<Ejercicio> catalogo, {
  required int nivelUsuario,
  required Set<String> equipoUsuario,
  required Set<String> zonasLesionCatalogo,
}) {
  return catalogo.where((e) {
    if (e.nivelMinimo > nivelUsuario) return false;

    final equipoOk =
        e.equipo == 'peso_corporal' || equipoUsuario.contains(e.equipo);
    if (!equipoOk) return false;

    final conflictoLesion = e.prohibidoLesion.any(zonasLesionCatalogo.contains);
    if (conflictoLesion) return false;

    return true;
  }).toList();
}

/// ---------------------------------------------------------------
/// 2) TAMAÑO DE LA SESIÓN: cuántos ejercicios en total.
/// ---------------------------------------------------------------
///
/// Aproxima el total para que rondas * numEjercicios * (trabajo +
/// descanso) se acerque a duracion_min; se acota al rango que permiten
/// los bloques (7-13). No tiene que ser exacto.
int numeroEjerciciosSesion(NivelConfig cfg) {
  final resultado =
      cfg.ejerciciosPorRonda.round().clamp(totalMinSesion, totalMaxSesion);
  debugPrint(
      '📊 numeroEjerciciosSesion: ejerciciosPorRonda=${cfg.ejerciciosPorRonda}, resultado=$resultado (min=$totalMinSesion, max=$totalMaxSesion)');
  return resultado;
}

/// ---------------------------------------------------------------
/// 3) DISTRIBUCIÓN POR BLOQUE: cuántos ejercicios de cada bloque.
/// ---------------------------------------------------------------
///
/// Core siempre apunta a ~30% del total (es "la firma", igual en los
/// tres tipos de día). Habilidad es 1 (2 en Movilidad). Cierre es 2
/// solo si duracion_min >= 30 (si no, 1 — "estiramientos solo si
/// duracion_min >= 30"). Lo que queda se reparte entre Activación y
/// Fuerza según el tipo de día:
/// - Día Fuerza: la mayoría va a Fuerza (~55% del total original).
/// - Día Cardio/Movilidad: la mayoría va a Activación, porque en el
///   catálogo real los ejercicios patrón=cardio/movilidad casi siempre
///   están etiquetados con bloque=activación, no bloque=fuerza — ahí
///   es donde vive ese ~45%/50% de "contenido cardio/movilidad".
Map<String, int> distribuirBloques(int n, TipoDia tipoDia, NivelConfig cfg) {
  final habilidad = tipoDia == TipoDia.movilidad ? 2 : 1;
  const cierre = _maxCierre;

  final core = (n * 0.30).round().clamp(_minCore, _maxCore);

  var resto = n - habilidad - cierre - core;
  const minRestoFuerzaActivacion = _minFuerza + _minActivacion;
  if (resto < minRestoFuerzaActivacion) resto = minRestoFuerzaActivacion;

  final fraccionFuerza = switch (tipoDia) {
    TipoDia.fuerza => 0.8,
    TipoDia.cardio => 0.35,
    TipoDia.movilidad => 0.35,
  };

  final fuerza = (resto * fraccionFuerza).round().clamp(_minFuerza, _maxFuerza);
  final activacion = (resto - fuerza).clamp(_minActivacion, _maxActivacion);

  return {
    'activación': activacion,
    'fuerza': fuerza,
    'core': core,
    'habilidad': habilidad,
    'cierre': cierre,
  };
}

/// ---------------------------------------------------------------
/// 4) ELECCIÓN DE EJERCICIOS para un bloque concreto.
/// ---------------------------------------------------------------
///
/// - Bloque 'fuerza': rota entre los patrones empuje/jalón/piernas.
/// - Bloque 'activación' en día Cardio: prefiere patrón=cardio.
/// - Bloque 'activación' en día Movilidad: prefiere patrón=movilidad.
/// - Evita repetir un ejercicio ya usado esta semana en el mismo tipo
///   de día si hay opciones frescas; si el catálogo elegible no
///   alcanza, se permite repetir (mejor repetir que dejar la sesión
///   incompleta).
/// - Nunca repite el mismo ejercicio dos veces dentro de la misma
///   sesión (eso ya lo evita quien llama, pasando un [pool] sin los
///   ids ya usados en bloques anteriores de esta sesión).
/// - Un ejercicio unilateral ocupa 2 "cupos" de [cantidad] (se convierte
///   en 2 pasos izquierdo/derecho más adelante en ordenarSesion), así
///   que se cuentan cupos, no ejercicios, al decidir cuándo parar.
List<Ejercicio> elegirParaBloque({
  required List<Ejercicio> pool,
  required String bloque,
  required int cantidad,
  required TipoDia tipoDia,
  required Set<String> usadosMismoTipoDia,
  required Random random,
}) {
  if (cantidad <= 0) return const [];

  final candidatos = pool.where((e) => e.bloques.contains(bloque)).toList();
  if (candidatos.isEmpty) return const [];

  List<String>? ordenPatrones;
  if (bloque == 'fuerza') {
    ordenPatrones = const ['empuje', 'jalón', 'piernas'];
  } else if (bloque == 'activación') {
    if (tipoDia == TipoDia.cardio) {
      ordenPatrones = const ['cardio', 'movilidad'];
    } else if (tipoDia == TipoDia.movilidad) {
      ordenPatrones = const ['movilidad', 'cardio'];
    }
  }

  // Fuerza/Core/Habilidad deben preferir el ejercicio de nivel_minimo
  // más alto que el usuario todavía pueda hacer (el más cercano a su
  // nivel real), no el más bajo — si no, un usuario Intermedio nunca
  // recibe ejercicios Intermedios porque el pool se llena de opciones
  // de nivel 0/1. Activación y Cierre se quedan como estaban: ahí
  // cualquier nivel bajo es apropiado para todos.
  final priorizarNivelAlto =
      bloque == 'fuerza' || bloque == 'core' || bloque == 'habilidad';

  // Se baraja primero para no elegir siempre los mismos ejercicios del
  // catálogo, y dentro de cada patrón se ordena por nivel_minimo
  // descendente (si aplica) — esto NO decide todavía qué patrón "gana":
  // eso lo resuelve la rotación de turnos de abajo, no un orden lineal
  // (ordenar y tomar los primeros N se llevaba puro "empuje" siempre).
  candidatos.shuffle(random);
  if (priorizarNivelAlto) {
    candidatos.sort((a, b) => b.nivelMinimo.compareTo(a.nivelMinimo));
  }

  final frescoIds = candidatos
      .where((e) => !usadosMismoTipoDia.contains(e.id))
      .map((e) => e.id)
      .toSet();

  final List<Ejercicio> elegidos;

  if (ordenPatrones != null) {
    // Rotación por turnos: una vuelta por empuje/jalón/piernas (o
    // cardio/movilidad), tomando un ejercicio de cada patrón por vuelta,
    // hasta llenar cantidad. Dentro de cada patrón, los frescos van
    // antes que los ya usados esta semana (que solo se permiten si no
    // alcanzan los frescos). Un patrón sin candidatos se salta sin
    // romper el turno de los demás.
    final colasPorPatron = <String, List<Ejercicio>>{
      for (final patron in ordenPatrones)
        patron: [
          ...candidatos.where(
            (e) => e.patron == patron && frescoIds.contains(e.id),
          ),
          ...candidatos.where(
            (e) => e.patron == patron && !frescoIds.contains(e.id),
          ),
        ],
    };

    final tomados = <Ejercicio>[];
    final idsElegidos = <String>{};
    var cupos = 0;
    var progreso = true;
    while (cupos < cantidad && progreso) {
      progreso = false;
      for (final patron in ordenPatrones) {
        if (cupos >= cantidad) break;
        final cola = colasPorPatron[patron]!;
        final indice = cola.indexWhere((e) => !idsElegidos.contains(e.id));
        if (indice == -1) continue;
        final candidato = cola[indice];
        final costo = candidato.unilateral ? 2 : 1;
        // Un unilateral que ya no cabe entero se salta (mejor terminar
        // 1 cupo corto que pasarse): la sesión nunca crece por su
        // culpa. Excepción: si el bloque sigue vacío, se toma de
        // todos modos para no dejarlo sin nada.
        if (cupos + costo > cantidad && cupos > 0) continue;
        tomados.add(candidato);
        idsElegidos.add(candidato.id);
        cupos += costo;
        progreso = true;
      }
    }
    elegidos = tomados;
  } else {
    // Sin patrones que rotar (core/habilidad/cierre): toma en orden,
    // prefiriendo frescos, sin repetir dentro de la misma sesión.
    final frescos = candidatos.where((e) => frescoIds.contains(e.id)).toList();
    final tomados = <Ejercicio>[];
    final idsElegidos = <String>{};
    var cupos = 0;

    void tomarDe(List<Ejercicio> lista) {
      for (final e in lista) {
        if (cupos >= cantidad) break;
        if (idsElegidos.contains(e.id)) continue;
        final costo = e.unilateral ? 2 : 1;
        if (cupos + costo > cantidad && cupos > 0) continue;
        tomados.add(e);
        idsElegidos.add(e.id);
        cupos += costo;
      }
    }

    tomarDe(frescos);
    if (cupos < cantidad) {
      tomarDe(candidatos); // fase 2: se permite repetir de la semana
    }
    elegidos = tomados;
  }

  return elegidos;
}

/// ---------------------------------------------------------------
/// 5) DOSIS de un ejercicio según su modalidad y el nivel.
/// ---------------------------------------------------------------
///
/// tiempo -> trabajo_seg; reps -> trabajo_reps; ambas -> trabajo_reps
/// (se prefieren reps porque la cámara cuenta repeticiones).
// ✅ Así ya está bien (pero hazlo explícito):
({String tipo, int valor}) calcularDosis(Ejercicio ejercicio, NivelConfig cfg) {
  if (ejercicio.modalidad == 'tiempo') {
    return (tipo: 'tiempo', valor: cfg.trabajoSeg);
  } else if (ejercicio.modalidad == 'reps') {
    return (tipo: 'reps', valor: cfg.trabajoReps);
  }
  // Fallback (no debería llegar aquí)
  return (tipo: 'reps', valor: cfg.trabajoReps);
}

/// ---------------------------------------------------------------
/// 6) ORDEN dentro de la sesión: bloque primero, luego posición.
/// ---------------------------------------------------------------
///
/// activación siempre abre y cierre siempre cierra (son el primer y
/// último bloque en ordenBloques); dentro de cada bloque, se agrupan
/// por posición (de pie -> colgado -> apoyo -> piso) para minimizar
/// transiciones. Un ejercicio unilateral genera 2 pasos consecutivos
/// (izquierdo y luego derecho, mismo bloque y dosis), nunca separados
/// por otro ejercicio.
List<EjercicioAsignado> ordenarSesion(
  Map<String, List<Ejercicio>> porBloque,
  NivelConfig cfg,
) {
  final resultado = <EjercicioAsignado>[];
  var orden = 1;

  for (final bloque in ordenBloques) {
    final lista = List<Ejercicio>.from(porBloque[bloque] ?? const []);
    lista.sort((a, b) {
      final pa = _ordenPosicion.indexOf(a.posicion);
      final pb = _ordenPosicion.indexOf(b.posicion);
      return (pa == -1 ? _ordenPosicion.length : pa).compareTo(
        pb == -1 ? _ordenPosicion.length : pb,
      );
    });

    for (final ejercicio in lista) {
      final dosis = calcularDosis(ejercicio, cfg);
      final lados = ejercicio.unilateral
          ? const <String?>['izquierdo', 'derecho']
          : const <String?>[null];
      for (final lado in lados) {
        resultado.add(
          EjercicioAsignado(
            ejercicio: ejercicio,
            orden: orden++,
            bloque: bloque,
            dosisTipo: dosis.tipo,
            dosisValor: dosis.valor,
            lado: lado,
          ),
        );
      }
    }
  }

  return resultado;
}

/// ---------------------------------------------------------------
/// Orquesta 2-6 para armar la sesión completa de UN día.
/// ---------------------------------------------------------------
List<EjercicioAsignado> generarSesionDia({
  required List<Ejercicio> catalogoElegible,
  required TipoDia tipoDia,
  required NivelConfig cfg,
  required Set<String> usadosMismoTipoDia,
  required Random random,
}) {
  final n = numeroEjerciciosSesion(cfg);
  final cantidadesPorBloque = distribuirBloques(n, tipoDia, cfg);

  final porBloque = <String, List<Ejercicio>>{};
  final idsUsadosEnEstaSesion = <String>{};

  for (final bloque in ordenBloques) {
    final cantidad = cantidadesPorBloque[bloque] ?? 0;
    final poolDisponible = catalogoElegible
        .where((e) => !idsUsadosEnEstaSesion.contains(e.id))
        .toList();

    final elegidos = elegirParaBloque(
      pool: poolDisponible,
      bloque: bloque,
      cantidad: cantidad,
      tipoDia: tipoDia,
      usadosMismoTipoDia: usadosMismoTipoDia,
      random: random,
    );

    porBloque[bloque] = elegidos;
    idsUsadosEnEstaSesion.addAll(elegidos.map((e) => e.id));
  }

  return ordenarSesion(porBloque, cfg);
}
