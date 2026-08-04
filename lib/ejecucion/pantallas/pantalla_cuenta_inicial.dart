/// Cuenta regresiva de 4s mostrada UNA sola vez, antes del primer
/// ejercicio de toda la rutina. Entre ejercicios no vuelve a aparecer:
/// de descanso se pasa directo a ejecución.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme.dart';
import '../beeper.dart';
import '../modelos_ejecucion.dart';
import '../widgets/boton_pildora.dart';
import '../widgets/texto_auto_ajustable.dart';
import '../widgets/video_placeholder.dart';

class PantallaCuentaInicial extends StatefulWidget {
  const PantallaCuentaInicial({
    super.key,
    required this.ejercicio,
    required this.onListo,
  });

  final EjercicioSesion ejercicio;
  final VoidCallback onListo;

  @override
  State<PantallaCuentaInicial> createState() => PantallaCuentaInicialState();
}

class PantallaCuentaInicialState extends State<PantallaCuentaInicial> {
  static const _segundosEspera = 4;
  int _cuentaRegresiva = _segundosEspera;
  Timer? _timer;
  final _beeper = Beeper();

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
              child: TextoAutoAjustable(
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
              child: VideoOPlaceholder(
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
                  TextoAutoAjustable(
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
                  BotonPildora(
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
