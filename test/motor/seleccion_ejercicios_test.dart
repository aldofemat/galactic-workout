import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/motor/calendario_semanal.dart';
import 'package:workout_app/motor/modelos.dart';
import 'package:workout_app/motor/seleccion_ejercicios.dart';

Ejercicio _e(
  String id, {
  int nivelMinimo = 0,
  List<String> bloques = const ['fuerza'],
  String patron = 'empuje',
  String modalidad = 'reps',
  String equipo = 'peso_corporal',
  String posicion = 'de pie',
  List<String> prohibidoLesion = const [],
  bool unilateral = false,
}) {
  return Ejercicio(
    id: id,
    nombre: 'Ejercicio $id',
    nivelMinimo: nivelMinimo,
    bloques: bloques,
    patron: patron,
    modalidad: modalidad,
    equipo: equipo,
    posicion: posicion,
    prohibidoLesion: prohibidoLesion,
    unilateral: unilateral,
  );
}

// nivel_config real de las 5 filas insertadas en Fase 4.
NivelConfig _cfg(int nivel) {
  const filas = {
    0: (
      trabajoSeg: 20,
      trabajoReps: 4,
      descansoSeg: 20,
      rondas: 1,
      duracionMin: 10
    ),
    1: (
      trabajoSeg: 30,
      trabajoReps: 6,
      descansoSeg: 30,
      rondas: 2,
      duracionMin: 20
    ),
    2: (
      trabajoSeg: 40,
      trabajoReps: 8,
      descansoSeg: 30,
      rondas: 2,
      duracionMin: 30
    ),
    3: (
      trabajoSeg: 45,
      trabajoReps: 20,
      descansoSeg: 30,
      rondas: 3,
      duracionMin: 45
    ),
    4: (
      trabajoSeg: 60,
      trabajoReps: 30,
      descansoSeg: 30,
      rondas: 3,
      duracionMin: 60
    ),
  };
  final f = filas[nivel]!;
  return NivelConfig(
    nivel: nivel,
    trabajoSeg: f.trabajoSeg,
    trabajoReps: f.trabajoReps,
    descansoSeg: f.descansoSeg,
    rondas: f.rondas,
    duracionMin: f.duracionMin,
  );
}

