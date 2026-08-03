/// Pestaña "Retos": placeholder. Aquí irán después retos personales y
/// retos con amigos.
library;

import 'package:flutter/material.dart';
import 'theme.dart';

class RetosScreen extends StatelessWidget {
  const RetosScreen({super.key});

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
                  Icons.emoji_events_outlined,
                  color: AppColors.brandBright,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'Retos',
                  style: TextStyle(
                    color: AppColors.brandBright,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Próximamente: retos personales y retos con amigos.',
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
