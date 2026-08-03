/// Parte 3B: pantalla de ejecución de la rutina. Recorre los
/// ejercicios del día en orden, repitiendo el circuito `rondas` veces.
/// Cuenta regresiva de 4s UNA sola vez al inicio de toda la rutina;
/// luego cada ejercicio va directo de descanso a ejecución (sin cuenta
/// regresiva individual), excepto tras el último ejercicio de la
/// última ronda, que va directo a cierre.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:video_player/video_player.dart';
import '../main.dart';
import '../pose_painter.dart';
import '../theme.dart';
import 'detector_ejercicio.dart';

/// Campanita ("tin") para las cuentas regresivas: una sola en 3-2-1,
/// doble "tin-tin" al llegar a 0. Reproduce por el volumen de medios
/// del dispositivo (respeta el volumen, no fuerza nada en silencio).
///
/// Cada beep usa su propio AudioPlayer nuevo, en vez de reutilizar uno
/// solo: reproducir varias veces seguidas en el mismo reproductor
/// fallaba después del primer intento. Además, al no depender de un
/// reproductor guardado en el State, un beep en curso no se corta
/// aunque la pantalla que lo disparó ya se haya cerrado (importante
/// para el doble beep del final, que dispara justo cuando se navega a
/// la siguiente pantalla).
class _Beeper {
  static final _sonido = AssetSource('audio/tin.wav');

  Future<void> _tocarUnaVez() async {
    final player = AudioPlayer();
    try {
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.play(_sonido);
      // Se espera a que termine de sonar antes de liberar el
      // reproductor (la campanita dura ~550ms).
      await Future.delayed(const Duration(milliseconds: 700));
    } catch (_) {
      // Se ignora: es solo un efecto de sonido, no algo crítico.
    } finally {
      await player.dispose();
    }
  }

  Future<void> simple() => _tocarUnaVez();

  Future<void> doble() async {
    unawaited(_tocarUnaVez());
    await Future.delayed(const Duration(milliseconds: 220));
    unawaited(_tocarUnaVez());
  }
}

/// Un ejercicio ya resuelto para la sesión de hoy: lo mínimo que la
/// pantalla de ejecución necesita saber de él.
class EjercicioSesion {
  const EjercicioSesion({
    required this.ejercicioId,
    required this.nombre,
    required this.mediaUrl,
    required this.dosisTipo,
    required this.dosisValor,
  });

  /// id real en el catálogo `ejercicios`, para poder guardar
  /// session_ejercicio_tiempos con una referencia de verdad (no el
  /// nombre como texto suelto).
  final String ejercicioId;
  final String nombre;
  final String? mediaUrl;
  final String dosisTipo; // 'tiempo' | 'reps'
  final int dosisValor;
}

enum _Fase { cuentaInicial, ejecucion, descanso, cierre }

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

/// Métricas ya calculadas para mostrar en la pantalla de cierre.
class _MetricasCierre {
  const _MetricasCierre({
    required this.duracion,
    required this.repsTotales,
    required this.porcentajeValidas,
    required this.comparacion,
    required this.racha,
  });

  final Duration duracion;
  final int repsTotales;
  final int? porcentajeValidas;
  final String comparacion;
  final int racha;
}

class _EjecucionRutinaScreenState extends State<EjecucionRutinaScreen> {
  CameraController? _controller;
  PoseDetector? _poseDetector;
  InputImageRotation _imageRotation = InputImageRotation.rotation0deg;
  bool _isDetecting = false;
  List<Pose> _poses = [];
  bool _showDebugPanel = false;

  int _pasoActual = 0;
  _Fase _fase = _Fase.cuentaInicial;
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

