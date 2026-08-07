/// Pantalla TEMPORAL de depuración para el motor de rutinas: dispara
/// generarRutinaSemanal() contra Supabase con el usuario real y muestra
/// un resumen de lo que generó (días, tipo de día, ejercicios con
/// bloque y dosis) para poder revisar si la rutina tiene sentido.
///
/// Esto no es UI final — es a propósito visible y feo, para que sea
/// fácil de encontrar y quitar cuando el motor esté validado.
library;

import 'package:flutter/material.dart';
import '../main.dart';
import 'generador_rutina.dart';

class _EjercicioDetalle {
  const _EjercicioDetalle({
    required this.orden,
    required this.nombre,
    required this.bloque,
    required this.dosisTipo,
    required this.dosisValor,
  });

  final int orden;
  final String nombre;
  final String bloque;
  final String dosisTipo;
  final int dosisValor;
}

class _RutinaDiaDetalle {
  const _RutinaDiaDetalle({
    required this.diaNumero,
    required this.tipoDia,
    required this.ejercicios,
    this.duracionCalculada,
  });

  final int diaNumero;
  final String tipoDia;
  final List<_EjercicioDetalle> ejercicios;
  final double? duracionCalculada;
}

const _etiquetaTipoDia = {
  'fuerza': 'FUERZA (F)',
  'cardio': 'CARDIO (C)',
  'movilidad': 'MOVILIDAD (M)',
};

/// Vuelve a leer de Supabase la semana ya guardada (rutina_dias +
/// rutina_dia_ejercicios, con el nombre del ejercicio embebido vía la
/// FK ejercicio_id -> ejercicios) para mostrarla en pantalla.
///
/// ✅ TAMBIÉN TRAE y VERIFICA la duración_calculada_min
Future<List<_RutinaDiaDetalle>> _obtenerDetalleSemana(String semanaId) async {
  final dias = await supabase
      .from('rutina_dias')
      .select()
      .eq('semana_id', semanaId)
      .order('dia_numero', ascending: true);

  final resultado = <_RutinaDiaDetalle>[];
  for (final diaMap in dias as List) {
    final diaId = diaMap['id'] as String;
    final duracionCalculada = diaMap['duracion_calculada_min'] as double?;

    final filas = await supabase
        .from('rutina_dia_ejercicios')
        .select(
          'orden, bloque, dosis_tipo, dosis_valor, lado, ejercicios(nombre)',
        )
        .eq('dia_id', diaId)
        .order('orden', ascending: true);

    final ejercicios = (filas as List).map((m) {
      final ejercicioEmbebido = m['ejercicios'] as Map<String, dynamic>;
      final lado = m['lado'] as String?;
      final nombre = ejercicioEmbebido['nombre'] as String;
      return _EjercicioDetalle(
        orden: m['orden'] as int,
        nombre: lado == null ? nombre : '$nombre (lado $lado)',
        bloque: m['bloque'] as String,
        dosisTipo: m['dosis_tipo'] as String,
        dosisValor: m['dosis_valor'] as int,
      );
    }).toList();

    resultado.add(
      _RutinaDiaDetalle(
        diaNumero: diaMap['dia_numero'] as int,
        tipoDia: diaMap['tipo_dia'] as String,
        ejercicios: ejercicios,
        duracionCalculada: duracionCalculada,
      ),
    );

    // ✅ VERIFICACIÓN EN CONSOLA (puedes ver en Flutter DevTools)
    if (duracionCalculada != null) {
      print(
          '✓ Día ${diaMap['dia_numero']}: ${duracionCalculada.toStringAsFixed(1)} minutos');
    } else {
      print('⚠️ Día ${diaMap['dia_numero']}: Sin duración calculada');
    }
  }
  return resultado;
}

class RutinaDebugScreen extends StatefulWidget {
  const RutinaDebugScreen({super.key});

  @override
  State<RutinaDebugScreen> createState() => _RutinaDebugScreenState();
}

class _RutinaDebugScreenState extends State<RutinaDebugScreen> {
  late Future<List<_RutinaDiaDetalle>> _future;

  @override
  void initState() {
    super.initState();
    _future = _leerActualOGenerar();
  }

  /// Al abrir esta pantalla solo se LEE la semana activa existente; no
  /// se regenera nada (eso quedaría solo para el botón "Regenerar").
  /// Si el usuario no tiene ninguna semana activa todavía, ahí sí se
  /// genera la primera.
  Future<List<_RutinaDiaDetalle>> _leerActualOGenerar() async {
    final userId = supabase.auth.currentUser!.id;
    final semanas = await supabase
        .from('rutinas_semana')
        .select()
        .eq('user_id', userId)
        .eq('activa', true)
        .order('generada_at', ascending: false);

    final semanaId = semanas.isEmpty
        ? await generarRutinaSemanal(userId)
        : semanas.first['id'] as String;
    return _obtenerDetalleSemana(semanaId);
  }

  Future<List<_RutinaDiaDetalle>> _generarYLeer() async {
    final userId = supabase.auth.currentUser!.id;
    final semanaId = await generarRutinaSemanal(userId);
    return _obtenerDetalleSemana(semanaId);
  }

  void _regenerar() {
    setState(() {
      _future = _generarYLeer();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        title: const Text('🔧 DEBUG: motor de rutinas 🔧'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepOrange,
        onPressed: _regenerar,
        icon: const Icon(Icons.refresh),
        label: const Text('Regenerar'),
      ),
      body: FutureBuilder<List<_RutinaDiaDetalle>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.deepOrange),
                  SizedBox(height: 16),
                  Text(
                    'Generando rutina en Supabase...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error generando/leyendo la rutina:\n${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final dias = snapshot.data ?? [];
          if (dias.isEmpty) {
            return const Center(
              child: Text(
                'La semana se generó pero no tiene días.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: dias.length,
            itemBuilder: (context, i) {
              final dia = dias[i];
              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Día ${dia.diaNumero} — '
                            '${_etiquetaTipoDia[dia.tipoDia] ?? dia.tipoDia}',
                            style: const TextStyle(
                              color: Colors.deepOrangeAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // ✅ Mostrar duración calculada aquí
                          if (dia.duracionCalculada != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.3),
                                border: Border.all(color: Colors.greenAccent),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '⏱️ ${dia.duracionCalculada!.toStringAsFixed(1)} min',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.3),
                                border: Border.all(color: Colors.redAccent),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '⚠️ Sin duración',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Divider(color: Colors.white24),
                      if (dia.ejercicios.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '(sin ejercicios asignados — catálogo elegible '
                            'insuficiente para este bloque/tipo de día)',
                            style: TextStyle(color: Colors.orangeAccent),
                          ),
                        ),
                      for (final ej in dia.ejercicios)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text(
                                  '${ej.orden}.',
                                  style: const TextStyle(color: Colors.white38),
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  ej.bloque,
                                  style: const TextStyle(
                                    color: Colors.lightBlueAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  ej.nombre,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              Text(
                                ej.dosisTipo == 'tiempo'
                                    ? '${ej.dosisValor}s'
                                    : '${ej.dosisValor} reps',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
