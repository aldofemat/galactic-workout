/// Pestaña "Novedades": placeholder. Aquí irán después blog, noticias,
/// tutoriales y productos.
library;

import 'package:flutter/material.dart';
import 'theme.dart';

class NovedadesScreen extends StatelessWidget {
  const NovedadesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: AppColors.brandBright,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'Novedades',
                  style: TextStyle(
                    color: AppColors.brandBright,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Próximamente: blog, noticias, tutoriales y productos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
