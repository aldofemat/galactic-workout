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
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

class Beeper {
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
