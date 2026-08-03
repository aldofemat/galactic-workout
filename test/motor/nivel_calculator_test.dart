import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/motor/nivel_calculator.dart';

void main() {
  group('calcularNivel — casos del mensaje del usuario', () {
    test('0/0/0 (no puede ninguno) => nivel 0', () {
      final r = calcularNivel(
        sentadillasPuede: false,
        sentadillasReps: null,
        lagartijasPuede: false,
        lagartijasReps: null,
        dominadasPuede: false,
        dominadasReps: null,
        correTiempo: null,
        paradaManos: null,
        paradaManosTiempo: null,
      );
      expect(r.nivel, 0);
    });

    test('15 sent / 12 lag / 0 dom => nivel 1 (dominadas es el mínimo)', () {
      final r = calcularNivel(
        sentadillasPuede: true,
        sentadillasReps: 15,
        lagartijasPuede: true,
        lagartijasReps: 12,
        dominadasPuede: false,
        dominadasReps: null,
        correTiempo: null,
        paradaManos: null,
        paradaManosTiempo: null,
      );
      expect(r.nivelSentadillas, 2);
      expect(r.nivelLagartijas, 2);
      expect(r.nivelDominadas, 1);
      expect(r.nivel, 1);
    });

    test('25/25/12 => nivel 3', () {
      final r = calcularNivel(
        sentadillasPuede: true,
        sentadillasReps: 25,
        lagartijasPuede: true,
        lagartijasReps: 25,
        dominadasPuede: true,
        dominadasReps: 12,
        correTiempo: null,
        paradaManos: null,
        paradaManosTiempo: null,
      );
      expect(r.nivel, 3);
    });

    test('50 sent / 5 lag / 0 dom => nivel 1 (lagartijas es el mínimo)', () {
      final r = calcularNivel(
        sentadillasPuede: true,
        sentadillasReps: 50,
        lagartijasPuede: true,
        lagartijasReps: 5,
        dominadasPuede: false,
        dominadasReps: null,
        correTiempo: null,
        paradaManos: null,
        paradaManosTiempo: null,
      );
      expect(r.nivelSentadillas, 4);
      expect(r.nivelLagartijas, 1);
      expect(r.nivelDominadas, 1);
      expect(r.nivel, 1);
    });
  });

  group('calcularNivel — requisitos extra de Élite (nivel 4)', () {
    test('35/31/22 + corre mas_40 + parada 1_3min => nivel 4', () {
      final r = calcularNivel(
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
      expect(r.nivelSentadillas, 4);
      expect(r.nivelLagartijas, 4);
      expect(r.nivelDominadas, 4);
      expect(r.cumpleRequisitosElite, true);
      expect(r.nivel, 4);
    });

    test(
      '35/31/22 + corre 20_40 + parada 1_3min => nivel 3 (falta cardio)',
      () {
        final r = calcularNivel(
          sentadillasPuede: true,
          sentadillasReps: 35,
          lagartijasPuede: true,
          lagartijasReps: 31,
          dominadasPuede: true,
          dominadasReps: 22,
          correTiempo: '20_40',
          paradaManos: true,
          paradaManosTiempo: '1_3min',
        );
        expect(r.cumpleRequisitosElite, false);
        expect(r.nivel, 3);
      },
    );

    test(
      '35/31/22 + corre mas_40 + parada_manos false => nivel 3 (falta habilidad)',
      () {
        final r = calcularNivel(
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
        expect(r.cumpleRequisitosElite, false);
        expect(r.nivel, 3);
      },
    );

    test(
      '35/31/22 + corre mas_40 + parada menos_1min => nivel 3 (tiempo insuficiente)',
      () {
        final r = calcularNivel(
          sentadillasPuede: true,
          sentadillasReps: 35,
          lagartijasPuede: true,
          lagartijasReps: 31,
          dominadasPuede: true,
          dominadasReps: 22,
          correTiempo: 'mas_40',
          paradaManos: true,
          paradaManosTiempo: 'menos_1min',
        );
        expect(r.cumpleRequisitosElite, false);
        expect(r.nivel, 3);
      },
    );

    test('el requisito de Élite no aplica si el mínimo de fuerza no es 4', () {
      final r = calcularNivel(
        sentadillasPuede: true,
        sentadillasReps: 25,
        lagartijasPuede: true,
        lagartijasReps: 25,
        dominadasPuede: true,
        dominadasReps: 12,
        correTiempo: null,
        paradaManos: null,
        paradaManosTiempo: null,
      );
      expect(r.cumpleRequisitosElite, null);
      expect(r.nivel, 3);
    });
  });

  group('calcularNivel — casos extra de cobertura', () {
    test('reps=0 con puede=true equivale a puede=false', () {
      final r = calcularNivel(
        sentadillasPuede: true,
        sentadillasReps: 0,
        lagartijasPuede: true,
        lagartijasReps: 0,
        dominadasPuede: true,
        dominadasReps: 0,
        correTiempo: null,
        paradaManos: null,
        paradaManosTiempo: null,
      );
      expect(r.nivel, 0); // excepción: dominadas también cae a 0
    });

    test(
      'dominadas 0 pero sentadillas/lagartijas no ambas en 0 => dominadas nivel 1',
      () {
        final r = calcularNivel(
          sentadillasPuede: true,
          sentadillasReps: 3,
          lagartijasPuede: false,
          lagartijasReps: null,
          dominadasPuede: false,
          dominadasReps: null,
          correTiempo: null,
          paradaManos: null,
          paradaManosTiempo: null,
        );
        expect(r.nivelDominadas, 1);
        expect(r.nivel, 0); // el mínimo sigue siendo lagartijas en 0
      },
    );

    test('límites exactos de las tablas (9/10, 19/20, 29/30)', () {
      final a = calcularNivel(
        sentadillasPuede: true,
        sentadillasReps: 9,
        lagartijasPuede: true,
        lagartijasReps: 10,
        dominadasPuede: true,
        dominadasReps: 20,
        correTiempo: null,
        paradaManos: null,
        paradaManosTiempo: null,
      );
      expect(a.nivelSentadillas, 1);
      expect(a.nivelLagartijas, 2);
    });
  });
}
