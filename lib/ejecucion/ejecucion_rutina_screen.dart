/// Parte 3B: pantalla de ejecución de la rutina. Recorre los
/// ejercicios del día en orden, repitiendo el circuito `rondas` veces.
/// Cuenta regresiva de 4s UNA sola vez al inicio de toda la rutina;
/// luego cada ejercicio va directo de descanso a ejecución (sin cuenta
/// regresiva individual), excepto tras el último ejercicio de la
/// última ronda, que va directo a cierre.
library;

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../main.dart';
import 'detector_ejercicio.dart';
import 'modelos_ejecucion.dart';
import 'pantallas/pantalla_cierre.dart';
import 'pantallas/pantalla_cuenta_inicial.dart';
import 'pantallas/pantalla_descanso.dart';
import 'pantallas/pantalla_ejecucion.dart';

class EjecucionRutinaScreen extends StatefulWidget {
  const EjecucionRutinaScreen({
    super.key,
    required this.ejercicios,
    required this.rondas,
    required this.descansoSeg,
    required this.tipoDia,
    required this.diaId,
  });

  final List<EjercicioSesion> ejercicios;
  final int rondas;
  final int descansoSeg;

  /// 'fuerza' | 'cardio' | 'movilidad'.
  final String tipoDia;

  /// id de rutina_dias, para marcarlo completado al terminar.
  final String diaId;

  @override
  State<EjecucionRutinaScreen> createState() => _EjecucionRutinaScreenState();
}

class _EjecucionRutinaScreenState extends State<EjecucionRutinaScreen> {
  CameraController? _controller;
  PoseDetector? _poseDetector;
  InputImageRotation _imageRotation = InputImageRotation.rotation0deg;
  bool _isDetecting = false;
  List<Pose> _poses = [];
  bool _showDebugPanel = false;

  int _pasoActual = 0;
  Fase _fase = Fase.cuentaInicial;
  DetectorEjercicio? _detectorActual;

  /// Controla si se permite salir de esta pantalla sin confirmación
  /// (true una vez que se llega al cierre; false durante la sesión).
  bool _canPop = false;

  final DateTime _inicioSesion = DateTime.now();
  int _repsTotalesSesion = 0;
  int _repsConDeteccion = 0;
  int _numeroRepGlobal = 0;
  final List<({int numeroRep, double profundidadGrados})> _detalleReps = [];

  /// Marca de tiempo de cuándo arrancó el ejercicio actual (fase
  /// ejecución), para medir cuánto tardó cada ejercicio de reps.
  DateTime? _inicioEjercicioActual;
  final List<
      ({
        int paso,
        String ejercicioId,
        int repsCompletadas,
        int segundos,
      })> _tiemposEjercicios = [];

  MetricasCierre? _metricas;
  String? _errorGuardado;

  int get _totalPasos => widget.ejercicios.length * widget.rondas;

  EjercicioSesion get _ejercicioActual =>
      widget.ejercicios[_pasoActual % widget.ejercicios.length];

  bool get _esUltimoPaso => _pasoActual >= _totalPasos - 1;

