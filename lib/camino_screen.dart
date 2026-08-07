/// Pestaña "Entrenamiento": un camino tipo journey (Duolingo-style) con
/// un nodo por cada rutina_dias del usuario, de todas sus semanas, en
/// orden cronológico. No se reinicia por semana: es un camino infinito
/// que acumula historial. Al abrir, la vista arranca centrada en el
/// día actual.
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'main.dart';
import 'motor/generador_rutina.dart';
import 'motor/nivel_progreso.dart';
import 'rutina_preview_screen.dart';
import 'theme.dart';

enum _EstadoNodo { completado, actual, bloqueado }

class _NodoCamino {
  const _NodoCamino({
    required this.diaId,
    required this.tipoDia,
    required this.estado,
  });

  final String diaId;
  final String tipoDia;
  final _EstadoNodo estado;
}

class _CaminoData {
  const _CaminoData({
    required this.nodos,
    required this.indiceActual,
    required this.racha,
    required this.semanaOrdinal,
    required this.nivelNombre,
  });

  final List<_NodoCamino> nodos;

  /// -1 si no hay ningún día pendiente (no debería pasar: siempre se
  /// asegura una semana con al menos un día pendiente antes de volver).
  final int indiceActual;
  final int racha;
  final int semanaOrdinal;
  final String nivelNombre;
}

const _iconoPorTipoDia = {
  'fuerza': Icons.fitness_center,
  'cardio': Icons.monitor_heart,
  'movilidad': Icons.accessibility_new,
};

class CaminoScreen extends StatefulWidget {
  const CaminoScreen({super.key});

  @override
  State<CaminoScreen> createState() => _CaminoScreenState();
}

class _CaminoScreenState extends State<CaminoScreen> {
  static const _espacioVertical = 150.0;
  static const _radioNormal = 32.0;
  static const _radioActual = 44.0;

  late Future<_CaminoData> _future;
  final _scrollController = ScrollController();
  bool _yaCentroEnActual = false;

