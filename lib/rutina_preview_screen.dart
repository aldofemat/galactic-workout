/// Vista previa de la rutina de un día del camino: se abre al tocar el
/// nodo ACTUAL. Muestra duración/equipo/rondas y la lista de
/// ejercicios (placeholder + nombre + dosis), con el botón EMPEZAR
/// flotante sobre el contenido en vez de fijo dentro del scroll.
library;

import 'package:flutter/material.dart';
import 'ejecucion/ejecucion_rutina_screen.dart';
import 'ejecucion/modelos_ejecucion.dart';
import 'main.dart';
import 'theme.dart';

/// Ejercicios unilaterales llegan como 2 filas (lado izquierdo/derecho)
/// con el mismo ejercicio_id: el nombre a mostrar/ejecutar es el del
/// catálogo más el sufijo del lado, para distinguirlos en la lista y
/// durante la ejecución.
String _nombreConLado(String nombre, String? lado) {
  if (lado == null) return nombre;
  return '$nombre (lado $lado)';
}

class _EjercicioPreview {
  const _EjercicioPreview({
    required this.ejercicioId,
    required this.nombre,
    required this.mediaUrl,
    required this.dosisTipo,
    required this.dosisValor,
    required this.equipo,
  });

  final String ejercicioId;
  final String nombre;
  final String? mediaUrl;
  final String dosisTipo;
  final int dosisValor;
  final String equipo;
}

class _DiaPreview {
  const _DiaPreview({
    required this.diaId,
    required this.tipoDia,
    required this.duracionMin,
    required this.rondas,
    required this.descansoSeg,
    required this.ejercicios,
  });

  final String diaId;
  final String tipoDia;
  final int duracionMin;
  final int rondas;
  final int descansoSeg;
  final List<_EjercicioPreview> ejercicios;

  /// Resumen compacto del equipo que se va a usar ("Peso corporal", o
  /// los slugs de equipo distintos de peso_corporal, legibles).
  String get resumenEquipo {
    final slugs = ejercicios.map((e) => e.equipo).toSet()
      ..remove('peso_corporal');
    if (slugs.isEmpty) return 'Peso corporal';
    return slugs.map(_prettificarSlug).join(', ');
  }

  static String _prettificarSlug(String slug) {
    return slug
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class RutinaPreviewScreen extends StatefulWidget {
  const RutinaPreviewScreen({super.key, required this.diaId});

  final String diaId;

  @override
  State<RutinaPreviewScreen> createState() => _RutinaPreviewScreenState();
}

class _RutinaPreviewScreenState extends State<RutinaPreviewScreen> {
  late Future<_DiaPreview> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarPreview();
  }

  Future<_DiaPreview> _cargarPreview() async {
    final dia = await supabase
        .from('rutina_dias')
        .select()
        .eq('id', widget.diaId)
        .single();
    final semana = await supabase
        .from('rutinas_semana')
        .select()
        .eq('id', dia['semana_id'] as String)
        .single();
    final cfg = await supabase
        .from('nivel_config')
        .select()
        .eq('nivel', semana['nivel_usuario'] as int)
        .single();

    final ejerciciosData = await supabase
        .from('rutina_dia_ejercicios')
        .select(
          'orden, bloque, dosis_tipo, dosis_valor, lado, ejercicio_id, '
          'ejercicios(nombre, media_url, equipo)',
        )
        .eq('dia_id', widget.diaId)
        .order('orden', ascending: true);

    final ejercicios = (ejerciciosData as List).map((ej) {
      final ejercicioEmbebido = ej['ejercicios'] as Map<String, dynamic>;
      return _EjercicioPreview(
        ejercicioId: ej['ejercicio_id'] as String,
        nombre: _nombreConLado(
          ejercicioEmbebido['nombre'] as String,
          ej['lado'] as String?,
        ),
        mediaUrl: ejercicioEmbebido['media_url'] as String?,
        dosisTipo: ej['dosis_tipo'] as String,
        dosisValor: ej['dosis_valor'] as int,
        equipo: ejercicioEmbebido['equipo'] as String,
      );
    }).toList();

    return _DiaPreview(
      diaId: widget.diaId,
      tipoDia: dia['tipo_dia'] as String,
      duracionMin: cfg['duracion_min'] as int,
      rondas: cfg['rondas'] as int,
      descansoSeg: cfg['descanso_seg'] as int,
      ejercicios: ejercicios,
    );
  }

  Future<void> _empezar(_DiaPreview dia) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EjecucionRutinaScreen(
          ejercicios: dia.ejercicios
              .map(
                (e) => EjercicioSesion(
                  ejercicioId: e.ejercicioId,
                  nombre: e.nombre,
                  mediaUrl: e.mediaUrl,
                  dosisTipo: e.dosisTipo,
                  dosisValor: e.dosisValor,
                ),
              )
              .toList(),
          rondas: dia.rondas,
          descansoSeg: dia.descansoSeg,
          tipoDia: dia.tipoDia,
          diaId: dia.diaId,
        ),
      ),
    );
    // Al volver (sesión completada o abandonada) se cierra también la
    // vista previa: el camino recarga y refleja el nuevo estado.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DiaPreview>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vista previa')),
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.brandBright),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vista previa')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar la vista previa:\n${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final dia = snapshot.data!;
        return Scaffold(
          appBar: AppBar(title: const Text('Vista previa')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: Colors.white54,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${dia.duracionMin} min',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(width: 14),
                  const Icon(
                    Icons.fitness_center,
                    color: Colors.white54,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      dia.resumenEquipo,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Icons.repeat, color: Colors.white54, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${dia.rondas} rondas',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              for (final ej in dia.ejercicios) ...[
                _EjercicioListTile(ejercicio: ej),
                const Divider(color: Colors.white12, height: 1),
              ],
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.brandBright,
            foregroundColor: Colors.black,
            shape: const StadiumBorder(),
            onPressed: () => _empezar(dia),
            icon: const Icon(Icons.play_arrow),
            label: const Text(
              'EMPEZAR',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}

/// Un renglón de la lista: placeholder cuadrado a la izquierda (donde
/// irá la imagen/video cuando haya media_url), nombre al centro, dosis
/// al extremo derecho.
class _EjercicioListTile extends StatelessWidget {
  const _EjercicioListTile({required this.ejercicio});

  final _EjercicioPreview ejercicio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _MediaPlaceholder(mediaUrl: ejercicio.mediaUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              ejercicio.nombre,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            ejercicio.dosisTipo == 'tiempo'
                ? '${ejercicio.dosisValor}s'
                : '${ejercicio.dosisValor} reps',
            style: const TextStyle(
              color: AppColors.brandBright,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder cuadrado donde va la imagen/video del ejercicio. Cuando
/// el catálogo tenga media_url, este es el punto a reemplazar por la
/// miniatura/thumbnail real.
class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.mediaUrl});

  final String? mediaUrl;

  @override
  Widget build(BuildContext context) {
    if (mediaUrl != null && mediaUrl!.isNotEmpty) {
      // TODO: mostrar la imagen/miniatura real de mediaUrl aquí.
    }
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.brandDark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.fitness_center, color: Colors.white38, size: 24),
    );
  }
}
