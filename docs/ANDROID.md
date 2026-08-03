# Android — Build, export y despliegue

## Requisitos

- **Godot 3.6.x** con export templates de Android.
  - AUR: `paru -S godot3-bin godot3-export-templates` (necesita `sudo`).
  - Sin sudo: extraer `godot3-bin` y ejecutar el binario directo (ver abajo).
- **JDK 17** (por ejemplo `openjdk-17-jdk`).
- **Android SDK** con platform android-30/31 y build-tools recientes.
- **Android NDK** `r23c` (el soportado por Godot 3.6 para armar las librerías nativas).
- Un **keystore** propio para firmar.

## minSdk / objetivo

| Parámetro | Valor | Nota |
|-----------|-------|------|
| minSdk | **21** | Android 5.0; es el mínimo nativo de Godot 3.6 y cumple el requisito API 21 |
| targetSdk | 30–31 | Compatible con Play y TV |
| ABI | `arm64-v8a`, `armeabi-v7a`, `x86` | Cobertura máxima de cajas y teléfonos |
| Orientación | Landscape | Todos los juegos originales son apaisados |

> Por qué no Godot 4: Godot 4.x exige **OpenGL ES 3.0** en Android. Las cajas
> genéricas RK3128 (Mali-400MP2) y RK3328 (Mali-450MP2) solo soportan **OpenGL ES
> 1.1/2.0**, así que un APK de Godot 4 ni siquiera inicia ahí. Godot 3.6 + renderer
> **GLES2** corre bien incluso con 1 GB de RAM.

## Configuración del proyecto (`export_presets.cfg`)

- Preset **Android** (Gradle build), package `org.lostgames.xo`.
- Version code/name, min_sdk 21, target_sdk 30.
- Permisos: **no** requiere permisos especiales (sin internet/almacenamiento).
- Keystore: `keystore.jks` + contraseñas en el preset (no subir al repo).

## Exportar

```
# headless (importa assets la primera vez)
godot3 --headless --path . --import

# build apk (requiere SDK/JDK configurados)
godot3 --headless --path . --export-debug "Android" build/lost-games-xo-debug.apk
```

O abrir el editor, `Proyecto > Exportar > Android > Exportar proyecto`.

## Instalar en caja/TV

```
adb install build/lost-games-xo-debug.apk
```

En TV: la app aparece en la parrilla (es una Activity normal, no TV-only, así que
también aparece en teléfonos).

## Godot 3.6 sin sudo (alternativa)

```sh
# 1. paru construye el paquete sin instalar:
paru -S --build godot3-bin
# 2. extraer localmente:
mkdir -p ~/.local/opt/godot3-bin
tar --zstd -xf ~/.cache/paru/clone/godot3-bin/godot3-bin-3.6.2-1-x86_64.pkg.tar.zst -C ~/.local/opt/godot3-bin
# 3. ejecutar con config aislada:
XDG_CONFIG_HOME=~/.config/godot3-env \
  ~/.local/opt/godot3-bin/usr/lib/godot3-bin/Godot_v3.6.2-stable_x11.64 "$@"
```

## Pruebas

1. **Desktop Linux**: `godot3 --path .` — verificar menú, los 5 juegos, back/ESC.
2. **Smoke tests headless**: `godot3 --headless --path . --script tests/smoke.gd`.
3. **Box Rockchip**: `adb install` + comprobar FPS estables en TumbleBoy
   (el más exigente por la física y el tablero grande).

## Controles

| Acción | Teléfono | TV/control |
|--------|----------|------------|
| Mover | Joystick virtual / toque directo | D-pad / palanca izquierda |
| Confirmar | Botón táctil A / toque | Botón A / Select |
| Atrás | Botón táctil B / back del sistema | Botón B / Back del control |
| Cursor (Jump/HeadCat) | Virtual pointer (toque) | D-pad + Confirmar |
