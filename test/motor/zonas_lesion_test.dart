import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/motor/zonas_lesion.dart';

void main() {
  test('mapea las 4 zonas de onboarding a sus tokens del catálogo', () {
    final tokens = zonasLesionCatalogo([
      'Rodillas',
      'Espalda baja',
      'Hombros',
      'Muñecas',
    ]);
    expect(tokens, {'rodilla', 'rodillas', 'espalda', 'hombro', 'muñecas'});
  });

  test('es insensible a mayúsculas/espacios', () {
    final tokens = zonasLesionCatalogo(['  rodillas  ', 'ESPALDA BAJA']);
    expect(tokens, {'rodilla', 'rodillas', 'espalda'});
  });

  test('"Otra" no tiene mapeo (es texto libre)', () {
    final tokens = zonasLesionCatalogo(['Otra']);
    expect(tokens, isEmpty);
  });

  test('lista vacía => conjunto vacío', () {
    expect(zonasLesionCatalogo(const []), isEmpty);
  });
}
