# Workout App — Fase 1: Cámara + Pose Detection

Esta es la primera fase: validar que la detección de pose funciona bien en
tiempo real y que se pueden contar repeticiones de sentadilla por ángulo de
rodilla. Sin backend, sin login, sin Supabase todavía — solo lo esencial.

## Qué hace

- Muestra el feed de la cámara frontal en vivo.
- Detecta el esqueleto (keypoints) con ML Kit Pose Detection, on-device.
- Dibuja el esqueleto sobre el video.
- Calcula el ángulo cadera-rodilla-tobillo y cuenta repeticiones de sentadilla.

## Cómo instalar

```bash
flutter pub get
```

## Configuración necesaria (permisos de cámara)

### Android — `android/app/src/main/AndroidManifest.xml`

Agrega dentro de `<manifest>`, antes de `<application>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

Y asegúrate que `minSdkVersion` en `android/app/build.gradle` sea al menos 21:

```gradle
minSdkVersion 21
```

### iOS — `ios/Runner/Info.plist`

Agrega dentro del `<dict>` principal:

```xml
<key>NSCameraUsageDescription</key>
<string>Necesitamos la cámara para detectar tu postura durante el ejercicio.</string>
```

## Cómo correr

```bash
flutter run
```

Prueba en un dispositivo físico, no en el simulador/emulador — la cámara y
el rendimiento de ML Kit se comportan distinto (y a veces no funcionan) en
emuladores.

## Qué revisar en esta fase

1. **¿Detecta bien tu cuerpo?** Prueba con distinta luz y distancia a la cámara.
2. **¿El conteo de reps es preciso?** Haz 15-20 sentadillas reales y compara
   contra el conteo de la app.
3. **Ajusta los umbrales** en `lib/squat_counter.dart` (`downThreshold` /
   `upThreshold`) según lo que veas — cada persona/cámara puede necesitar
   valores distintos.
4. **Si el esqueleto se ve desalineado** respecto al video, el punto a
   calibrar es `_scalePoint()` en `lib/pose_painter.dart` (depende de la
   orientación y resolución de tu cámara específica).

## Estructura

```
lib/
  main.dart                 - entry point, inicializa cámaras
  camera_pose_screen.dart   - pantalla principal: cámara + stream de poses
  pose_painter.dart         - dibuja el esqueleto sobre el preview
  squat_counter.dart        - lógica de ángulos y conteo de repeticiones
```

## Siguiente paso (Fase 2)

Una vez que el conteo de reps te convenza, se agrega Supabase: Auth,
tabla de sesiones, y guardar cada entrenamiento (reps, fecha, ejercicio).
