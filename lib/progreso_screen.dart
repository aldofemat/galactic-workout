/// Parte 3D: pestaña "Progreso" — 3 secciones (racha, evolución, nivel).
library;

import 'package:flutter/material.dart';
import 'main.dart';
import 'motor/nivel_calculator.dart';
import 'motor/nivel_progreso.dart';
import 'theme.dart';

class _EvolucionPunto {
  const _EvolucionPunto({
    required this.fecha,
    required this.repsValidas,
    required this.porcentajeValidas,
  });

  final DateTime fecha;
  final int repsValidas;
  final int porcentajeValidas;
}

class _ProgresoData {
  const _ProgresoData({
    required this.racha,
    required this.diasEntrenadosMes,
    required this.evolucion,
    required this.nivelResultado,
    required this.mensajeFaltante,
  });

  final int racha;
  final Set<DateTime> diasEntrenadosMes;
  final List<_EvolucionPunto> evolucion;
  final NivelResultado nivelResultado;
  final String mensajeFaltante;
}

/// Pestaña "Progreso": racha con tolerancia + calendario del mes,
/// evolución de reps válidas por sesión, y nivel actual + qué falta
/// para el siguiente.
class ProgresoScreen extends StatefulWidget {
  const ProgresoScreen({super.key});

  @override
  State<ProgresoScreen> createState() => _ProgresoScreenState();
}

class _ProgresoScreenState extends State<ProgresoScreen> {
  late Future<_ProgresoData> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargar();
  }

  Future<void> _recargar() async {
    final future = _cargar();
    setState(() {
      _future = future;
    });
    await future;
  }

  /// tolerancia_dias = techo(7 / dias_plan), mínimo 2. Usa el dias_plan
  /// de la semana activa; si no hay ninguna, asume 3 (el plan mínimo).
  Future<int> _obtenerToleranciaDias(String userId) async {
    final semana = await supabase
        .from('rutinas_semana')
        .select('dias_plan')
        .eq('user_id', userId)
        .eq('activa', true)
        .maybeSingle();
    final diasPlan = (semana?['dias_plan'] as int?) ?? 3;
    final tolerancia = (7 / diasPlan).ceil();
    return tolerancia < 2 ? 2 : tolerancia;
  }

  /// Días calendario (sin hora) con al menos una workout_sessions,
  /// más recientes primero.
  Future<List<DateTime>> _obtenerDiasEntrenados(String userId) async {
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
    final ordenadas = fechas.toList()..sort((a, b) => b.compareTo(a));
    return ordenadas;
  }

  /// Racha CON TOLERANCIA: cuenta días entrenados consecutivos desde
  /// el más reciente, sin romperse mientras el hueco entre dos días
  /// entrenados no supere la tolerancia. No son días de calendario
  /// estrictamente seguidos — son días de descanso "perdonados".
  int _calcularRacha(List<DateTime> diasEntrenadosDesc, int tolerancia) {
    if (diasEntrenadosDesc.isEmpty) return 0;

    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final gapHoy = hoySinHora.difference(diasEntrenadosDesc.first).inDays;
    if (gapHoy > tolerancia) return 0;

    var racha = 1;
    for (var i = 1; i < diasEntrenadosDesc.length; i++) {
      final gap =
          diasEntrenadosDesc[i - 1].difference(diasEntrenadosDesc[i]).inDays;
      if (gap <= tolerancia) {
        racha++;
      } else {
        break;
      }
    }
    return racha;
  }

  /// Progresión de reps válidas (con detección de cámara) por sesión.
  /// Solo incluye sesiones que sí tuvieron al menos una rep detectada.
  Future<List<_EvolucionPunto>> _obtenerEvolucion(String userId) async {
    final data = await supabase
        .from('workout_sessions')
        .select('fecha, reps_totales, session_reps(count)')
        .eq('user_id', userId)
        .order('fecha', ascending: true)
        .limit(60);

    final puntos = <_EvolucionPunto>[];
    for (final row in data as List) {
      final conteos = row['session_reps'] as List?;
      final repsValidas = (conteos != null && conteos.isNotEmpty)
          ? conteos.first['count'] as int
          : 0;
      if (repsValidas <= 0) continue;
      final repsTotales = row['reps_totales'] as int;
      puntos.add(
        _EvolucionPunto(
          fecha: DateTime.parse(row['fecha'] as String).toLocal(),
          repsValidas: repsValidas,
          porcentajeValidas:
              repsTotales > 0 ? (repsValidas / repsTotales * 100).round() : 0,
        ),
      );
    }
    return puntos;
  }

  Future<_ProgresoData> _cargar() async {
    final userId = supabase.auth.currentUser!.id;

    final tolerancia = await _obtenerToleranciaDias(userId);
    final diasEntrenados = await _obtenerDiasEntrenados(userId);
    final racha = _calcularRacha(diasEntrenados, tolerancia);

    final ahora = DateTime.now();
    final diasEntrenadosMes = diasEntrenados
        .where((d) => d.year == ahora.year && d.month == ahora.month)
        .toSet();

    final evolucion = await _obtenerEvolucion(userId);

    final perfil =
        await supabase.from('profiles').select().eq('id', userId).single();
    final nivelResultado = calcularNivelDesdePerfil(perfil);
    final mensajeFaltante = calcularMensajeFaltante(
      nivel: nivelResultado,
      sentadillasReps: perfil['sentadillas_reps'] as int? ?? 0,
      lagartijasReps: perfil['lagartijas_reps'] as int? ?? 0,
      dominadasReps: perfil['dominadas_reps'] as int? ?? 0,
      correTiempo: perfil['corre_tiempo'] as String?,
      paradaManos: perfil['parada_manos'] as bool?,
      paradaManosTiempo: perfil['parada_manos_tiempo'] as String?,
    );

    return _ProgresoData(
      racha: racha,
      diasEntrenadosMes: diasEntrenadosMes,
      evolucion: evolucion,
      nivelResultado: nivelResultado,
      mensajeFaltante: mensajeFaltante,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: FutureBuilder<_ProgresoData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.brandBright),
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
                        'No se pudo cargar tu progreso:\n${snapshot.error}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _recargar,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _recargar,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _SeccionRacha(
                    racha: data.racha,
                    diasEntrenadosMes: data.diasEntrenadosMes,
                  ),
                  const SizedBox(height: 36),
                  _SeccionEvolucion(evolucion: data.evolucion),
                  const SizedBox(height: 36),
                  _SeccionNivel(
                    nivel: data.nivelResultado,
                    mensajeFaltante: data.mensajeFaltante,
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await supabase.auth.signOut();
                    },
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    label: const Text(
                      'Cerrar sesión',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
  }
}