  _MetricasCierre? _metricas;
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
      _fase = _Fase.ejecucion;
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
        _fase = _Fase.cierre;
        _canPop = true;
      });
      _finalizarSesion();
    } else {
      setState(() => _fase = _Fase.descanso);
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
        _metricas = _MetricasCierre(
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
      _fase = _Fase.ejecucion;
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

    if (_fase == _Fase.cierre) {
      content = _PantallaCierre(
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
          _fase == _Fase.descanso ? _pasoActual + 1 : _pasoActual;

      content = switch (_fase) {
        _Fase.cuentaInicial => _PantallaCuentaInicial(
            ejercicio: _ejercicioActual,
            onListo: _iniciarEjercicioActual,
          ),
        _Fase.ejecucion => _PantallaEjecucion(
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
        _Fase.descanso => _PantallaDescanso(
            key: ValueKey('descanso_$_pasoActual'),
            segundos: widget.descansoSeg,
            siguienteEjercicio: _siguienteEjercicio,
            onTerminar: _avanzarAlSiguientePaso,
            completados: completados,
            ejerciciosPorRonda: widget.ejercicios.length,
            rondas: widget.rondas,
          ),
        _Fase.cierre => const SizedBox.shrink(),
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

/// Recuadro de video del ejercicio: si hay media_url, reproduce ese
/// video en loop, automático y sin audio. Si no hay media_url, o si el
/// video falla al cargar (red, URL inválida, etc.), cae de vuelta al
/// placeholder con el ícono de play — nunca truena la pantalla por un
/// video que no carga.
class _VideoOPlaceholder extends StatefulWidget {
  const _VideoOPlaceholder({
    required this.mediaUrl,
    this.width = 220,
    this.height = 220,
    this.borderRadius = 16,
  });

  final String? mediaUrl;
  final double width;
  final double height;
  final double borderRadius;

  @override
  State<_VideoOPlaceholder> createState() => _VideoOPlaceholderState();
}

class _VideoOPlaceholderState extends State<_VideoOPlaceholder> {
  VideoPlayerController? _controller;
  bool _fallo = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void didUpdateWidget(covariant _VideoOPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl) {
      _controller?.dispose();
      _controller = null;
      _fallo = false;
      _inicializar();
    }
  }

  void _inicializar() {
    final url = widget.mediaUrl;
    if (url == null || url.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    controller.initialize().then((_) {
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller
        ..setLooping(true)
        ..setVolume(0)
        ..play();
      setState(() => _controller = controller);
    }).catchError((Object _) {
      if (!mounted) return;
      setState(() => _fallo = true);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final mostrarVideo =
        !_fallo && controller != null && controller.value.isInitialized;

    return Container(
      width: widget.width,
      height: widget.height,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: Colors.white24),
      ),
      child: mostrarVideo
          ? FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          : const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white38,
                size: 56,
              ),
            ),
    );
  }
}

/// Texto que se autoajusta al mayor tamaño posible sin desbordar, hasta
/// [maxLines] líneas: para leerse a 1-2 metros de distancia, el nombre
/// del ejercicio y las reps/tiempo deben verse lo más grandes que
/// quepan, encogiéndose solo lo justo cuando el texto es largo. Mide
/// con TextPainter en vez de depender de un paquete externo.
class _TextoAutoAjustable extends StatelessWidget {
  const _TextoAutoAjustable({
    required this.texto,
    required this.maxFontSize,
    required this.style,
    this.minFontSize = 14,
    this.maxLines = 2,
    this.textAlign = TextAlign.center,
  });

  final String texto;
  final double maxFontSize;
  final double minFontSize;
  final int maxLines;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var fontSize = maxFontSize;
        while (fontSize > minFontSize) {
          final painter = TextPainter(
            text: TextSpan(
              text: texto,
              style: style.copyWith(fontSize: fontSize),
            ),
            maxLines: maxLines,
            textDirection: TextDirection.ltr,
            textAlign: textAlign,
          )..layout(maxWidth: constraints.maxWidth);
          if (!painter.didExceedMaxLines) break;
          fontSize -= 2;
        }
        return Text(
          texto,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(fontSize: fontSize),
        );
      },
    );
  }
}

/// Círculo con un número/contador grande adentro: usado para el
/// cronómetro de descanso y el contador de la pantalla de ejecución.
/// Mismo negro semitransparente que el recuadro del nombre del
/// ejercicio, para que ambos compartan el mismo tratamiento visual.
class _CirculoNumero extends StatelessWidget {
  const _CirculoNumero({
    required this.texto,
    this.diametro,
    this.progreso,
    this.sufijo,
    this.grosorAnillo = 4,
    this.numeroFontSize,
    this.sufijoFontSize,
  });

  final String texto;

  /// Si no se da, ocupa casi todo el ancho de la pantalla (margen
  /// chico a los lados, sin tocarlos): es el caso del contador
  /// principal de un ejercicio, donde el número es lo más importante
  /// para leer a distancia. Se puede pasar un valor chico cuando el
  /// cronómetro es secundario en esa pantalla (p. ej. el descanso,
  /// donde lo protagonista es el siguiente ejercicio).
  final double? diametro;

  /// 0.0-1.0: si se da, dibuja un anillo de progreso verde alrededor
  /// (se va vaciando conforme baja), sincronizado con la cuenta.
  final double? progreso;

  /// Texto chico opcional debajo del número (p. ej. "SEG").
  final String? sufijo;

  final double grosorAnillo;

  /// Tamaño de fuente FIJO (sp) para el número. Si no se da, el número
  /// llena lo más posible el espacio disponible (caso del contador
  /// grande de ejecución). Pasar un valor fijo aquí es lo que evita
  /// que, al calcularlo como proporción del diámetro, el número
  /// termine casi tocando el anillo.
  final double? numeroFontSize;
  final double? sufijoFontSize;

  @override
  Widget build(BuildContext context) {
    final diametro = this.diametro ?? MediaQuery.of(context).size.width - 32;
    return SizedBox(
      width: diametro,
      height: diametro,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // El fondo negro sólido solo aparece cuando NO hay anillo de
          // progreso (contador de ejecución, sobre la cámara): cuando
          // sí hay anillo (descanso), se deja el centro limpio para
          // que el video se siga viendo a través de él.
          if (progreso == null)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          if (progreso != null)
            Padding(
              padding: const EdgeInsets.all(2),
              child: CircularProgressIndicator(
                value: progreso!.clamp(0.0, 1.0),
                strokeWidth: grosorAnillo,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(AppColors.brandBright),
              ),
            ),
          if (numeroFontSize == null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _numeroYSufijo(fontSize: 200, sufijoFontSize: 40),
              ),
            )
          else
            // Tamaños fijos en sp (no una fracción del diámetro): con
            // el círculo bastante más grande que el bloque número+SEG,
            // queda centrado y holgado sin tocar el anillo.
            _numeroYSufijo(
              fontSize: numeroFontSize!,
              sufijoFontSize: sufijoFontSize ?? 13,
            ),
        ],
      ),
    );
  }

  Widget _numeroYSufijo(
      {required double fontSize, required double sufijoFontSize}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          texto,
          style: TextStyle(
            color: sufijo == null ? Colors.white : AppColors.brandBright,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        if (sufijo != null)
          Text(
            sufijo!,
            style: TextStyle(
              color: Colors.white54,
              fontSize: sufijoFontSize,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
      ],
    );
  }
}

