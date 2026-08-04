/// Texto que se autoajusta al mayor tamaño posible sin desbordar, hasta
/// [maxLines] líneas: para leerse a 1-2 metros de distancia, el nombre
/// del ejercicio y las reps/tiempo deben verse lo más grandes que
/// quepan, encogiéndose solo lo justo cuando el texto es largo. Mide
/// con TextPainter en vez de depender de un paquete externo.
library;

import 'package:flutter/material.dart';

class TextoAutoAjustable extends StatelessWidget {
  const TextoAutoAjustable({
    super.key,
    required this.texto,
    required this.maxFontSize,
    required this.style,
    this.minFontSize = 14,
    this.maxLines = 2,
    this.textAlign = TextAlign.center,
  });

  final String texto;
  final double maxFontSize;
  final double minFontSize;
  final int maxLines;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var fontSize = maxFontSize;
        while (fontSize > minFontSize) {
          final painter = TextPainter(
            text: TextSpan(
              text: texto,
              style: style.copyWith(fontSize: fontSize),
            ),
            maxLines: maxLines,
            textDirection: TextDirection.ltr,
            textAlign: textAlign,
          )..layout(maxWidth: constraints.maxWidth);
          if (!painter.didExceedMaxLines) break;
          fontSize -= 2;
        }
        return Text(
          texto,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(fontSize: fontSize),
        );
      },
    );
  }
}
