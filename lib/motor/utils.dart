/// Redondea minutos al múltiplo de 5 más cercano.
/// Si está en empate (.5), siempre sube.
/// Ejemplo: 22.5 → 25, 20.6 → 20, 32.5 → 35
int redondearA5Minutos(double minutos) {
  return ((minutos + 2.5) / 5).floor() * 5;
}