void main() {
  group('filtrarElegibles', () {
    final catalogo = [
      _e('nivel_alto', nivelMinimo: 3),
      _e('equipo_ajeno', equipo: 'anillas'),
      _e('equipo_propio', equipo: 'paralelas'),
      _e('con_lesion', prohibidoLesion: ['hombro']),
      _e('libre'),
    ];

    test('excluye ejercicios por encima del nivel del usuario', () {
      final r = filtrarElegibles(
        catalogo,
        nivelUsuario: 1,
        equipoUsuario: {'paralelas'},
        zonasLesionCatalogo: {},
      );
      expect(r.map((e) => e.id), isNot(contains('nivel_alto')));
    });

    test('excluye ejercicios con equipo que el usuario no tiene', () {
      final r = filtrarElegibles(
        catalogo,
        nivelUsuario: 4,
        equipoUsuario: {'paralelas'},
        zonasLesionCatalogo: {},
      );
      expect(r.map((e) => e.id), isNot(contains('equipo_ajeno')));
      expect(r.map((e) => e.id), contains('equipo_propio'));
    });

    test('excluye ejercicios que chocan con una zona de lesión', () {
      final r = filtrarElegibles(
        catalogo,
        nivelUsuario: 4,
        equipoUsuario: {'paralelas'},
        zonasLesionCatalogo: {'hombro'},
      );
      expect(r.map((e) => e.id), isNot(contains('con_lesion')));
      expect(r.map((e) => e.id), contains('libre'));
    });
  });

  group('numeroEjerciciosSesion', () {
    test('siempre cae dentro del rango 7-13 para los 5 niveles', () {
      for (var nivel = 0; nivel <= 4; nivel++) {
        final n = numeroEjerciciosSesion(_cfg(nivel));
        expect(n, inInclusiveRange(totalMinSesion, totalMaxSesion),
            reason: 'nivel $nivel');
      }
    });
  });

  group('distribuirBloques', () {
    test('respeta los rangos de cada bloque y usa habilidad=1', () {
      final d = distribuirBloques(10, TipoDia.fuerza, _cfg(2));
      expect(d['activación']!, inInclusiveRange(1, 2));
      expect(d['fuerza']!, inInclusiveRange(2, 4));
      expect(d['core']!, inInclusiveRange(2, 4));
      expect(d['habilidad'], 1);
      expect(d['cierre']!, inInclusiveRange(1, 2));
    });

    test('día Movilidad usa habilidad=2', () {
      final d = distribuirBloques(10, TipoDia.movilidad, _cfg(2));
      expect(d['habilidad'], 2);
    });

    test('cierre es 2 solo si duracion_min >= 30', () {
      final corto =
          distribuirBloques(8, TipoDia.fuerza, _cfg(0)); // duracion 10
      final largo =
          distribuirBloques(12, TipoDia.fuerza, _cfg(3)); // duracion 45
      expect(corto['cierre'], 1);
      expect(largo['cierre'], 2);
    });

    test('día Fuerza destina más a fuerza que día Cardio o Movilidad', () {
      final fuerza = distribuirBloques(10, TipoDia.fuerza, _cfg(2));
      final cardio = distribuirBloques(10, TipoDia.cardio, _cfg(2));
      final movilidad = distribuirBloques(10, TipoDia.movilidad, _cfg(2));
      expect(fuerza['fuerza']!, greaterThanOrEqualTo(cardio['fuerza']!));
      expect(fuerza['fuerza']!, greaterThanOrEqualTo(movilidad['fuerza']!));
    });
  });

  group('elegirParaBloque', () {
    test('respeta el bloque pedido y la cantidad', () {
      final pool = [
        _e('f1', bloques: ['fuerza'], patron: 'empuje'),
        _e('f2', bloques: ['fuerza'], patron: 'jalón'),
        _e('c1', bloques: ['core'], patron: 'core'),
      ];
      final elegidos = elegirParaBloque(
        pool: pool,
        bloque: 'fuerza',
        cantidad: 2,
        tipoDia: TipoDia.fuerza,
        usadosMismoTipoDia: {},
        random: Random(1),
      );
      expect(elegidos.length, 2);
      expect(elegidos.every((e) => e.bloques.contains('fuerza')), isTrue);
    });

    test(
        'evita repetir ejercicios ya usados esta semana si hay opciones frescas',
        () {
      final pool = [
        _e('f1', bloques: ['fuerza']),
        _e('f2', bloques: ['fuerza']),
        _e('f3', bloques: ['fuerza']),
      ];
      final elegidos = elegirParaBloque(
        pool: pool,
        bloque: 'fuerza',
        cantidad: 2,
        tipoDia: TipoDia.fuerza,
        usadosMismoTipoDia: {'f1'},
        random: Random(1),
      );
      expect(elegidos.map((e) => e.id), isNot(contains('f1')));
    });

    test('permite repetir si no hay suficientes ejercicios frescos', () {
      final pool = [
        _e('unico', bloques: ['fuerza'])
      ];
      final elegidos = elegirParaBloque(
        pool: pool,
        bloque: 'fuerza',
        cantidad: 1,
        tipoDia: TipoDia.fuerza,
        usadosMismoTipoDia: {'unico'},
        random: Random(1),
      );
      expect(elegidos.map((e) => e.id), contains('unico'));
    });

    test('bloque sin candidatos devuelve lista vacía sin tronar', () {
      final elegidos = elegirParaBloque(
        pool: [
          _e('c1', bloques: ['core'])
        ],
        bloque: 'fuerza',
        cantidad: 2,
        tipoDia: TipoDia.fuerza,
        usadosMismoTipoDia: {},
        random: Random(1),
      );
      expect(elegidos, isEmpty);
    });

    test(
      'bug reportado: usuario nivel 2 con barra TBX debe recibir la dominada '
      '(N2) en vez de llenarse con superman/mono/isométricos (N0-N1)',
      () {
        final pool = [
          _e(
            'superman',
            bloques: ['fuerza'],
            patron: 'jalón',
            nivelMinimo: 0,
          ),
          _e('el_mono', bloques: ['fuerza'], patron: 'jalón', nivelMinimo: 1),
          _e(
            'isometrico_dominada',
            bloques: ['fuerza'],
            patron: 'jalón',
            nivelMinimo: 1,
          ),
          _e(
            'dominada_abierta',
            bloques: ['fuerza'],
            patron: 'jalón',
            nivelMinimo: 2,
          ),
        ];

        // Probado con varias semillas para no depender de que el barajado
        // "por suerte" ya diera el resultado correcto.
        for (final semilla in [1, 2, 3, 4, 5]) {
          final elegidos = elegirParaBloque(
            pool: pool,
            bloque: 'fuerza',
            cantidad: 1,
            tipoDia: TipoDia.fuerza,
            usadosMismoTipoDia: {},
            random: Random(semilla),
          );
          expect(
            elegidos.single.id,
            'dominada_abierta',
            reason: 'semilla $semilla',
          );
        }
      },
    );

    test(
      'bug reportado: fuerza con 3-4 cupos debe rotar por turnos entre '
      'patrones, no ordenar y quedarse solo con empuje',
      () {
        final pool = [
          _e(
            'lagartija_cerrada',
            bloques: ['fuerza'],
            patron: 'empuje',
            nivelMinimo: 1,
          ),
          _e(
            'lagartija_pica',
            bloques: ['fuerza'],
            patron: 'empuje',
            nivelMinimo: 2,
          ),
          _e(
            'lagartija_abierta',
            bloques: ['fuerza'],
            patron: 'empuje',
            nivelMinimo: 1,
          ),
          _e(
            'fondos_trapecio',
            bloques: ['fuerza'],
            patron: 'empuje',
            nivelMinimo: 1,
          ),
          _e(
            'dominada_abierta',
            bloques: ['fuerza'],
            patron: 'jalón',
            nivelMinimo: 2,
          ),
          _e(
            'el_mono',
            bloques: ['fuerza'],
            patron: 'jalón',
            nivelMinimo: 1,
          ),
          _e(
            'sentadilla_basica',
            bloques: ['fuerza'],
            patron: 'piernas',
            nivelMinimo: 1,
          ),
          _e(
            'desplantes',
            bloques: ['fuerza'],
            patron: 'piernas',
            nivelMinimo: 1,
          ),
        ];

        for (final cantidad in [3, 4]) {
          for (final semilla in [1, 2, 3, 4, 5]) {
            final elegidos = elegirParaBloque(
              pool: pool,
              bloque: 'fuerza',
              cantidad: cantidad,
              tipoDia: TipoDia.fuerza,
              usadosMismoTipoDia: {},
              random: Random(semilla),
            );
            final patronesElegidos = elegidos.map((e) => e.patron).toSet();
            expect(
              patronesElegidos,
              containsAll(['empuje', 'jalón', 'piernas']),
              reason: 'cantidad=$cantidad semilla=$semilla, '
                  'elegidos=${elegidos.map((e) => e.id).toList()}',
            );
          }
        }
      },
    );

    test('en core también prioriza nivel_minimo más alto', () {
      final pool = [
        _e('core_n0', bloques: ['core'], nivelMinimo: 0),
        _e('core_n2', bloques: ['core'], nivelMinimo: 2),
        _e('core_n1', bloques: ['core'], nivelMinimo: 1),
      ];
      final elegidos = elegirParaBloque(
        pool: pool,
        bloque: 'core',
        cantidad: 1,
        tipoDia: TipoDia.fuerza,
        usadosMismoTipoDia: {},
        random: Random(7),
      );
      expect(elegidos.single.id, 'core_n2');
    });

    test('en habilidad también prioriza nivel_minimo más alto', () {
      final pool = [
        _e('skill_n1', bloques: ['habilidad'], nivelMinimo: 1),
        _e('skill_n3', bloques: ['habilidad'], nivelMinimo: 3),
      ];
      final elegidos = elegirParaBloque(
        pool: pool,
        bloque: 'habilidad',
        cantidad: 1,
        tipoDia: TipoDia.fuerza,
        usadosMismoTipoDia: {},
        random: Random(3),
      );
      expect(elegidos.single.id, 'skill_n3');
    });

    test(
      'activación NO prioriza nivel_minimo (queda como estaba: cualquier '
      'nivel bajo es apropiado ahí)',
      () {
        // Con esta semilla, "act_n0" queda primero tras el barajado; si
        // activación priorizara nivel alto (como fuerza/core/habilidad),
        // "act_n2" ganaría en su lugar.
        final pool = [
          _e('act_n0',
              bloques: ['activación'], patron: 'movilidad', nivelMinimo: 0),
          _e('act_n2',
              bloques: ['activación'], patron: 'movilidad', nivelMinimo: 2),
        ];
        final elegidos = elegirParaBloque(
          pool: pool,
          bloque: 'activación',
          cantidad: 1,
          tipoDia: TipoDia.fuerza,
          usadosMismoTipoDia: {},
          random: Random(1),
        );
        // Verificamos que el orden se conserva tal cual el barajado (sin
        // ordenar por nivel): tomamos el mismo pool+semilla y barajamos
        // aparte para comparar contra el primero resultante.
        final copiaBarajada = List.of(pool)..shuffle(Random(1));
        expect(elegidos.single.id, copiaBarajada.first.id);
      },
    );

    test(
      'un ejercicio unilateral ocupa 2 cupos: no agrega cupos extra al '
      'total del bloque, solo consume 2 de los que ya existían',
      () {
        final pool = [
          _e('empuje_unilateral',
              bloques: ['fuerza'], patron: 'empuje', unilateral: true),
          _e('jalon_normal', bloques: ['fuerza'], patron: 'jalón'),
          _e('piernas_normal', bloques: ['fuerza'], patron: 'piernas'),
        ];
        final elegidos = elegirParaBloque(
          pool: pool,
          bloque: 'fuerza',
          cantidad: 3,
          tipoDia: TipoDia.fuerza,
          usadosMismoTipoDia: {},
          random: Random(1),
        );
        // La rotación por turnos toma empuje_unilateral (2 cupos) y
        // luego jalon_normal (1 cupo): 3 cupos llenos con solo 2
        // ejercicios elegidos, sin llegar a piernas_normal.
        expect(
            elegidos.map((e) => e.id), ['empuje_unilateral', 'jalon_normal']);
      },
    );
  });

  group('calcularDosis', () {
    final cfg = _cfg(2); // trabajo_seg=40, trabajo_reps=8

    test('modalidad tiempo => usa trabajo_seg', () {
      final d = calcularDosis(_e('x', modalidad: 'tiempo'), cfg);
      expect(d.tipo, 'tiempo');
      expect(d.valor, 40);
    });

    test('modalidad reps => usa trabajo_reps', () {
      final d = calcularDosis(_e('x', modalidad: 'reps'), cfg);
      expect(d.tipo, 'reps');
      expect(d.valor, 8);
    });

    test('modalidad ambas => prefiere reps', () {
      final d = calcularDosis(_e('x', modalidad: 'ambas'), cfg);
      expect(d.tipo, 'reps');
      expect(d.valor, 8);
    });
  });

  group('ordenarSesion', () {
    test('respeta el orden de bloques y agrupa por posición dentro de cada uno',
        () {
      final porBloque = {
        'cierre': [_e('cierre1', posicion: 'piso')],
        'activación': [
          _e('act_piso', posicion: 'piso'),
          _e('act_pie', posicion: 'de pie'),
        ],
        'fuerza': [_e('fuerza1', posicion: 'apoyo')],
      };
      final sesion = ordenarSesion(porBloque, _cfg(2));

      expect(sesion.map((a) => a.bloque), [
        'activación',
        'activación',
        'fuerza',
        'cierre',
      ]);
      // Dentro de activación: de pie antes que piso.
      final activacion = sesion.where((a) => a.bloque == 'activación').toList();
      expect(activacion[0].ejercicio.id, 'act_pie');
      expect(activacion[1].ejercicio.id, 'act_piso');
      // orden es secuencial 1..N
      expect(sesion.map((a) => a.orden), [1, 2, 3, 4]);
    });

    test(
      'un ejercicio unilateral genera 2 pasos consecutivos izquierdo/'
      'derecho, con el mismo bloque y dosis, sin separarse por otro '
      'ejercicio',
      () {
        final porBloque = {
          'fuerza': [
            _e('normal_antes', posicion: 'de pie'),
            _e('lateral', posicion: 'apoyo', unilateral: true),
            _e('normal_despues', posicion: 'piso'),
          ],
        };
        final sesion = ordenarSesion(porBloque, _cfg(2));

        // 4 pasos totales: normal + (izq+der del unilateral) + normal.
        expect(sesion.length, 4);
        expect(sesion.map((a) => a.ejercicio.id),
            ['normal_antes', 'lateral', 'lateral', 'normal_despues']);
        expect(sesion.map((a) => a.lado), [null, 'izquierdo', 'derecho', null]);
        // Consecutivos: orden sigue siendo secuencial sin huecos.
        expect(sesion.map((a) => a.orden), [1, 2, 3, 4]);
        // Mismo bloque y dosis en ambos lados del par.
        final par = sesion.where((a) => a.ejercicio.id == 'lateral').toList();
        expect(par[0].bloque, par[1].bloque);
        expect(par[0].dosisTipo, par[1].dosisTipo);
        expect(par[0].dosisValor, par[1].dosisValor);
      },
    );
  });

  group('generarSesionDia (integración de 2-6)', () {
    test('produce una sesión no vacía con un catálogo variado', () {
      final catalogo = [
        _e('act1', bloques: ['activación'], patron: 'movilidad'),
        _e('act2', bloques: ['activación'], patron: 'cardio'),
        _e('f1', bloques: ['fuerza'], patron: 'empuje'),
        _e('f2', bloques: ['fuerza'], patron: 'jalón'),
        _e('f3', bloques: ['fuerza'], patron: 'piernas'),
        _e('c1', bloques: ['core'], patron: 'core'),
        _e('c2', bloques: ['core'], patron: 'core'),
        _e('c3', bloques: ['core'], patron: 'core'),
        _e('h1', bloques: ['habilidad'], patron: 'core'),
        _e('cierre1', bloques: ['cierre'], patron: 'movilidad'),
        _e('cierre2', bloques: ['cierre'], patron: 'movilidad'),
      ];

      final sesion = generarSesionDia(
        catalogoElegible: catalogo,
        tipoDia: TipoDia.fuerza,
        cfg: _cfg(2),
        usadosMismoTipoDia: {},
        random: Random(42),
      );

      expect(sesion, isNotEmpty);
      // No debe repetir ningún ejercicio dentro de la misma sesión.
      final ids = sesion.map((a) => a.ejercicio.id).toList();
      expect(ids.toSet().length, ids.length);
      // El primer bloque presente debe ser activación y el último cierre.
      final bloquesUsados = sesion.map((a) => a.bloque).toSet();
      if (bloquesUsados.contains('activación')) {
        expect(sesion.first.bloque, 'activación');
      }
      if (bloquesUsados.contains('cierre')) {
        expect(sesion.last.bloque, 'cierre');
      }
    });

    test(
      'día con un ejercicio unilateral en el catálogo: el par izq/der '
      'sale consecutivo y el total de pasos no crece por su culpa',
      () {
        final catalogoSinUnilateral = [
          _e('act1', bloques: ['activación'], patron: 'movilidad'),
          _e('act2', bloques: ['activación'], patron: 'cardio'),
          _e('f1', bloques: ['fuerza'], patron: 'empuje'),
          _e('f2', bloques: ['fuerza'], patron: 'jalón'),
          _e('f3', bloques: ['fuerza'], patron: 'piernas'),
          _e('f4', bloques: ['fuerza'], patron: 'piernas'),
          _e('c1', bloques: ['core'], patron: 'core'),
          _e('c2', bloques: ['core'], patron: 'core'),
          _e('c3', bloques: ['core'], patron: 'core'),
          _e('h1', bloques: ['habilidad'], patron: 'core'),
          _e('cierre1', bloques: ['cierre'], patron: 'movilidad'),
          _e('cierre2', bloques: ['cierre'], patron: 'movilidad'),
        ];
        // Mismo catálogo, pero el ejercicio de empuje ahora es
        // unilateral (p. ej. plancha lateral) en vez de bilateral.
        final catalogoConUnilateral = [
          ...catalogoSinUnilateral.where((e) => e.id != 'f1'),
          _e(
            'f1',
            bloques: ['fuerza'],
            patron: 'empuje',
            unilateral: true,
          ),
        ];

        final cfg = _cfg(2);
        final sesionSin = generarSesionDia(
          catalogoElegible: catalogoSinUnilateral,
          tipoDia: TipoDia.fuerza,
          cfg: cfg,
          usadosMismoTipoDia: {},
          random: Random(42),
        );
        final sesionCon = generarSesionDia(
          catalogoElegible: catalogoConUnilateral,
          tipoDia: TipoDia.fuerza,
          cfg: cfg,
          usadosMismoTipoDia: {},
          random: Random(42),
        );

        // Mismo total de pasos con o sin unilateral: el par ocupa los
        // 2 cupos que antes ocupaba un solo ejercicio bilateral, no
        // agrega pasos extra a la sesión.
        expect(sesionCon.length, sesionSin.length);

        final indiceF1 = sesionCon.indexWhere((a) => a.ejercicio.id == 'f1');
        expect(indiceF1, greaterThanOrEqualTo(0),
            reason: 'f1 debe seguir eligiéndose con esta semilla');
        // El par sale consecutivo: mismo bloque/dosis, lados
        // izquierdo luego derecho, ordenes consecutivos.
        final ladoIzq = sesionCon[indiceF1];
        final ladoDer = sesionCon[indiceF1 + 1];
        expect(ladoIzq.ejercicio.id, 'f1');
        expect(ladoDer.ejercicio.id, 'f1');
        expect(ladoIzq.lado, 'izquierdo');
        expect(ladoDer.lado, 'derecho');
        expect(ladoDer.orden, ladoIzq.orden + 1);
        expect(ladoDer.bloque, ladoIzq.bloque);
        expect(ladoDer.dosisTipo, ladoIzq.dosisTipo);
        expect(ladoDer.dosisValor, ladoIzq.dosisValor);

        // Muestra cómo queda el día completo, para revisión visual.
        // ignore: avoid_print
        print('--- Día generado (con f1 unilateral) ---');
        for (final paso in sesionCon) {
          final nombre = paso.lado == null
              ? paso.ejercicio.nombre
              : '${paso.ejercicio.nombre} (lado ${paso.lado})';
          // ignore: avoid_print
          print(
            '${paso.orden}. [${paso.bloque}] $nombre — '
            '${paso.dosisValor} ${paso.dosisTipo}',
          );
        }
      },
    );
  });
}
