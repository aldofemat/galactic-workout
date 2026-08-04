/// Pantalla 2 del ciclo: ejecución con cámara en vivo.
library;

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../pose_painter.dart';
import '../beeper.dart';
import '../detector_ejercicio.dart';
import '../modelos_ejecucion.dart';
import '../widgets/barra_progreso.dart';
import '../widgets/circulo_numero.dart';
import '../widgets/texto_auto_ajustable.dart';

class PantallaEjecucion extends StatefulWidget {
  const PantallaEjecucion({
    super.key,
    required this.controller,
    required this.poses,
    required this.ejercicio,
    required this.detector,
    required this.showDebugPanel,
    required this.onToggleDebugPanel,
    required this.onTerminar,
    required this.completados,
    required this.ejerciciosPorRonda,
    required this.rondas,
  });

  final CameraController controller;
  final List<Pose> poses;
  final EjercicioSesion ejercicio;
  final DetectorEjercicio? detector;
  final bool showDebugPanel;
  final VoidCallback onToggleDebugPanel;

  /// Se llama al terminar (por meta alcanzada, tiempo agotado, o salto
  /// manual), pasando cuántas reps se completaron realmente (0 para
  /// ejercicios de tiempo).
  final ValueChanged<int> onTerminar;

  /// Para la barra de progreso de toda la rutina.
  final int completados;
  final int ejerciciosPorRonda;
  final int rondas;

  @override
  State<PantallaEjecucion> createState() => PantallaEjecucionState();
}

class PantallaEjecucionState extends State<PantallaEjecucion> {
  Timer? _timer;
  int _segundosRestantes = 0;
  int _repsManual = 0;
  bool _terminadoDisparado = false;
  final _beeper = Beeper();

  bool get _esTiempo => widget.ejercicio.dosisTipo == 'tiempo';

  @override
  void initState() {
    super.initState();
    if (_esTiempo) {
      _segundosRestantes = widget.ejercicio.dosisValor;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _segundosRestantes--);
        if (_segundosRestantes <= 0) {
          _timer?.cancel();
          _beeper.doble();
          widget.onTerminar(0);
        } else if (_segundosRestantes <= 3) {
          _beeper.simple();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sumarRepManual() {
    setState(() => _repsManual++);
    if (_repsManual >= widget.ejercicio.dosisValor) {
      widget.onTerminar(_repsManual);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repsCamara = widget.detector?.reps;

    if (!_esTiempo &&
        repsCamara != null &&
        repsCamara >= widget.ejercicio.dosisValor &&
        !_terminadoDisparado) {
      _terminadoDisparado = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onTerminar(repsCamara),
      );
    }

    final indicadorPrincipal = _esTiempo
        ? '$_segundosRestantes'
        : '${repsCamara ?? _repsManual} / ${widget.ejercicio.dosisValor}';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(widget.controller),
          CustomPaint(
            painter: PosePainter(
              widget.poses,
              Size(
                widget.controller.value.previewSize!.height,
                widget.controller.value.previewSize!.width,
              ),
              InputImageRotation.rotation0deg,
            ),
          ),
          // Toque en pantalla muestra/oculta el panel de diagnóstico,
          // igual que en CameraPoseScreen.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onToggleDebugPanel,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 0,
            right: 0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: Colors.black.withValues(alpha: 0.6),
              child: TextoAutoAjustable(
                texto: widget.ejercicio.nombre,
                maxFontSize: 30,
                minFontSize: 18,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Positioned(
            top: 160,
            left: 0,
            right: 0,
            child: Center(
              child: CirculoNumero(texto: indicadorPrincipal),
            ),
          ),
          if (!_esTiempo && repsCamara == null)
            Positioned(
              bottom: 130,
              left: 40,
              right: 40,
              child: SizedBox(
                height: 70,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _sumarRepManual,
                  child: const Text('+1'),
                ),
              ),
            ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton(
                onPressed: () => widget
                    .onTerminar(_esTiempo ? 0 : (repsCamara ?? _repsManual)),
                child: const Text(
                  'Saltar ejercicio',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 20,
            right: 20,
            child: BarraProgresoRutina(
              completados: widget.completados,
              ejerciciosPorRonda: widget.ejerciciosPorRonda,
              rondas: widget.rondas,
            ),
          ),
          if (widget.showDebugPanel)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  widget.detector?.debugInfo ??
                      'Sin datos de diagnóstico para este ejercicio '
                          '(conteo manual).',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
