# Builds de escritorio (Windows, Linux, macOS)

TumbleBoy Reborn se publica también para escritorio usando el **port a Godot 4**
(`godot4/`, renderer Compatibility). Los builds de escritorio son artefactos
adicionales de la misma release conjunta que los APKs.

## Artefactos

| Plataforma | ZIP | Arquitectura |
|------------|-----|--------------|
| Windows | `tumbleboy-reborn-win64.zip` | x86_64 |
| Windows | `tumbleboy-reborn-win32.zip` | x86_32 (PCs antiguos) |
| Linux | `tumbleboy-reborn-linux64.zip` | x86_64 |
| Linux | `tumbleboy-reborn-linux32.zip` | x86_32 |
| Linux | `tumbleboy-reborn-linux-arm64.zip` | ARM64 (Raspberry Pi, Chromebooks) |
| macOS | `tumbleboy-reborn-macos.zip` | universal (Intel + Apple Silicon) |

Todos son un único binario (o `.app` en macOS) con el pck embebido o en
`Contents/Resources`. No requieren keystore ni SDK.

## Por qué Godot 4

- El port a Godot 4 ya existe y pasa el smoke test (`SMOKE TEST: ALL PASS`).
- En escritorio todo hardware es OpenGL 3.3+ / GLES 3.0, así que el renderer
  Compatibility es el adecuado.
- godot3 (GLES2) queda solo para Android legacy.

## Requisitos

- `godot` (Godot 4.7.1) y los export templates instalados:
  `~/.local/share/godot/export_templates/4.7.1.stable/` (cubren Windows, Linux,
  macOS y Android; un solo paquete).
- **Wine** para incrustar icono/versión en el `.exe` de Windows (si falta, el
  export sigue pero el exe sale sin recursos de icono/versión).

## Exportar

```bash
cd godot4
godot --headless --path . --import   # primera vez
godot --headless --path . --export-release "Windows Desktop"   build/tumbleboy-reborn-win64.zip
godot --headless --path . --export-release "Windows Desktop 32" build/tumbleboy-reborn-win32.zip
godot --headless --path . --export-release "Linux/X11"          build/tumbleboy-reborn-linux64.zip
godot --headless --path . --export-release "Linux/X11 32"       build/tumbleboy-reborn-linux32.zip
godot --headless --path . --export-release "Linux/X11 ARM64"    build/tumbleboy-reborn-linux-arm64.zip
godot --headless --path . --export-release "macOS"              build/tumbleboy-reborn-macos.zip
```

Los presets viven en `tools/export_presets.example.cfg` y se generan con
`tools/setup_export_presets.py` junto a los de Android. Gotchas importantes:

1. **`include_filter="*.txt"`**: los presets de escritorio también lo llevan;
   sin él el juego arranca sin niveles (igual que en Android).
2. **`texture_format`**: `s3tc_bptc=true` y `etc2_astc=false`. El proyecto
   importa con ETC2/ASTC (móvil); en escritorio se re-encodifica a S3TC/BPT en
   el export. Sin estas flags los builds de escritorio no verían las texturas.
3. **macOS**: desde Linux se exporta una `.app` sin firmar ni notarizar
   (requiere un Mac + cuenta Apple Developer). El usuario debe hacer
   clic derecho → Abrir la primera vez (Gatekeeper).

## Verificar

```bash
# Linux 64: el binario exportado arranca y sale limpio en headless
./build/tumbleboy-reborn-linux64.zip   # descomprimir antes
./tumbleboy-reborn-linux64 --headless --quit-after 120   # exit 0

# Windows: smoke con Wine (usar drivers dummy, WASAPI no está completo en Wine)
wine ./tumbleboy-reborn-win64.exe --headless --audio-driver Dummy \
     --display-driver headless --quit-after 120

# macOS: verificar que el binario es universal
file "TumbleBoy Reborn.app/Contents/MacOS/TumbleBoy Reborn"
#   Mach-O universal binary ... [x86_64] ... [arm64]

# Pck: comprobar que los niveles .txt están dentro (script en /tmp no es parte del repo)
python3 tools/pck_ls.py build/tumbleboy-reborn-linux64.zip  # 21 niveles
```

Los builds de Linux x86_32 y ARM64 no se pueden probar en una máquina x86_64
sin libs de 32 bits / qemu-user; se valida la arquitectura del ELF con `file`.
macOS no se puede ejecutar desde Linux.

## Compatibilidad de datos

Los builds de escritorio usan las mismas rutas `user://` y el mismo nombre de
app que los APKs, y el formato de guardado (`save_slots.json`, v2), niveles
`.txt` y packs ZIP es idéntico entre godot3 y godot4. En el mismo SO, los
guardados y packs son intercambiables entre ambos motores.

## Release

Ver `ANDROID.md` ("Release — checklist completa"). Los zips de escritorio se
suben como assets de la misma release vía `gh release create`, junto a los 5
APKs. El blog (XO Galaxy) muestra un botón por artefacto
(`blog/xo-galaxy/post.html`, atributo `data-ext="zip"`).