/// Sección 1: racha + calendario del mes.
class _SeccionRacha extends StatelessWidget {
  const _SeccionRacha({required this.racha, required this.diasEntrenadosMes});

  final int racha;
  final Set<DateTime> diasEntrenadosMes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSeccion('RACHA'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$racha',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 64,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                racha == 1 ? 'día seguido' : 'días seguidos',
                style: const TextStyle(color: Colors.white70, fontSize: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _CalendarioMes(diasEntrenados: diasEntrenadosMes),
      ],
    );
  }
}

class _CalendarioMes extends StatelessWidget {
  const _CalendarioMes({required this.diasEntrenados});

  final Set<DateTime> diasEntrenados;

  static const _nombresDias = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final primerDia = DateTime(ahora.year, ahora.month, 1);
    final diasEnMes = DateTime(ahora.year, ahora.month + 1, 0).day;
    final offset = primerDia.weekday - 1;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _nombresDias
              .map(
                (d) => Text(
                  d,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: offset + diasEnMes,
          itemBuilder: (context, index) {
            if (index < offset) return const SizedBox.shrink();
            final dia = index - offset + 1;
            final fecha = DateTime(ahora.year, ahora.month, dia);
            final entrenado = diasEntrenados.contains(fecha);
            final esHoy = dia == ahora.day;
            return Container(
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: entrenado ? AppColors.brandBright : Colors.white10,
                shape: BoxShape.circle,
                border:
                    esHoy ? Border.all(color: Colors.white, width: 1.5) : null,
              ),
              child: Center(
                child: Text(
                  '$dia',
                  style: TextStyle(
                    color: entrenado ? Colors.white : Colors.white38,
                    fontSize: 12,
                    fontWeight: entrenado ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Sección 2: evolución de reps válidas por sesión (lista si hay pocos
/// datos, línea de tendencia simple con 5 o más).
class _SeccionEvolucion extends StatelessWidget {
  const _SeccionEvolucion({required this.evolucion});

  final List<_EvolucionPunto> evolucion;

  static const _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  String _formatFecha(DateTime f) => '${f.day} de ${_meses[f.month - 1]}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSeccion('TU EVOLUCIÓN'),
        const SizedBox(height: 12),
        if (evolucion.isEmpty)
          const Text(
            'Todavía no hay sesiones con detección de cámara.',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          )
        else if (evolucion.length < 5)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: evolucion.reversed
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '${_formatFecha(p.fecha)}: ${p.repsValidas} reps · '
                      '${p.porcentajeValidas}% válidas',
                      style: const TextStyle(color: Colors.white, fontSize: 17),
                    ),
                  ),
                )
                .toList(),
          )
        else ...[
          _LineaTendencia(
              valores: evolucion.map((p) => p.repsValidas).toList()),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatFecha(evolucion.first.fecha),
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
              Text(
                _formatFecha(evolucion.last.fecha),
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LineaTendencia extends StatelessWidget {
  const _LineaTendencia({required this.valores});

  final List<int> valores;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: CustomPaint(painter: _TendenciaPainter(valores)),
    );
  }
}

class _TendenciaPainter extends CustomPainter {
  _TendenciaPainter(this.valores);

  final List<int> valores;

  @override
  void paint(Canvas canvas, Size size) {
    if (valores.isEmpty) return;

    final maxV = valores.reduce((a, b) => a > b ? a : b).toDouble();
    final minV = valores.reduce((a, b) => a < b ? a : b).toDouble();
    final rango = (maxV - minV) == 0 ? 1 : (maxV - minV);

    final linea = Paint()
      ..color = AppColors.brandBright
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final punto = Paint()..color = AppColors.brandBright;

    const margen = 8.0;
    final anchoUtil = size.width - margen * 2;
    final altoUtil = size.height - margen * 2;
    final dx = valores.length > 1 ? anchoUtil / (valores.length - 1) : 0.0;

    Offset posicion(int i) {
      final x = margen + dx * i;
      final normalizado = (valores[i] - minV) / rango;
      final y = margen + altoUtil - (normalizado * altoUtil);
      return Offset(x, y);
    }

    final path = Path();
    for (var i = 0; i < valores.length; i++) {
      final p = posicion(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, linea);

    for (var i = 0; i < valores.length; i++) {
      canvas.drawCircle(posicion(i), 4, punto);
    }
  }

  @override
  bool shouldRepaint(covariant _TendenciaPainter oldDelegate) =>
      oldDelegate.valores != valores;
}

/// Sección 3: nivel actual, sub-niveles, y qué falta para el siguiente.
class _SeccionNivel extends StatelessWidget {
  const _SeccionNivel({required this.nivel, required this.mensajeFaltante});

  final NivelResultado nivel;
  final String mensajeFaltante;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSeccion('TU NIVEL'),
        const SizedBox(height: 8),
        Text(
          '${nombresNivel[nivel.nivel]} (nivel ${nivel.nivel})',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _FilaSubnivel('Sentadillas', nivel.nivelSentadillas),
        _FilaSubnivel('Lagartijas', nivel.nivelLagartijas),
        _FilaSubnivel('Dominadas', nivel.nivelDominadas),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.brandDark.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppColors.brandBright.withValues(alpha: 0.4)),
          ),
          child: Text(
            mensajeFaltante,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilaSubnivel extends StatelessWidget {
  const _FilaSubnivel(this.nombre, this.nivel);

  final String nombre;
  final int nivel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            nombre,
            style: const TextStyle(color: Colors.white70, fontSize: 17),
          ),
          Text(
            nombresNivel[nivel] ?? '$nivel',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
