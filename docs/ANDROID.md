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

> El proceso puede terminar con `free(): invalid pointer`, líneas de
> `nvidia-drm`/`dri3` o `glx: failed to create dri3 screen`: son ruido del
> teardown de OpenGL de este equipo (sin contexto GLES3), inofensivos. Si el
> APK se generó en `build/` y `apksigner verify` pasa, el export fue correcto.
> `--headless` también funciona; sin él, el export usa el renderer GLES2 del
> proyecto y sale igual.

## Launcher de Android TV

Para que el juego aparezca en la fila de apps del launcher de Android TV la
activity debe declarar el intent-filter **`LEANBACK_LAUNCHER`** además del
`LAUNCHER` normal:

```xml
<intent-filter>
    <action android:name="android.intent.action.MAIN" />
    <category android:name="android.intent.category.LAUNCHER" />
</intent-filter>
<intent-filter>
    <action android:name="android.intent.action.MAIN" />
    <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
</intent-filter>
```

Con ambos filtros la app sigue funcionando como una app normal en teléfonos
(el launcher de teléfono usa `LAUNCHER`; el de TV usa `LEANBACK_LAUNCHER`).

> ⚠️ **En Godot 3.6 NO existe la opción `package/show_in_android_tv`.** Las
> claves `package/show_in_android_tv`, `package/show_in_app_library` y
> `package/show_as_launcher_app` son de Godot 4.x: si aparecen en el
> `export_presets.cfg`, Godot 3.6 las ignora en silencio y el APK sale **sin**
> el filtro de TV. La forma correcta en 3.6 es editar el manifest del custom
> build:

1. `res://android/build/AndroidManifest.xml` es el manifest *main* del
   proyecto Gradle. El exportador solo reescribe las regiones
   `<!--CHUNK_..._BEGIN/END-->` y los atributos del `<application>` tras
   `android:icon="@mipmap/icon"` (ver `platform/android/export/export_plugin.cpp`,
   bloque `//fix manifest`); **todo lo demás del archivo se preserva entre
   exports**, así que el `<intent-filter>` añadido dentro de la activity se
   conserva.
2. El manifest se mergea con el temporal `android/build/src/release/AndroidManifest.xml`
   que genera el exportador (`_write_tmp_manifest`): los intent-filters del
   manifest main se fusionan sobre la activity final `com.godot.game.GodotApp`.
3. Se añade también `<uses-feature android:name="android.software.leanback"
   android:required="false" />`: `required="false"` mantiene la instalación en
   teléfonos y cajas sin TV.

> Este manifest está **versionado en git** (es la única excepción a
> `/android/` en `.gitignore`). Al reinstalar el *Android build template*
> desde el menú del editor se sobrescribe con el template de serie; hay que
> volver a aplicar el cambio. La activity ya lleva `android:exported="true"`
> (requisito para los launchers en Android 12+).

### Portada del tile en el launcher (banner 320×180)

El launcher de Android TV usa el **`android:banner`** de la app (320×180)
como portada del tile en la fila de apps. Sin él, el tile sale sin imagen
(le pasaba a v1.1.2 y anteriores).

Fix (v1.1.3) — en el manifest del custom build
(`android/build/AndroidManifest.xml`), el atributo **antes** de `android:icon`
(lo que vaya después de `android:icon` el exportador lo borra; antes, se
preserva):

```xml
<application ... android:banner="@mipmap/banner" android:icon="@mipmap/icon">
```

Recurso `android/build/res/mipmap/banner.png` (320×180), recortado de
`Portada-TumbleBoy-Reborn.png` (1200×896 → crop 1200×675 → 320×180). La fuente
generada vive en `assets/android/banner_320x180.png`; para regenerarla:

```
cp assets/android/banner_320x180.png android/build/res/mipmap/banner.png
```

Verificar que entró en el APK:

```
aapt dump badging build/tumbleboy-reborn-debug.apk | grep banner
# application: label='TumbleBoy Reborn' ... banner='res/mipmap/banner.png'
```

> El launcher de teléfono ignora el banner; el de TV lo muestra como fondo del
> tile. También conviene tener `launcher_icons/*` en los presets
> (`assets/android/icon_192.png`, `adaptive_fg/bg_432.png`) para que el icono
> no salga genérico.

## Verificar en Waydroid (launcher de Android TV)

Waydroid permite probar el launcher de TV sin caja. Flujo usado en v1.1.3:

1. `waydroid status` → `RUNNING`; IP del contenedor (p.ej. `192.168.240.112`).
2. `adb connect 192.168.240.112:5555` (o adb portable en `/tmp/opencode/platform-tools/`).
3. `waydroid app install` **falla** en este equipo (el directorio tmp
   `~/.local/share/waydroid/data/waydroid_tmp` es root y el usuario no puede
   escribir). Usar adb directamente:
   ```
   adb -s 192.168.240.112:5555 install build/tumbleboy-reborn-debug.apk
   ```
4. El APK debug se firma con el **debug keystore** (`~/.android/debug.keystore`),
   distinto del release: si el contenedor ya tenía la release instalada hay que
   **desinstalar primero** o `adb install -r` falla con
   `INSTALL_FAILED_UPDATE_INCOMPATIBLE ... signatures do not match`:
   ```
   adb -s 192.168.240.112:5555 uninstall com.aleperix.tumbleboyreborn
   ```
5. Refrescar el launcher para que relea la app:
   ```
   adb -s 192.168.240.112:5555 shell am start -a android.intent.action.MAIN -c android.intent.category.HOME
   ```
6. Comprobar visualmente el tile en la fila de apps (el modelo/IA no ve
   imágenes: confirmar con el usuario).

## Release — checklist completa

