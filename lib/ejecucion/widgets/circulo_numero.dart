/// Círculo con un número/contador grande adentro: usado para el
/// cronómetro de descanso y el contador de la pantalla de ejecución.
library;

import 'package:flutter/material.dart';
import '../../theme.dart';

class CirculoNumero extends StatelessWidget {
  const CirculoNumero({
    super.key,
    required this.texto,
    this.diametro,
    this.progreso,
    this.sufijo,
    this.grosorAnillo = 4,
    this.numeroFontSize,
    this.sufijoFontSize,
  });

  final String texto;
  final double? diametro;
  final double? progreso;
  final String? sufijo;
  final double grosorAnillo;
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
          // Fondo negro sólido solo cuando NO hay anillo (contador de
          // ejecución sobre la cámara). Con anillo (descanso), centro limpio.
          if (progreso == null)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),

          // El anillo de progreso ocupa TODO el diámetro del círculo.
          if (progreso != null)
            SizedBox(
              width: diametro,
              height: diametro,
              child: CircularProgressIndicator(
                value: progreso!.clamp(0.0, 1.0),
                strokeWidth: grosorAnillo,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(AppColors.brandBright),
              ),
            ),

          // El número + SEG, centrados. Con tamaño fijo (numeroFontSize)
          // van tal cual; sin él, se escalan para llenar el espacio.
          if (numeroFontSize == null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _numeroYSufijo(fontSize: 200, sufijoFontSize: 40),
              ),
            )
          else
            _numeroYSufijo(
              fontSize: numeroFontSize!,
              sufijoFontSize: sufijoFontSize ?? 13,
            ),
        ],
      ),
    );
  }

  Widget _numeroYSufijo({
    required double fontSize,
    required double sufijoFontSize,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: sufijo == null ? Colors.white : AppColors.brandBright,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        if (sufijo != null) ...[
          const SizedBox(height: 2),
          Text(
            sufijo!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: sufijoFontSize,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
        ],
      ],
    );
  }
}
