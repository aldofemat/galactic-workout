/// Pantalla 3 del ciclo: descanso entre ejercicios.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme.dart';
import '../beeper.dart';
import '../modelos_ejecucion.dart';
import '../widgets/barra_progreso.dart';
import '../widgets/circulo_numero.dart';
import '../widgets/texto_auto_ajustable.dart';
import '../widgets/video_placeholder.dart';

class PantallaDescanso extends StatefulWidget {
  const PantallaDescanso({
    super.key,
    required this.segundos,
    required this.siguienteEjercicio,
    required this.onTerminar,
    required this.completados,
    required this.ejerciciosPorRonda,
    required this.rondas,
  });

  final int segundos;
  final EjercicioSesion? siguienteEjercicio;
  final VoidCallback onTerminar;

  /// Para la barra de progreso de toda la rutina.
  final int completados;
  final int ejerciciosPorRonda;
  final int rondas;

  @override
  State<PantallaDescanso> createState() => PantallaDescansoState();
}

class PantallaDescansoState extends State<PantallaDescanso> {
  late int _segundosRestantes = widget.segundos;
  Timer? _timer;
  final _beeper = Beeper();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _segundosRestantes--);
      if (_segundosRestantes <= 0) {
        _timer?.cancel();
        _beeper.doble();
        widget.onTerminar();
      } else if (_segundosRestantes <= 3) {
        _beeper.simple();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final siguiente = widget.siguienteEjercicio;
    final dosisSiguienteTexto = siguiente == null
        ? null
        : (siguiente.dosisTipo == 'tiempo'
            ? '${siguiente.dosisValor} SEGUNDOS'
            : '${siguiente.dosisValor} REPETICIONES');

    // "RONDA X · Y/Z": ronda actual y posición dentro del total de la
    // sesión del ejercicio que sigue (el que arranca al terminar este
    // descanso, o sea el que está en el índice `completados`).
    final rondaActual = (widget.completados ~/ widget.ejerciciosPorRonda) + 1;
    final posicionActual = (widget.completados % widget.ejerciciosPorRonda) + 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // El video del siguiente ejercicio de fondo, a pantalla
          // completa: es el protagonista de esta pantalla.
          VideoOPlaceholder(
            mediaUrl: siguiente?.mediaUrl,
            width: double.infinity,
            height: double.infinity,
            borderRadius: 0,
          ),
          // Degradados oscuros arriba y abajo, bien opacos, para que
          // el texto resalte claramente sobre el video sin perderse.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 340,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.55, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.97),
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [0.0, 0.5, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.97),
                    Colors.black.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                const Text(
                  'DESCANSO',
                  style: TextStyle(
                    color: AppColors.brandBright,
                    fontSize: 18,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: BarraProgresoRutina(
                    completados: widget.completados,
                    ejerciciosPorRonda: widget.ejerciciosPorRonda,
                    rondas: widget.rondas,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'RONDA $rondaActual · $posicionActual/${widget.ejerciciosPorRonda}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (siguiente != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SIGUIENTE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            letterSpacing: 3,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 28,
                          height: 3,
                          color: AppColors.brandBright,
                        ),
                        const SizedBox(height: 8),
                        TextoAutoAjustable(
                          texto: siguiente.nombre.toUpperCase(),
                          maxFontSize: 26,
                          minFontSize: 16,
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: AppColors.brandBright,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: TextoAutoAjustable(
                                texto: dosisSiguienteTexto!,
                                maxFontSize: 18,
                                minFontSize: 13,
                                maxLines: 1,
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  color: AppColors.brandBright,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                Builder(
                  builder: (context) {
                    // Medidas exactas (no proporciones del propio
                    // círculo, que fue lo que causaba que el número
                    // casi tocara el anillo): diámetro y tipografía
                    // del cronómetro son dp/sp fijos; solo el margen
                    // lateral y el ancho del botón son % del ancho de
                    // pantalla, a propósito, para que quepan en
                    // cualquier tamaño.
                    final anchoPantalla = MediaQuery.of(context).size.width;
                    final margenLateral = anchoPantalla * 0.05;
                    final anchoBoton = anchoPantalla * 0.46;
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: margenLateral),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CirculoNumero(
                              texto: '$_segundosRestantes',
                              diametro: 120,
                              progreso: _segundosRestantes / widget.segundos,
                              grosorAnillo: 5,
                              numeroFontSize: 40,
                            ),
                          ),
                          const SizedBox(width: 32),
                          SizedBox(
                            width: anchoBoton,
                            height: 58,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: const StadiumBorder(),
                                side: const BorderSide(
                                  color: AppColors.brandBright,
                                  width: 2,
                                ),
                                foregroundColor: AppColors.brandBright,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              ),
                              onPressed: () {
                                _timer?.cancel();
                                widget.onTerminar();
                              },
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'SALTAR DESCANSO',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
