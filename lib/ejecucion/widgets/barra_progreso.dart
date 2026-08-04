/// Barra de progreso de toda la rutina: un segmento por ejercicio,
/// agrupado por ronda con una pequeña separación entre grupos. Solo
/// visual, sin números ni texto — lleno (verde) = ya completado,
/// vacío (gris) = pendiente.
library;

import 'package:flutter/material.dart';
import '../../theme.dart';

class BarraProgresoRutina extends StatelessWidget {
  const BarraProgresoRutina({
    super.key,
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
