# Versión web (HTML5) y GitHub Pages

TumbleBoy Reborn se publica también como **juego en el navegador** usando el
port a **Godot 4** (`godot4/`, renderer Compatibility, WebGL2). El build
HTML5 se despliega en **GitHub Pages** desde la rama `gh-pages`.

## Dónde se juega

- **Juego en línea**: <https://aleperix.github.io/tumbleboy-reborn/>
- **ZIP para alojar tú**: `tumbleboy-reborn-web.zip` (asset de la release):
  contiene `tumbleboy-reborn.html` (renombrable a `index.html`), `.js`,
  `.wasm`, `.pck` e iconos. Súbelo a cualquier servidor estático con HTTPS.

## Configuración del preset

El preset `Web` está en `tools/export_presets.example.cfg` (preset nº 9) y se
genera con `tools/setup_export_presets.py` igual que el resto. Valores clave:

1. **`variant/thread_support=false`** (single-threaded): sin SharedArrayBuffer
   no se necesitan cabeceras COOP/COEP, así que el juego funciona tal cual en
   GitHub Pages (que no permite cabeceras custom). Si se activara threads
   habría que servir con `Cross-Origin-Opener-Policy` + `Cross-Origin-Embedder-Policy`.
2. **`texture_format`**: `s3tc_bptc=true`, `etc2_astc=true` (`for_desktop+for_mobile`):
   WebGL2 soporta S3TC/ETC2, así que se mantienen ambas.
3. **`canvas_resize_policy=2`** (Adaptive): el canvas se adapta al tamaño de la
   ventana del navegador.
4. **`include_filter="*.txt"`**: el pck lleva los 21 niveles (mismo gotcha que
   en el resto de presets).

## Exportar y desplegar

```bash
# Exportar el build web (necesita que build/web/ exista antes)
mkdir -p godot4/build/web
cd godot4
godot --headless --path . --export-release "Web" build/web/tumbleboy-reborn.html

# Publicar en gh-pages (exporta si falta; --no-export usa el build actual)
tools/update_gh_pages.sh            # o: --no-export
```

`tools/update_gh_pages.sh` crea/actualiza la rama `gh-pages` con un *worktree*
en `/tmp`, copia los artefactos, renombra `tumbleboy-reborn.html` a
`index.html`, añade `.nojekyll` y hace push. La primera vez también hay que
activar Pages en GitHub (Settings → Pages → Source: `gh-pages` / root); la URL
es `https://<usuario>.github.io/tumbleboy-reborn/`.

## Verificar

```bash
# El .wasm se sirve con el MIME correcto
curl -sI https://aleperix.github.io/tumbleboy-reborn/tumbleboy-reborn.wasm
#   content-type: application/wasm

# Smoke en navegador (sin JS errors; captura = loader del motor)
firefox --headless --window-size=1200,825 --screenshot /tmp/web.png \
    https://aleperix.github.io/tumbleboy-reborn/
```

El pck debe contener los 21 niveles (`tools/pck_ls.py` sobre el zip exportado).
El render del menú no se puede validar en headless con `--screenshot` (captura
en el `load`, antes de que acabe de instanciar el wasm de ~39 MB): la señal
suficiente es página 200 + pck con niveles + consola sin errores.

## Release

El `tumbleboy-reborn-web.zip` se sube como un asset más de la release conjunta
(vía `gh release create/upload`). El blog (XO Galaxy) tiene un botón
**"Jugar en el navegador"** que enlaza a GitHub Pages y un botón **Web** que
descarga el zip (`blog/xo-galaxy/post.html`, `data-ext="zip"`).

## Gotchas

- GitHub Pages sirve el wasm de 39 MB tal cual (sin gzip: el tamaño se nota en
  la primera carga). El `.js` y `.pck` sí se sirven comprimidos.
- Los guardados de la versión web viven en el origen del navegador: son
  independientes de los guardados del escritorio/móvil.
- `build/` y los `.zip`/`.exe` de `godot4/` están en `.gitignore`: no se
  commitean artefactos, solo el preset de ejemplo y `tools/update_gh_pages.sh`.