1. **Bump de versión** en `export_presets.cfg` (los 4 presets, gitignoreado):
   `version/code` (+1) y `version/name` a la nueva.
2. **Debug en Waydroid** (verificación):
   ```
   godot3 --path . --export-debug "Android" build/tumbleboy-reborn-debug.apk
   ```
3. **3 APKs de release** (Gradle build + firma con keystore release):
   ```
   godot3 --path . --export "Android ARM64" build/tumbleboy-reborn-ARM64.apk
   godot3 --path . --export "Android ARM32" build/tumbleboy-reborn-ARM32.apk
   godot3 --path . --export "Android X86"    build/tumbleboy-reborn-X86.apk
   ```
4. **Verificar**: `aapt dump badging` (versionCode/versionName/banner) y
   `apksigner verify --print-certs` → SHA-256 `d804317b…b35be12`.
5. **Publicar**:
   ```
   git add <cambios> && git commit -m "v1.1.x: ..." && git push origin main
   git tag v1.1.x && git push origin v1.1.x
   gh release create v1.1.x --title "v1.1.x — ..." --notes-file <notas.md> \
     build/tumbleboy-reborn-ARM64.apk build/tumbleboy-reborn-ARM32.apk build/tumbleboy-reborn-X86.apk
   ```
6. **Actualizar el blog** (XO Galaxy): el post lee el changelog de
   `blog/xo-galaxy/releases.json` vía **jsDelivr** (los lectores no tocan la
   API de GitHub; si falla, el post cae a la API con ETag). Regenerar y subir:
   ```
   python3 tools/gen_releases_json.py
   git add blog/xo-galaxy/releases.json && git commit -m "blog: releases.json tras v1.1.x" && git push origin main
   ```
   jsDelivr refresca el archivo solo en ~12 h (`@main`); para forzarlo:
   `curl https://purge.jsdelivr.net/gh/Aleperix/tumbleboy-reborn@main/blog/xo-galaxy/releases.json`.

> El post también sirve sus imágenes (portada + capturas) desde jsDelivr
> (`blog/xo-galaxy/*.png` vía `@main`). Fuente versionada del post:
> `blog/xo-galaxy/post.html`.

## Instalar en caja/TV

```
adb install build/tumbleboy-reborn-debug.apk
```

En TV: la app aparece en la parrilla del launcher (activity con
`LEANBACK_LAUNCHER`, pero no TV-only: también aparece y se instala en
teléfonos).

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
2. **Controles táctiles en escritorio**: `godot3 --path . -- --force-touch`
   (`--force-touch` activa `InputManager.is_mobile()` y muestra los controles
   táctiles; el mouse emula el touch con `emulate_touch_from_mouse=true`, ya
   configurado en `project.godot`).
3. **Smoke tests headless**: `godot3 --headless --path . res://scenes/SmokeTest.tscn`.
4. **Box Rockchip**: `adb install` + comprobar FPS estables en TumbleBoy
   (es exigente por la física y el tablero grande).

## Detección de móvil

`InputManager.is_mobile()` usa `OS.has_feature("mobile")` (no `"android"`):
en Godot 3 los feature tags se comparan con sensibilidad a mayúsculas y el tag
real de Android es `"Android"`, por lo que `"android"` en minúsculas devuelve
siempre `false` y ocultaba los controles táctiles en teléfono. El tag
`"mobile"` cubre Android e iOS. En escritorio `--force-touch` fuerza `true`
para probar los controles.

Consecuencia del fix (v1.1.1): los controles táctiles (joystick + switch
Mando/Acelerómetro) aparecen ahora en el teléfono tanto en la partida como en
el modo prueba del editor (`_sync_touch_controls()` los muestra solo durante
`play_mode`).

## Botón Atrás de Android

En Godot 3.x el botón Atrás del sistema NO llega como `InputEventKey`: el
platforma Android solo emite `MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST`, y con
`application/config/quit_on_go_back` activado (default `true`) la app se cerraba
siempre sin dar opción a la lógica interna.

Fix (v1.1.2):

1. `application/config/quit_on_go_back=false` en `project.godot`: el Atrás ya no
   cierra la app por sí solo.
2. `InputManager._notification()` captura `NOTIFICATION_WM_GO_BACK_REQUEST` y
   traduce la petición a las acciones `back`/`ui_cancel` con `Input.action_press`.
   Como en Android el Atrás es un *tap* sin key-up, `action_press` se usa en vez
   de sintetizar un `InputEventKey`: marca el frame incondicionalmente, así cada
   GO_BACK genera un `back_just_pressed()` fresco (verificado en el
   `smoke_test.gd` con dos GO_BACK seguidos).

Con eso, toda la lógica existente (`back_just_pressed()` en menú, hubs, editor,
packs y partida) funciona igual en Android: el back cierra la app solo en el
menú principal y navega hacia atrás en submenús/partidas/editor.

## Controles

| Acción | Teléfono | TV/control |
|--------|----------|------------|
| Mover | Mando (joystick) / Acelerómetro | D-pad / palanca izquierda |
| Modo de control | Botón derecho (tamaño del análogo): **Mando** ↔ **Acelerómetro** (se recuerda entre partidas) | — |
| Confirmar | Toque directo | Botón A / Select |
| Atrás | Back del sistema | Botón B / Back del control |
| Foco UI del editor (TV) | — | F2 / botón Y |

> El modo de control móvil (Mando o Acelerómetro) se guarda en `SaveData.settings`
> (`control_mode`) y se restaura al iniciar. En el editor, el D-pad pinta por
> defecto; al llegar al tope de las celdas el foco salta a los botones (y a la
> inversa), y con **F2 / Y** se activa el *modo foco UI* explícito.