  EjercicioSesion? get _siguienteEjercicio => _esUltimoPaso
      ? null
      : widget.ejercicios[(_pasoActual + 1) % widget.ejercicios.length];

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      ),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _controller!.initialize();
    if (!mounted) return;

    _imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    await _controller!.startImageStream(_processCameraImage);
    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isNotEmpty) {
        _detectorActual?.procesarPose(poses.first);
      }
      if (mounted) {
        setState(() => _poses = poses);
      }
    } catch (e) {
      debugPrint('Error procesando frame: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _imageRotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  void _iniciarEjercicioActual() {
    setState(() {
      _detectorActual = crearDetectorPara(_ejercicioActual.nombre);
      _fase = Fase.ejecucion;
      _inicioEjercicioActual = DateTime.now();
    });
  }

  void _terminarEjercicioActual(int repsCompletadas) {
    // Acumula reps_totales (solo cuenta ejercicios de reps; los de
    // tiempo pasan repsCompletadas=0) y el detalle por rep de los
    // ejercicios que sí tuvieron detección por cámara.
    if (_ejercicioActual.dosisTipo != 'tiempo') {
      _repsTotalesSesion += repsCompletadas;
      final detector = _detectorActual;
      if (detector != null) {
        _repsConDeteccion += repsCompletadas;
        for (final angulo in detector.profundidadesPorRep) {
          _numeroRepGlobal++;
          _detalleReps.add(
            (numeroRep: _numeroRepGlobal, profundidadGrados: angulo),
          );
        }
      }

      final inicio = _inicioEjercicioActual;
      if (inicio != null) {
        _tiemposEjercicios.add(
          (
            paso: _pasoActual,
            ejercicioId: _ejercicioActual.ejercicioId,
            repsCompletadas: repsCompletadas,
            segundos: DateTime.now().difference(inicio).inSeconds,
          ),
        );
      }
    }

    if (_esUltimoPaso) {
      setState(() {
        _fase = Fase.cierre;
        _canPop = true;
      });
      _finalizarSesion();
    } else {
      setState(() => _fase = Fase.descanso);
    }
  }

  String _etiquetaEjercicio(String tipoDia) {
    const etiquetas = {
      'fuerza': 'Día de Fuerza',
      'cardio': 'Día de Cardio',
      'movilidad': 'Día de Movilidad',
    };
    return etiquetas[tipoDia] ?? tipoDia;
  }

  /// Racha provisional: días calendario consecutivos (incluyendo hoy)
  /// con al menos una workout_sessions guardada. El cálculo formal de
  /// racha se define en la Parte 3D; esto es un valor razonable
  /// mientras tanto.
  Future<int> _calcularRachaProvisional(String userId) async {
    final sesiones = await supabase
        .from('workout_sessions')
        .select('fecha')
        .eq('user_id', userId)
        .order('fecha', ascending: false)
        .limit(60);

    final dias = <DateTime>{};
    for (final s in sesiones as List) {
      final fecha = DateTime.parse(s['fecha'] as String).toLocal();
      dias.add(DateTime(fecha.year, fecha.month, fecha.day));
    }

    var racha = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    while (dias.contains(cursor)) {
      racha++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return racha;
  }

  Future<void> _finalizarSesion() async {
    setState(() => _errorGuardado = null);
    try {
      final duracion = DateTime.now().difference(_inicioSesion);
      final userId = supabase.auth.currentUser!.id;
      final etiqueta = _etiquetaEjercicio(widget.tipoDia);

      // Última sesión del MISMO tipo de día, antes de guardar la de hoy.
      final anterior = await supabase
          .from('workout_sessions')
          .select('reps_totales')
          .eq('user_id', userId)
          .eq('ejercicio', etiqueta)
          .order('fecha', ascending: false)
          .limit(1)
          .maybeSingle();

      final sesionInsertada = await supabase
          .from('workout_sessions')
          .insert({
            'user_id': userId,
            'ejercicio': etiqueta,
            'reps_totales': _repsTotalesSesion,
            'fecha': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      final sessionId = sesionInsertada['id'] as String;

      if (_detalleReps.isNotEmpty) {
        await supabase.from('session_reps').insert(
              _detalleReps
                  .map(
                    (d) => {
                      'session_id': sessionId,
                      'numero_rep': d.numeroRep,
                      'profundidad_grados': d.profundidadGrados,
                    },
                  )
                  .toList(),
            );
      }

      await supabase
          .from('rutina_dias')
          .update({'completado': true}).eq('id', widget.diaId);

      // Dato complementario (ritmo de ejecución para Perfil), no
      // crítico: si falla, no debe tumbar el guardado de la sesión que
      // ya se completó arriba.
      if (_tiemposEjercicios.isNotEmpty) {
        try {
          await supabase.from('session_ejercicio_tiempos').insert(
                _tiemposEjercicios
                    .map(
                      (t) => {
                        'session_id': sessionId,
                        'ejercicio_id': t.ejercicioId,
                        'paso': t.paso,
                        'reps_completadas': t.repsCompletadas,
                        'segundos': t.segundos,
                      },
                    )
                    .toList(),
              );
        } catch (e) {
          debugPrint('No se pudo guardar session_ejercicio_tiempos: $e');
        }
      }

      final racha = await _calcularRachaProvisional(userId);

      final porcentajeValidas =
          (_repsConDeteccion > 0 && _repsTotalesSesion > 0)
              ? (_repsConDeteccion / _repsTotalesSesion * 100).round()
              : null;

      final comparacion = anterior == null
          ? 'Tu primera sesión registrada'
          : _formatearComparacion(
              _repsTotalesSesion,
              anterior['reps_totales'] as int,
              widget.tipoDia,
            );

      if (!mounted) return;
      setState(() {
        _metricas = MetricasCierre(
          duracion: duracion,
          repsTotales: _repsTotalesSesion,
          porcentajeValidas: porcentajeValidas,
          comparacion: comparacion,
          racha: racha,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorGuardado = 'No se pudo guardar tu sesión: $e');
    }
  }

  String _formatearComparacion(int actual, int anterior, String tipoDia) {
    final diferencia = actual - anterior;
    final signo = diferencia > 0 ? '+' : '';
    return '$signo$diferencia reps vs tu última sesión de $tipoDia';
  }

  /// Se llama al terminar el descanso (por cronómetro o "Saltar
  /// descanso"): pasa directo al siguiente ejercicio, sin cuenta
  /// regresiva individual.
  void _avanzarAlSiguientePaso() {
    setState(() {
      _pasoActual++;
      _detectorActual = crearDetectorPara(_ejercicioActual.nombre);
      _fase = Fase.ejecucion;
      _inicioEjercicioActual = DateTime.now();
    });
  }

  Future<bool> _confirmarAbandonar() async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Abandonar la sesión?'),
        content: const Text(
          'No se guardará tu progreso de hoy y el día seguirá pendiente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abandonar'),
          ),
        ],
      ),
    );
    return resultado == true;
  }

  Future<void> _manejarIntentoDeSalir(bool didPop) async {
    if (didPop) return;
    final abandonar = await _confirmarAbandonar();
    if (!mounted || !abandonar) return;
    setState(() => _canPop = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_fase == Fase.cierre) {
      content = PantallaCierre(
        metricas: _metricas,
        error: _errorGuardado,
        onReintentar: _finalizarSesion,
        onListo: () => Navigator.of(context).pop(),
      );
    } else if (_controller == null || !_controller!.value.isInitialized) {
      content = const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    } else {
      // Durante el descanso, el ejercicio de _pasoActual ya se terminó
      // (el incremento pasa hasta _avanzarAlSiguientePaso), así que ahí
      // cuenta como completado para la barra de progreso.
      final completados =
          _fase == Fase.descanso ? _pasoActual + 1 : _pasoActual;

      content = switch (_fase) {
        Fase.cuentaInicial => PantallaCuentaInicial(
            ejercicio: _ejercicioActual,
            onListo: _iniciarEjercicioActual,
          ),
        Fase.ejecucion => PantallaEjecucion(
            key: ValueKey('ejecucion_$_pasoActual'),
            controller: _controller!,
            poses: _poses,
            ejercicio: _ejercicioActual,
            detector: _detectorActual,
            showDebugPanel: _showDebugPanel,
            onToggleDebugPanel: () =>
                setState(() => _showDebugPanel = !_showDebugPanel),
            onTerminar: _terminarEjercicioActual,
            completados: completados,
            ejerciciosPorRonda: widget.ejercicios.length,
            rondas: widget.rondas,
          ),
        Fase.descanso => PantallaDescanso(
            key: ValueKey('descanso_$_pasoActual'),
            segundos: widget.descansoSeg,
            siguienteEjercicio: _siguienteEjercicio,
            onTerminar: _avanzarAlSiguientePaso,
            completados: completados,
            ejerciciosPorRonda: widget.ejercicios.length,
            rondas: widget.rondas,
          ),
        Fase.cierre => const SizedBox.shrink(),
      };
    }

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) =>
          _manejarIntentoDeSalir(didPop),
      child: content,
    );
  }
}
