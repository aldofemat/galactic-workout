import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'main.dart';
import 'motor/rutina_debug_screen.dart';
import 'pose_painter.dart';
import 'session_history_screen.dart';
import 'squat_counter.dart';

class CameraPoseScreen extends StatefulWidget {
  const CameraPoseScreen({super.key});

  @override
  State<CameraPoseScreen> createState() => _CameraPoseScreenState();
}

class _CameraPoseScreenState extends State<CameraPoseScreen> {
  CameraController? _controller;
  PoseDetector? _poseDetector;
  final SquatCounter _squatCounter = SquatCounter();

  bool _isDetecting = false;
  List<Pose> _poses = [];
  double? _currentAngle;
  InputImageRotation _imageRotation = InputImageRotation.rotation0deg;
  bool _showDebugPanel = false;
  bool _isSaving = false;

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
    // Usa la cámara frontal si existe (para verte a ti mismo entrenando).
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          ImageFormatGroup.nv21, // requerido por ML Kit en Android
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
    if (_isDetecting) return; // evita procesar frames en paralelo
    _isDetecting = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isNotEmpty) {
        final angle = _squatCounter.processPose(poses.first);
        if (mounted) {
          setState(() {
            _poses = poses;
            _currentAngle = angle;
          });
        }
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

  /// Guarda la sesión actual (ejercicio "sentadilla", reps totales, fecha)
  /// en workout_sessions y reinicia el contador para la siguiente sesión.
  Future<void> _saveSession() async {
    setState(() => _isSaving = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('workout_sessions').insert({
        'user_id': userId,
        'ejercicio': 'sentadilla',
        'reps_totales': _squatCounter.reps,
        'fecha': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Sesión guardada: ${_squatCounter.reps} reps de sentadilla'),
        ),
      );
      setState(() => _squatCounter.reset());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la sesión: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Cierra sesión. AuthGate escucha onAuthStateChange y regresa solo a
  /// la pantalla de login, no hace falta navegar manualmente.
  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cerrar sesión: $e')),
      );
    }
  }

  Widget _cornerIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          CustomPaint(
            painter: PosePainter(
              _poses,
              Size(
                _controller!.value.previewSize!.height,
                _controller!.value.previewSize!.width,
              ),
              InputImageRotation.rotation0deg,
            ),
          ),
          // Capa transparente para capturar el tap que muestra/oculta el
          // panel de diagnóstico. Va encima del CustomPaint (que si no,
          // interceptaba el tap) pero debajo del panel de info y del
          // botón de reiniciar, para que esos sigan funcionando normal.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _showDebugPanel = !_showDebugPanel),
            ),
          ),
          // ⚠️ BOTÓN TEMPORAL DE DEBUG — motor de rutinas (Fase 4).
          // A propósito feo y a todo lo ancho para que sea imposible no
          // verlo; quitar cuando el motor esté validado.
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.deepOrange,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RutinaDebugScreen()),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    '🔧 DEBUG: GENERAR RUTINA 🔧',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Íconos discretos: historial y cerrar sesión.
          Positioned(
            top: MediaQuery.of(context).padding.top + 48,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _cornerIconButton(
                  icon: Icons.history,
                  tooltip: 'Historial de entrenamientos',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SessionHistoryScreen(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _cornerIconButton(
                  icon: Icons.logout,
                  tooltip: 'Cerrar sesión',
                  onPressed: _signOut,
                ),
              ],
            ),
          ),
          // Panel de info: reps, ángulo, etapa. Texto grande a propósito
          // para poder leerlo a 2-3 metros de distancia del celular.
          // top: 150 deja espacio libre para el banner de debug + íconos.
          Positioned(
            top: 150,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${_squatCounter.reps}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 96,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'REPS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Etapa: ${_squatCounter.stage}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_showDebugPanel)
                    Text(
                      'Ángulo rodilla: ${_currentAngle?.toStringAsFixed(1) ?? '--'}°',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Panel de diagnóstico: valores en vivo de cada condición que
          // evalúa la validación anti-falsos-positivos. Oculto por
          // defecto; un tap en cualquier parte del preview lo muestra u
          // oculta (ver GestureDetector sobre CameraPreview arriba).
          if (_showDebugPanel)
            Positioned(
              bottom: 190,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rodilla der: ${_fmtDeg(_squatCounter.debugRightKneeAngle)} '
                      '(conf ${_fmtPct(_squatCounter.debugRightLegConfidence)})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Rodilla izq: ${_fmtDeg(_squatCounter.debugLeftKneeAngle)} '
                      '(conf ${_fmtPct(_squatCounter.debugLeftLegConfidence)})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Cadera bajó: ${_fmtPct(_squatCounter.debugHipDropRatio)} '
                      '(requiere ${_fmtPct(_squatCounter.debugHipDropRequired)})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _squatCounter.debugFailureReason ??
                          'OK: condiciones cumplidas',
                      style: TextStyle(
                        color: _squatCounter.debugFailureReason == null
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSession,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Terminar sesión de entrenamiento'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => setState(() => _squatCounter.reset()),
                  child: const Text('Reiniciar contador'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDeg(double? value) =>
      value == null ? '--' : '${value.toStringAsFixed(0)}°';

  String _fmtPct(double? value) =>
      value == null ? '--' : '${(value * 100).toStringAsFixed(0)}%';
}
