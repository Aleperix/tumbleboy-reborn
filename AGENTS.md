# AGENTS.md — Guía para agentes de IA

Guía operativa para trabajar en este repo. Documentación técnica profunda en
`docs/` (empezar por `docs/README.md` y `docs/API.md`); aquí solo lo que hay
que saber sí o sí para no romper nada ni perder el tiempo.

## Qué es esto

**TumbleBoy Reborn**: marble-platformer pseudo-3D en **Godot 3.6** (renderer
GLES2) para Android (teléfono + TV/box con chip Rockchip, OpenGL ES 2.0).
Modo historia (21 niveles), editor de niveles, packs de la comunidad
descargables desde el juego, guardado por zócalos. Todo el código y las
conversaciones del proyecto van en **español**.

## Entorno y comandos

- Dos motores, dos árboles:
  - **Raíz**: **Godot 3.6.2** (NO 4.x), renderer GLES2, para Android legacy
    (cajas GLES 2.0-only). En esta máquina se llama `godot3` (wrapper que
    aísla la config con `XDG_CONFIG_HOME=~/.config/godot3-env`).
  - **`godot4/`**: port a **Godot 4.7.1** (renderer Compatibility), usado para
    Android moderno (targetSdk 36) y **escritorio (Windows/Linux/macOS)**. En
    esta máquina se llama `godot`.
- Jugar (raíz): `godot3 --path .` · controles táctiles: `godot3 --path . -- --force-touch`.
  Jugar (port): `godot --path godot4`.
- **Smoke test (el estándar antes de tocar nada):**
  - Raíz: `godot3 --headless --path . res://scenes/SmokeTest.tscn`
  - Port: `godot --headless --path godot4 res://scenes/SmokeTest.tscn`
  Debe terminar en `SMOKE TEST: ALL PASS` (≈265 checks, exit 0). Se cuelga
  en `--headless` si algún test deja nodos vivos (ver "Gotchas").
- Importar assets: `godot3 --headless --path . --import` (raíz) o
  `godot --headless --path godot4 --import` (port; necesario la primera vez).
- Export APK y release: ver `docs/ANDROID.md` (¡y el gotcha de `--export` abajo!).
  Export desktop: ver `docs/DESKTOP.md`.

## Arquitectura en 60 segundos

- Autoloads (`project.godot`): `AudioManager`, `SaveData` (guardado por
  zócalos + settings), `InputManager` (todas las acciones de entrada, back de
  Android, modo móvil/tilt), `LevelQueue`, `NavParams`.
- `scripts/tumbleboy/` — lógica del juego: `tumbleboy.gd` (partida),
  `board.gd`, `ball.gd`, `levels.gd`, `editor.gd`, `pack_store.gd`
  (tienda online: GitHub API + ETag/304, `http.timeout`), packs/zip.
- `scripts/ui/` — menús y hubs (`main_menu`, `story_hub`, `slot_picker`,
  `packs_community`, `editor_hub`, `credits`), `focus_nav.gd` (foco D-pad),
  `focus_grab.gd` (restaura foco 2 frames tras reconstruir filas).
- Escenas en `scenes/`, tests en `tests/`, packs de ejemplo en `packs/`,
  niveles en `assets/tumbleboy/data/levels/`.

## Convenciones

- GDScript 3.x, indentación con **tabs**, mensajes de log/UI/commits en español.
- Nombres: métodos privados `_con_guion_bajo`, snake_case para variables/funciones.
- Los menús leen el botón Atrás en `_process()` (patrón v1.1.4, ver Gotchas),
  no en `_input`/`_unhandled_input`.
- Los tests crean instancias de escenas y **siempre las liberan con `free()`**.

## Gotchas (críticos)

1. **Botón Atrás de Android**: llega solo como
   `MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST` (nunca como `InputEventKey`).
   `InputManager._notification()` lo traduce con `Input.action_press("back")` +
   `"ui_cancel"`, y eso solo marca `is_action_just_pressed()` *durante ese
   frame*. Por eso se **sondea en `_process`**, nunca en `_input`. `project.godot`
   tiene `config/quit_on_go_back=false`. Detalle: `action_press` sin
   `action_release` deja la acción "presionada" (ver gotcha 2).
