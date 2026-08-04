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
| Orientación | Landscape | El juego original es apaisado |
| Package | `com.aleperix.tumbleboyreborn` | Identidad de la app |

> Por qué no Godot 4: Godot 4.x exige **OpenGL ES 3.0** en Android. Las cajas
> genéricas RK3128 (Mali-400MP2) y RK3328 (Mali-450MP2) solo soportan **OpenGL ES
> 1.1/2.0**, así que un APK de Godot 4 ni siquiera inicia ahí. Godot 3.6 + renderer
> **GLES2** corre bien incluso con 1 GB de RAM.

## Configuración del proyecto (`export_presets.cfg`)

- Preset **Android** (Gradle build), package `com.aleperix.tumbleboyreborn`.
- Version code/name, min_sdk 21, target_sdk 30.
- Permisos: **no** requiere permisos especiales (sin internet/almacenamiento
  adicionales; la red la usa el juego para descargar packs).
- Keystore: `keystore.jks` + contraseñas en el preset (no subir al repo).

> Este repositorio no incluye `export_presets.cfg` (contiene rutas y credenciales
> locales). Créalo en el editor: `Proyecto > Exportar > Añadir… > Android`.

## Exportar

```
# headless (importa assets la primera vez)
godot3 --headless --path . --import

# build apk (requiere SDK/JDK configurados)
godot3 --headless --path . --export-debug "Android" build/tumbleboy-reborn-debug.apk
```

O abrir el editor, `Proyecto > Exportar > Android > Exportar proyecto`.

> ⚠️ **Los niveles `.txt` no se empaquetan solos.** Godot solo exporta por
> defecto los recursos importados; los `.txt` de `assets/tumbleboy/data/levels/`
> son archivos planos y se quedan fuera si no se añaden a la lista
> *Filters to export non-resource files/folders*. Sin ese filtro, el juego en
> Android arranca pero nunca pasa del menú (la lista de niveles queda vacía y
> `_start_playing()` salta directo a la pantalla de victoria). Cada preset del
> `export_presets.cfg` lleva `include_filter="*.txt"`.

## Release (APK firmado)

Para el APK de distribución usa el flag **`--export`** (usa el template
*release* por defecto). El preset `Android ARM64`/`ARM32`/`X86` genera un APK
por ABI con **Gradle build + firma con el keystore release**:

```
# release por ABI (requiere SDK/JDK/NDK y keystore configurados en el preset)
godot3 --headless --path . --export "Android ARM64" build/tumbleboy-reborn-ARM64.apk
godot3 --headless --path . --export "Android ARM32" build/tumbleboy-reborn-ARM32.apk
godot3 --headless --path . --export "Android X86"    build/tumbleboy-reborn-X86.apk

# verificar firma
apksigner verify --print-certs build/tumbleboy-reborn-ARM64.apk
```

> ⚠️ **`--export-release` NO existe en Godot 3.6.** Los únicos flags de export
> son `--export` (release), `--export-debug` (debug) y `--export-pack`. Un flag
> desconocido se ignora en silencio (`main.cpp`): en headless el juego arranca
> en bucle sin exportar nada y en modo editor simplemente abre el editor. Si el
> APK no se genera y no ves `export: begin`, revisa que el flag sea el correcto.

Los exports release pueden tardar varios minutos la primera vez (compilan el
proyecto Gradle); verás `export: begin: Exporting for Android steps: N` al
arrancar y `export: end` al terminar.

## Instalar en caja/TV

```
adb install build/tumbleboy-reborn-debug.apk
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

1. **Desktop Linux**: `godot3 --path .` — verificar menú, hubs, back/ESC.
2. **Smoke tests headless**: `godot3 --headless --path . res://scenes/SmokeTest.tscn`.
3. **Box Rockchip**: `adb install` + comprobar FPS estables en TumbleBoy
   (es exigente por la física y el tablero grande).

## Controles

| Acción | Teléfono | TV/control |
|--------|----------|------------|
| Mover | Joystick virtual / toque directo | D-pad / palanca izquierda |
| Confirmar | Botón táctil A / toque | Botón A / Select |
| Atrás | Botón táctil B / back del sistema | Botón B / Back del control |