  @override
  void initState() {
    super.initState();
    _future = _cargarCamino();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _reintentar() {
    setState(() {
      _future = _cargarCamino();
      _yaCentroEnActual = false;
    });
  }

  double _xFrac(int i) => 0.5 + 0.3 * sin(i * pi / 2);

  Future<void> _abrirVistaPrevia(String diaId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RutinaPreviewScreen(diaId: diaId)),
    );
    // Al volver (se haya empezado la rutina o no) se recarga el camino
    // para reflejar cualquier día recién completado.
    if (mounted) _reintentar();
  }

  /// Tolerancia de racha = techo(7 / dias_plan), mínimo 2. Misma regla
  /// que en la pestaña Progreso.
  int _tolerancia(int? diasPlan) {
    final plan = diasPlan ?? 3;
    final tolerancia = (7 / plan).ceil();
    return tolerancia < 2 ? 2 : tolerancia;
  }

  Future<int> _calcularRacha(String userId, int? diasPlanActivo) async {
    final sesiones = await supabase
        .from('workout_sessions')
        .select('fecha')
        .eq('user_id', userId)
        .order('fecha', ascending: false)
        .limit(200);

    final fechas = <DateTime>{};
    for (final s in sesiones as List) {
      final f = DateTime.parse(s['fecha'] as String).toLocal();
      fechas.add(DateTime(f.year, f.month, f.day));
    }
    final diasDesc = fechas.toList()..sort((a, b) => b.compareTo(a));
    if (diasDesc.isEmpty) return 0;

    final tolerancia = _tolerancia(diasPlanActivo);
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final gapHoy = hoySinHora.difference(diasDesc.first).inDays;
    if (gapHoy > tolerancia) return 0;

    var racha = 1;
    for (var i = 1; i < diasDesc.length; i++) {
      final gap = diasDesc[i - 1].difference(diasDesc[i]).inDays;
      if (gap <= tolerancia) {
        racha++;
      } else {
        break;
      }
    }
    return racha;
  }

  Future<_CaminoData> _cargarCamino() async {
    final userId = supabase.auth.currentUser!.id;

    var semanas = await supabase
        .from('rutinas_semana')
        .select()
        .eq('user_id', userId)
        .order('generada_at', ascending: true);

    if ((semanas as List).isEmpty) {
      await generarRutinaSemanal(userId);
      semanas = await supabase
          .from('rutinas_semana')
          .select()
          .eq('user_id', userId)
          .order('generada_at', ascending: true);
    }

    // La semana activa determina el nodo "actual": es el primer día con
    // completado=false DENTRO de esa semana específicamente (no el
    // primer completado=false de todo el historial, que podría ser un
    // día viejo abandonado de una semana ya inactiva). El resto de los
    // días —de cualquier semana— usa su flag completado real tal cual
    // está guardado.
    Map<String, dynamic>? semanaActiva = semanas
        .cast<Map<String, dynamic>?>()
        .firstWhere((s) => s?['activa'] == true, orElse: () => null);
    semanaActiva ??= semanas.isNotEmpty ? semanas.last : null;
    final semanaActivaId = semanaActiva?['id'];

    final nodos = <_NodoCamino>[];
    var indiceActual = -1;

    for (final semana in semanas) {
      final esSemanaActiva = semana['id'] == semanaActivaId;

      final semanaId = semana['id'] as String;
      debugPrint('📍 Cargando días para semana: $semanaId');
      final dias = await supabase
          .from('rutina_dias')
          .select()
          .eq('semana_id', semanaId)
          .order('dia_numero', ascending: true);
      debugPrint('📊 Días obtenidos: ${dias.length} | Contenido: $dias');

      var yaHayPendienteEnEstaSemana = false;
      for (final dia in dias as List) {
        final completado = dia['completado'] as bool;
        _EstadoNodo estado;
        if (completado) {
          estado = _EstadoNodo.completado;
        } else if (esSemanaActiva && !yaHayPendienteEnEstaSemana) {
          estado = _EstadoNodo.actual;
          indiceActual = nodos.length;
          yaHayPendienteEnEstaSemana = true;
        } else {
          estado = _EstadoNodo.bloqueado;
        }
        nodos.add(
          _NodoCamino(
            diaId: dia['id'] as String,
            tipoDia: dia['tipo_dia'] as String,
            estado: estado,
          ),
        );
      }
    }
    debugPrint('🎯 TOTAL nodos creados: ${nodos.length}');
    for (var i = 0; i < nodos.length; i++) {
      debugPrint('   Nodo $i: ${nodos[i].tipoDia} - ${nodos[i].estado}');
    }
    // Si la semana activa no tiene ningún día pendiente, ya está
    // completada (invariante ya garantizado en otras pantallas): se
    // genera una semana nueva y se agrega al final del camino.
    if (indiceActual == -1) {
      final nuevaSemanaId = await generarRutinaSemanal(userId);
      final dias = await supabase
          .from('rutina_dias')
          .select()
          .eq('semana_id', nuevaSemanaId)
          .order('dia_numero', ascending: true);
      indiceActual = nodos.length;
      for (final dia in dias as List) {
        nodos.add(
          _NodoCamino(
            diaId: dia['id'] as String,
            tipoDia: dia['tipo_dia'] as String,
            estado: nodos.length == indiceActual
                ? _EstadoNodo.actual
                : _EstadoNodo.bloqueado,
          ),
        );
      }
      semanaActiva = await supabase
          .from('rutinas_semana')
          .select()
          .eq('id', nuevaSemanaId)
          .single();
      semanas = [...semanas, semanaActiva];
    }

    final semanaOrdinal = semanas.indexWhere(
          (s) => s['id'] == semanaActiva?['id'],
        ) +
        1;
    final nivelNombre =
        nombresNivel[semanaActiva?['nivel_usuario'] as int? ?? 0] ??
            'Nivel ${semanaActiva?['nivel_usuario']}';

    final racha = await _calcularRacha(
      userId,
      semanaActiva?['dias_plan'] as int?,
    );

    return _CaminoData(
      nodos: nodos,
      indiceActual: indiceActual,
      racha: racha,
      semanaOrdinal: semanaOrdinal,
      nivelNombre: nivelNombre,
    );
  }

  void _centrarEnActualSiHaceFalta(_CaminoData data, double width) {
    if (_yaCentroEnActual || data.indiceActual < 0) return;
    _yaCentroEnActual = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final centroY =
          _espacioVertical * data.indiceActual + _espacioVertical / 2;
      final viewport = _scrollController.position.viewportDimension;
      final objetivo = (centroY - viewport / 2).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(objetivo);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CaminoData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.brandBright),
                SizedBox(height: 20),
                Text(
                  'Armando tu camino...',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No se pudo cargar tu camino:\n${snapshot.error}',
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _reintentar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Text(
                      'Entrenamiento',
                      style: TextStyle(
                        color: AppColors.brandBright,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '🔥 ${data.racha}',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Semana ${data.semanaOrdinal} · ${data.nivelNombre}',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _centrarEnActualSiHaceFalta(data, constraints.maxWidth);
                  final altura = data.nodos.isEmpty
                      ? constraints.maxHeight
                      : _espacioVertical * data.nodos.length;
                  debugPrint(
                      '📏 Renderizando: nodos=${data.nodos.length}, altura calculada=$altura, maxWidth=${constraints.maxWidth}');

                  final centros = [
                    for (var i = 0; i < data.nodos.length; i++)
                      Offset(
                        _xFrac(i) * constraints.maxWidth,
                        _espacioVertical * i + _espacioVertical / 2,
                      ),
                  ];
                  debugPrint(
                      '📋 Creando ${data.nodos.length} nodos widgets...');
                  return SingleChildScrollView(
                    controller: _scrollController,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: altura,
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: Size(constraints.maxWidth, altura),
                            painter: _CaminoPainter(
                              centros: centros,
                              nodos: data.nodos,
                            ),
                          ),
                          for (var i = 0; i < data.nodos.length; i++)
                            _NodoWidget(
                              centro: centros[i],
                              nodo: data.nodos[i],
                              radioNormal: _radioNormal,
                              radioActual: _radioActual,
                              onTap: data.nodos[i].estado == _EstadoNodo.actual
                                  ? () => _abrirVistaPrevia(data.nodos[i].diaId)
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CaminoPainter extends CustomPainter {
  _CaminoPainter({required this.centros, required this.nodos});

  final List<Offset> centros;
  final List<_NodoCamino> nodos;

  @override
  void paint(Canvas canvas, Size size) {
    debugPrint('🎨 Pintando camino: ${centros.length} centros, size=$size');
    for (var i = 1; i < centros.length; i++) {
      final p1 = centros[i - 1];
      final p2 = centros[i];
      final midY = (p1.dy + p2.dy) / 2;

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(p1.dx, midY, p2.dx, midY, p2.dx, p2.dy);

      // El color del tramo depende del nodo de DESTINO: verde si lleva a
      // un nodo ya completado o al actual, gris si lleva a uno bloqueado.
      final destino = nodos[i].estado;
      final verde = destino != _EstadoNodo.bloqueado;
      final paint = Paint()
        ..color = verde ? AppColors.brandBright : Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CaminoPainter oldDelegate) =>
      oldDelegate.centros != centros || oldDelegate.nodos != nodos;
}

class _NodoWidget extends StatelessWidget {
  const _NodoWidget({
    required this.centro,
    required this.nodo,
    required this.radioNormal,
    required this.radioActual,
    this.onTap,
  });

  final Offset centro;
  final _NodoCamino nodo;
  final double radioNormal;
  final double radioActual;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final esActual = nodo.estado == _EstadoNodo.actual;
    final radio = esActual ? radioActual : radioNormal;
    // Todos los estados muestran el ícono del tipo de día; lo único
    // que cambia entre completado/actual/bloqueado es el color.
    final icono = _iconoPorTipoDia[nodo.tipoDia] ?? Icons.circle;

    Color fondo;
    Color borde;
    Color iconoColor;
    switch (nodo.estado) {
      case _EstadoNodo.completado:
        fondo = AppColors.brandDark;
        borde = AppColors.brandBright;
        iconoColor = AppColors.brandBright;
      case _EstadoNodo.actual:
        fondo = AppColors.brandBright;
        borde = AppColors.brandBright;
        iconoColor = Colors.black;
      case _EstadoNodo.bloqueado:
        fondo = const Color(0xFF1A1A1A);
        borde = Colors.white24;
        iconoColor = Colors.white38;
    }

    return Positioned(
      left: centro.dx - radio,
      top: centro.dy - radio,
      width: radio * 2,
      height: radio * 2,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fondo,
          border: Border.all(color: borde, width: esActual ? 3 : 2),
          boxShadow: esActual
              ? [
                  BoxShadow(
                    color: AppColors.brandBright.withValues(alpha: 0.55),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(icono, color: iconoColor, size: radio * 0.75),
          ),
        ),
      ),
    );
  }
}
