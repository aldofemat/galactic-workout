/// Recuadro de video del ejercicio: si hay media_url, reproduce ese
/// video en loop, automático y sin audio. Si no hay media_url, o si el
/// video falla al cargar (red, URL inválida, etc.), cae de vuelta al
/// placeholder con el ícono de play — nunca truena la pantalla por un
/// video que no carga.
library;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoOPlaceholder extends StatefulWidget {
  const VideoOPlaceholder({
    super.key,
    required this.mediaUrl,
    this.width = 220,
    this.height = 220,
    this.borderRadius = 16,
  });

  final String? mediaUrl;
  final double width;
  final double height;
  final double borderRadius;

  @override
  State<VideoOPlaceholder> createState() => VideoOPlaceholderState();
}

class VideoOPlaceholderState extends State<VideoOPlaceholder> {
  VideoPlayerController? _controller;
  bool _fallo = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void didUpdateWidget(covariant VideoOPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl) {
      _controller?.dispose();
      _controller = null;
      _fallo = false;
      _inicializar();
    }
  }

  void _inicializar() {
    final url = widget.mediaUrl;
    if (url == null || url.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    controller.initialize().then((_) {
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller
        ..setLooping(true)
        ..setVolume(0)
        ..play();
      setState(() => _controller = controller);
    }).catchError((Object _) {
      if (!mounted) return;
      setState(() => _fallo = true);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final mostrarVideo =
        !_fallo && controller != null && controller.value.isInitialized;

    return Container(
      width: widget.width,
      height: widget.height,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: Colors.white24),
      ),
      child: mostrarVideo
          ? FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          : const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white38,
                size: 56,
              ),
            ),
    );
  }
}
