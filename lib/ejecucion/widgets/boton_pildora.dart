/// Botón circular grande usado en el flujo de ejecución ("Listo",
/// "Empezar"): extremos totalmente redondeados (píldora), con texto.
library;

import 'package:flutter/material.dart';

class BotonPildora extends StatelessWidget {
  const BotonPildora({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