2. **El smoke test se cuelga si un test filtra nodos.** Causa (ya corregida):
   `_test_scene` no hacía `free()` del TumbleBoy en `PLAYING`; al dejarlo en el
   árbol, su `_process` veía el `back` todavía "presionado" del
   `_test_android_back` y llamaba `_go_to_menu()` → `change_scene()` → liberaba
   el smoke test a mitad de un `yield` → cuelgue silencioso en headless. Regla:
   **todo test que instancie una escena debe `free()`arla**, y si el test toca
   acciones de input debe liberarlas (`InputManager.release_action(...)`).
3. **`--export-release` NO existe en Godot 3.6.** Los flags son `--export`
   (release), `--export-debug` y `--export-pack`. Un flag desconocido se ignora
   en silencio y no exporta nada (ni error). El preset release genera 1 APK por
   ABI: `--export "Android ARM64"` / `"Android ARM32"` / `"Android X86"`.
4. **`export_presets.cfg` NO se commitea** (`.gitignore:15`, lleva la
   contraseña del keystore release). Se regenera con
   `tools/setup_export_presets.py` (template `tools/export_presets.example.cfg`,
   env `TB_KEYSTORE_PATH`/`TB_KEYSTORE_USER`/`TB_KEYSTORE_PASS` o flags;
   permisos 0600). La **versión** del juego vive en `DEFAULTS` del script
   (`VERSION_CODE`/`VERSION_NAME`): el bump es editar el script + regenerar.
   El keystore release está en `~/.android/tumbleboy-release.keystore`.
5. **Los `.txt` de niveles no se empaquetan solos**: cada preset del
   `export_presets.cfg` necesita `include_filter="*.txt"` o el juego arranca
   sin niveles. El manifest de TV (`android/build/AndroidManifest.xml`) se
   preserva entre exports salvo las regiones CHUNK — está versionado.
6. **Blog (XO Galaxy)**: el post lee `releases.json` vía jsDelivr; tras
   publicar release hay que regenerar (`python3 tools/gen_releases_json.py`),
   commitear y purgar `https://purge.jsdelivr.net/gh/Aleperix/tumbleboy-reborn@main/blog/xo-galaxy/releases.json`.
   Dentro de `<script>` del post **no** usar caracteres no-ASCII literales
   (`·`, `ó`): usar escapes `\u00b7`, `\u00f3` o Blogger los convierte en
   entidades que rompen el JS; la plantilla exige `//<![CDATA[`.
7. **Ruido de OpenGL inofensivo**: `free(): invalid pointer`, `nvidia-drm`,
   `dri3`, `pci id` en la salida headless/export son del teardown de GLES de
   este equipo; no indican error. El criterio de éxito es `SMOKE TEST: ALL PASS`
   / APK generado + `apksigner verify`.
8. **Detección móvil**: `InputManager.is_mobile()` usa `OS.has_feature("mobile")`
   (el tag real de Android es `"Android"`, con mayúscula; `"android"` devuelve
   siempre false). `--force-touch` lo fuerza en escritorio.

## Publicar una release (resumen)

Flujo completo en `docs/ANDROID.md` ("Release — checklist completa") y
`docs/DESKTOP.md`. Resumen: bump de versión en **ambos**
`setup_export_presets.py` (raíz y `godot4/`, misma VERSION_CODE/NAME) →
regenerar presets → exportar los 5 APKs (3 godot3 + 2 godot4) y los 6 zips de
escritorio → verificar (`aapt`/`apksigner`, `file`, smoke) → `git tag` +
`gh release create` → regenerar/subir `releases.json` → purgar jsDelivr. Los
artefactos van como assets de la release; los botones del blog usan
`releases/latest/download/` (sin versiones hardcodeadas).

## Documentación

- `docs/README.md` — índice + decisiones técnicas.
- `docs/API.md` — referencia técnica (autoloads, scripts, escenas, formatos).
- `docs/ANDROID.md` — build/export/release/checklist + gotchas de TV.
- `docs/game-tumbleboy.md`, `docs/tumbleboy-level-format.md` — ficha del juego y formato de niveles.
- `packs/README.md` — formato de packs comunitarios.
