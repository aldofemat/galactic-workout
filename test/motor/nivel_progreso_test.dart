import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/motor/nivel_calculator.dart';
import 'package:workout_app/motor/nivel_progreso.dart';

void main() {
  test(
      'ejemplo del mensaje: "Para Avanzado te faltan: 5 lagartijas más, 3 dominadas más"',
      () {
    final nivel = calcularNivel(
      sentadillasPuede: true,
      sentadillasReps: 25, // nivel 3
      lagartijasPuede: true,
      lagartijasReps: 15, // nivel 2, faltan 5 para 20
      dominadasPuede: true,
      dominadasReps: 7, // nivel 2, faltan 3 para 10
      correTiempo: null,
      paradaManos: null,
      paradaManosTiempo: null,
    );

    final mensaje = calcularMensajeFaltante(
      nivel: nivel,
      sentadillasReps: 25,
      lagartijasReps: 15,
      dominadasReps: 7,
      correTiempo: null,
      paradaManos: null,
      paradaManosTiempo: null,
    );

    expect(
        mensaje, 'Para Avanzado te faltan: 5 lagartijas más, 3 dominadas más');
  });

  test('gate de Élite: faltan ambas condiciones extra', () {
    final nivel = calcularNivel(
      sentadillasPuede: true,
      sentadillasReps: 35,
      lagartijasPuede: true,
      lagartijasReps: 31,
      dominadasPuede: true,
      dominadasReps: 22,
      correTiempo: null,
      paradaManos: null,
      paradaManosTiempo: null,
    );
    expect(nivel.nivel, 3); // topado por el gate

    final mensaje = calcularMensajeFaltante(
      nivel: nivel,
      sentadillasReps: 35,
      lagartijasReps: 31,
      dominadasReps: 22,
      correTiempo: null,
      paradaManos: null,
      paradaManosTiempo: null,
    );

    expect(
      mensaje,
      'Tu fuerza ya es de Élite. Te falta: correr 40 min seguidos y pararte de manos 1 minuto. '
      'El cardio y el equilibrio también entrenan.',
    );
  });

  test('gate de Élite: solo falta pararse de manos', () {
    final nivel = calcularNivel(
      sentadillasPuede: true,
      sentadillasReps: 35,
      lagartijasPuede: true,
      lagartijasReps: 31,
      dominadasPuede: true,
      dominadasReps: 22,
      correTiempo: 'mas_40',
      paradaManos: false,
      paradaManosTiempo: null,
    );

    final mensaje = calcularMensajeFaltante(
      nivel: nivel,
      sentadillasReps: 35,
      lagartijasReps: 31,
      dominadasReps: 22,
      correTiempo: 'mas_40',
      paradaManos: false,
      paradaManosTiempo: null,
    );

    expect(
      mensaje,
      'Tu fuerza ya es de Élite. Te falta: pararte de manos 1 minuto. '
      'El cardio y el equilibrio también entrenan.',
    );
  });

  test('Élite completo: mensaje de felicitación', () {
    final nivel = calcularNivel(
      sentadillasPuede: true,
      sentadillasReps: 35,
      lagartijasPuede: true,
      lagartijasReps: 31,
      dominadasPuede: true,
      dominadasReps: 22,
      correTiempo: 'mas_40',
      paradaManos: true,
      paradaManosTiempo: '1_3min',
    );
    expect(nivel.nivel, 4);

    final mensaje = calcularMensajeFaltante(
      nivel: nivel,
      sentadillasReps: 35,
      lagartijasReps: 31,
      dominadasReps: 22,
      correTiempo: 'mas_40',
      paradaManos: true,
      paradaManosTiempo: '1_3min',
    );

    expect(
        mensaje, '¡Ya eres Élite en los 5 requisitos! Nivel máximo alcanzado.');
  });

  test('nivel 0: falta el eslabón más débil para llegar a Principiante', () {
    final nivel = calcularNivel(
      sentadillasPuede: false,
      sentadillasReps: null,
      lagartijasPuede: true,
      lagartijasReps: 5,
      dominadasPuede: false,
      dominadasReps: null,
      correTiempo: null,
      paradaManos: null,
      paradaManosTiempo: null,
    );
    expect(nivel.nivel, 0);

    final mensaje = calcularMensajeFaltante(
      nivel: nivel,
      sentadillasReps: 0,
      lagartijasReps: 5,
      dominadasReps: 0,
      correTiempo: null,
      paradaManos: null,
      paradaManosTiempo: null,
    );

    // Sentadillas nivel 0 < siguiente(1): faltan 1 - 0 = 1.
    expect(mensaje, 'Para Principiante te faltan: 1 sentadillas más');
  });
}