/// Botón circular grande usado en el flujo de ejecución ("Listo",
/// "Empezar"): extremos totalmente redondeados (píldora), con texto.
class _BotonPildora extends StatelessWidget {
  const _BotonPildora({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// Cuenta regresiva de 4s mostrada UNA sola vez, antes del primer
/// ejercicio de toda la rutina. Entre ejercicios no vuelve a aparecer:
/// de descanso se pasa directo a ejecución.
class _PantallaCuentaInicial extends StatefulWidget {
  const _PantallaCuentaInicial({
    required this.ejercicio,
    required this.onListo,
  });

  final EjercicioSesion ejercicio;
  final VoidCallback onListo;

  @override
  State<_PantallaCuentaInicial> createState() => _PantallaCuentaInicialState();
}

class _PantallaCuentaInicialState extends State<_PantallaCuentaInicial> {
  static const _segundosEspera = 4;
  int _cuentaRegresiva = _segundosEspera;
  Timer? _timer;
  final _beeper = _Beeper();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _cuentaRegresiva--);
      if (_cuentaRegresiva <= 0) {
        _timer?.cancel();
        _beeper.doble();
        widget.onListo();
      } else if (_cuentaRegresiva <= 3) {
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
    final ejercicio = widget.ejercicio;
    final dosisTexto = ejercicio.dosisTipo == 'tiempo'
        ? '${ejercicio.dosisValor} segundos'
        : '${ejercicio.dosisValor} repeticiones';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: _TextoAutoAjustable(
                texto: ejercicio.nombre,
                maxFontSize: 44,
                minFontSize: 24,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // El video llena lo que sobra entre el nombre y los
            // controles de abajo: así nunca desborda la pantalla, sin
            // importar cuánto midan el nombre o el texto de dosis.
            Expanded(
              child: _VideoOPlaceholder(
                mediaUrl: ejercicio.mediaUrl,
                width: double.infinity,
                height: double.infinity,
                borderRadius: 0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TextoAutoAjustable(
                    texto: dosisTexto,
                    maxFontSize: 30,
                    minFontSize: 18,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.brandBright,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_cuentaRegresiva > 0)
                    Text(
                      '$_cuentaRegresiva',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 16),
                  _BotonPildora(
                    label: 'LISTO',
                    onPressed: () {
                      _timer?.cancel();
                      widget.onListo();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla 2 del ciclo: ejecución con cámara en vivo.
class _PantallaEjecucion extends StatefulWidget {
  const _PantallaEjecucion({
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
  State<_PantallaEjecucion> createState() => _PantallaEjecucionState();
}

class _PantallaEjecucionState extends State<_PantallaEjecucion> {
  Timer? _timer;
  int _segundosRestantes = 0;
  int _repsManual = 0;
  bool _terminadoDisparado = false;
  final _beeper = _Beeper();

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
              child: _TextoAutoAjustable(
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
              child: _CirculoNumero(texto: indicadorPrincipal),
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
            child: _BarraProgresoRutina(
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

/// Pantalla 3 del ciclo: descanso entre ejercicios.
class _PantallaDescanso extends StatefulWidget {
  const _PantallaDescanso({
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
  State<_PantallaDescanso> createState() => _PantallaDescansoState();
}

class _PantallaDescansoState extends State<_PantallaDescanso> {
  late int _segundosRestantes = widget.segundos;
  Timer? _timer;
  final _beeper = _Beeper();

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
    final totalPasos = widget.ejerciciosPorRonda * widget.rondas;
    final rondaActual = (widget.completados ~/ widget.ejerciciosPorRonda) + 1;
    final posicionActual = widget.completados + 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // El video del siguiente ejercicio de fondo, a pantalla
          // completa: es el protagonista de esta pantalla.
          _VideoOPlaceholder(
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
                    Colors.black.withValues(alpha: 0.7),
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
                  child: _BarraProgresoRutina(
                    completados: widget.completados,
                    ejerciciosPorRonda: widget.ejerciciosPorRonda,
                    rondas: widget.rondas,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'RONDA $rondaActual · $posicionActual/$totalPasos',
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
                        _TextoAutoAjustable(
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
                              child: _TextoAutoAjustable(
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
                    final anchoBoton = anchoPantalla * 0.62;
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: margenLateral),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _CirculoNumero(
                            texto: '$_segundosRestantes',
                            diametro: 90,
                            progreso: _segundosRestantes / widget.segundos,
                            sufijo: 'SEG',
                            grosorAnillo: 5,
                            numeroFontSize: 40,
                            sufijoFontSize: 13,
                          ),
                          const SizedBox(width: 8),
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
                                  Icon(
                                    Icons.keyboard_double_arrow_right,
                                    size: 20,
                                  ),
                                  SizedBox(width: 6),
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
                const SizedBox(height: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de progreso de toda la rutina: un segmento por ejercicio,
/// agrupado por ronda con una pequeña separación entre grupos. Solo
/// visual, sin números ni texto — lleno (verde) = ya completado,
/// vacío (gris) = pendiente.
class _BarraProgresoRutina extends StatelessWidget {
  const _BarraProgresoRutina({
    required this.completados,
    required this.ejerciciosPorRonda,
    required this.rondas,
  });

  final int completados;
  final int ejerciciosPorRonda;
  final int rondas;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var r = 0; r < rondas; r++) ...[
          if (r > 0) const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                for (var e = 0; e < ejerciciosPorRonda; e++) ...[
                  if (e > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: (r * ejerciciosPorRonda + e) < completados
                            ? AppColors.brandBright
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Pantalla de cierre (Parte 3C): guarda la sesión en Supabase y
/// muestra las 4 métricas mientras ese guardado corre en segundo plano.
class _PantallaCierre extends StatelessWidget {
  const _PantallaCierre({
    required this.metricas,
    required this.error,
    required this.onReintentar,
    required this.onListo,
  });

  final _MetricasCierre? metricas;
  final String? error;
  final VoidCallback onReintentar;
  final VoidCallback onListo;

  String _formatDuracion(Duration d) {
    final minutos = d.inMinutes;
    final segundos = d.inSeconds % 60;
    return minutos > 0 ? '$minutos min $segundos s' : '$segundos s';
  }

  @override
  Widget build(BuildContext context) {
    final err = error;
    if (err != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  err,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onReintentar,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final m = metricas;
    if (m == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.brandBright),
              SizedBox(height: 20),
              Text(
                'Guardando tu sesión...',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Rutina completada',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuracion(m.duracion),
                  style: const TextStyle(color: Colors.white70, fontSize: 20),
                ),
                const SizedBox(height: 28),
                Text(
                  m.porcentajeValidas != null
                      ? '${m.repsTotales} reps totales · ${m.porcentajeValidas}% válidas'
                      : '${m.repsTotales} reps totales',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  m.comparacion,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.brandBright,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '🔥 ${m.racha} ${m.racha == 1 ? 'día seguido' : 'días seguidos'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: onListo,
                    child: const Text('Listo'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
