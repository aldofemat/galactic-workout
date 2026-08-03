import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/motor/calendario_semanal.dart';

void main() {
  group('diasPlanDesdeFrecuencia', () {
    test('0-3 días entrenados => plan de 3 días', () {
      for (final f in [0, 1, 2, 3]) {
        expect(diasPlanDesdeFrecuencia(f), 3, reason: 'frecuencia $f');
      }
    });

    test('4 => plan de 4 días', () {
      expect(diasPlanDesdeFrecuencia(4), 4);
    });

    test('5 => plan de 5 días', () {
      expect(diasPlanDesdeFrecuencia(5), 5);
    });

    test('6-7 => plan de 6 días', () {
      expect(diasPlanDesdeFrecuencia(6), 6);
      expect(diasPlanDesdeFrecuencia(7), 6);
    });
  });

  group('calendarioSemanal', () {
    test('3 días: F, C, M', () {
      expect(calendarioSemanal(3), [
        TipoDia.fuerza,
        TipoDia.cardio,
        TipoDia.movilidad,
      ]);
    });

    test('4 días: F, C, F, M', () {
      expect(calendarioSemanal(4), [
        TipoDia.fuerza,
        TipoDia.cardio,
        TipoDia.fuerza,
        TipoDia.movilidad,
      ]);
    });

    test('5 días: F, C, F, C, M', () {
      expect(calendarioSemanal(5), [
        TipoDia.fuerza,
        TipoDia.cardio,
        TipoDia.fuerza,
        TipoDia.cardio,
        TipoDia.movilidad,
      ]);
    });

    test('6 días: F, C, F, M, F, C', () {
      expect(calendarioSemanal(6), [
        TipoDia.fuerza,
        TipoDia.cardio,
        TipoDia.fuerza,
        TipoDia.movilidad,
        TipoDia.fuerza,
        TipoDia.cardio,
      ]);
    });

    test('valor fuera de 3-6 truena', () {
      expect(() => calendarioSemanal(2), throwsArgumentError);
      expect(() => calendarioSemanal(7), throwsArgumentError);
    });
  });
}
