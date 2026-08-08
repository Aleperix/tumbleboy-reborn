#!/usr/bin/env python3
"""Genera export_presets.cfg desde tools/export_presets.example.cfg (Godot 4).

El template está versionado; el archivo generado NO se commitea (contiene la
contraseña del keystore de release) y está en .gitignore. Los secretos entran
por variables de entorno o flags CLI; el número de versión vive por defecto en
este script (DEFAULTS), de modo que el bump es un cambio de git visible.

Este es el setup del port a Godot 4 (renderer Compatibility, targetSdk 36,
minSdk 24, APKs ARM64 + X86_64). La versión se comparte con el port godot3
(release conjunta v1.2.0): ambos scripts deben llevar el mismo VERSION_CODE/NAME.

Además del preset, el script deja el template de build Android (android/build)
listo para exportar con gradle: escribe android/.build_version (marcador de
versión que exige el export) y aplica los ajustes de TV al manifest
(src/main/AndroidManifest.xml: leanback + banner + LEANBACK_LAUNCHER) y los
recursos res/mipmap-*/banner.png, de forma idempotente. Esto hace reproducible
el setup tras un clonado limpio (el template se extrae con
`godot --headless --install-android-build-template` o descomprimiendo
android_source.zip en android/build).

Uso:
    export TB_KEYSTORE_PATH=~/.android/tumbleboy-release.keystore
    export TB_KEYSTORE_USER=tumbleboy
    export TB_KEYSTORE_PASS='...'
    python3 tools/setup_export_presets.py

Flags alternativos (anulan env):
    python3 tools/setup_export_presets.py \
        --keystore-path ~/.android/tumbleboy-release.keystore \
        --keystore-user tumbleboy --keystore-pass '...' \
        --version-code 8 --version-name 1.2.0
"""

import argparse
import os
import shutil
import stat
import sys

# Version del engine para el marcador android/.build_version del gradle export.
GODOT_VERSION = "4.7.1.stable"

# Ajustes de TV que se garantizan en el manifest del template Android.
LEANBACK_FEATURE = """\
    <!-- La app funciona en telefono y en TV: required=false mantiene la instalacion
         en ambos, y el intent-filter LEANBACK_LAUNCHER la hace aparecer en el
         launcher de Android TV. -->
    <uses-feature
        android:name="android.software.leanback"
        android:required="false" />

"""

LEANBACK_FILTER = """            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
            </intent-filter>
"""

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = os.path.join(REPO_ROOT, "tools", "export_presets.example.cfg")
OUT = os.path.join(REPO_ROOT, "export_presets.cfg")

# La versión vive aquí: el bump de versión es editar estos defaults y regenerar.
DEFAULTS = {
    "KEYSTORE_PATH": "~/.android/tumbleboy-release.keystore",
    "VERSION_CODE": "8",
    "VERSION_NAME": "1.2.0",
}

ENV = {
    "KEYSTORE_PATH": "TB_KEYSTORE_PATH",
    "KEYSTORE_USER": "TB_KEYSTORE_USER",
    "KEYSTORE_PASS": "TB_KEYSTORE_PASS",
    "VERSION_CODE": "TB_VERSION_CODE",
    "VERSION_NAME": "TB_VERSION_NAME",
}

# Sin estos dos no se puede firmar el release; aborta con mensaje claro.
REQUIRED = ("KEYSTORE_USER", "KEYSTORE_PASS")


def _value(args, key):
    v = getattr(args, key, None) or os.environ.get(ENV[key]) or DEFAULTS.get(key, "")
    if key == "KEYSTORE_PATH":
        v = os.path.expanduser(v)
    return v


def _patch_manifest():
    """Aplica (idempotente) los ajustes de TV al manifest del template Android."""
    manifest_path = os.path.join(
        REPO_ROOT, "android", "build", "src", "main", "AndroidManifest.xml"
    )
    if not os.path.exists(manifest_path):
        print("  android/build no instalado todavia; saltando ajustes de TV")
        return
    with open(manifest_path, encoding="utf-8") as f:
        text = f.read()

    original = text
    if "android.software.leanback" not in text:
        text = text.replace("    <application", LEANBACK_FEATURE + "    <application", 1)
    if "@mipmap/banner" not in text:
        text = text.replace(
            'android:allowBackup="false"',
            'android:allowBackup="false"\n        android:banner="@mipmap/banner"',
            1,
        )
    if 'android.intent.category.LEANBACK_LAUNCHER' not in text:
        text = text.replace(
            '<category android:name="android.intent.category.LAUNCHER" />\n            '
            "</intent-filter>",
            '<category android:name="android.intent.category.LAUNCHER" />\n            '
            "</intent-filter>\n"
            + LEANBACK_FILTER,
            1,
        )

    if text != original:
        with open(manifest_path, "w", encoding="utf-8") as f:
            f.write(text)
        print("  manifest Android actualizado con ajustes de TV")
    else:
        print("  manifest Android ya tiene los ajustes de TV")


def _ensure_banner():
    """Copia assets/android/banner_320x180.png a res/mipmap-*/banner.png."""
    source = os.path.join(REPO_ROOT, "assets", "android", "banner_320x180.png")
    if not os.path.exists(source):
        print("  banner_320x180.png ausente en assets; saltando banner de TV")
        return
    res_dir = os.path.join(REPO_ROOT, "android", "build", "res")
    copied = False
    if os.path.isdir(res_dir):
        for entry in os.listdir(res_dir):
            if not entry.startswith("mipmap-"):
                continue
            target = os.path.join(res_dir, entry, "banner.png")
            if not os.path.exists(target):
                shutil.copyfile(source, target)
                copied = True
    if copied:
        print("  banner de TV copiado a res/mipmap-*/")
    else:
        print("  banner de TV ya presente en res/mipmap-*/")


def _ensure_build_version():
    """Escribe android/.build_version (marcador que exige el export gradle)."""
    android_dir = os.path.join(REPO_ROOT, "android")
    os.makedirs(android_dir, exist_ok=True)
    marker = os.path.join(android_dir, ".build_version")
    with open(marker, "w", encoding="utf-8") as f:
        f.write(GODOT_VERSION + "\n")
    print(f"  android/.build_version -> {GODOT_VERSION}")


def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--keystore-path", dest="KEYSTORE_PATH")
    ap.add_argument("--keystore-user", dest="KEYSTORE_USER")
    ap.add_argument("--keystore-pass", dest="KEYSTORE_PASS")
    ap.add_argument("--version-code", dest="VERSION_CODE")
    ap.add_argument("--version-name", dest="VERSION_NAME")
    args = ap.parse_args()

    values = {key: _value(args, key) for key in ENV}
    for key in REQUIRED:
        if not values[key]:
            sys.exit(
                f"falta {ENV[key]} (o --{key.lower().replace('_', '-')}) para "
                "generar export_presets.cfg"
            )

    with open(TEMPLATE, encoding="utf-8") as f:
        template = f.read()

    missing = []
    for key, value in values.items():
        placeholder = f"__{key}__"
        if placeholder not in template:
            missing.append(placeholder)
        template = template.replace(placeholder, value)

    if missing:
        sys.exit("placeholders ausentes en el template: " + ", ".join(missing))
    if "__" in template:
        sys.exit("quedan placeholders sin resolver; aborto por seguridad")

    with open(OUT, "w", encoding="utf-8") as f:
        f.write(template)
    os.chmod(OUT, stat.S_IRUSR | stat.S_IWUSR)  # 0600: contiene la contraseña
    print("export_presets.cfg generado desde", os.path.relpath(TEMPLATE, REPO_ROOT))
    print("  keystore:", values["KEYSTORE_PATH"])
    print("  version:", values["VERSION_CODE"], "/", values["VERSION_NAME"])

    _ensure_build_version()
    _patch_manifest()
    _ensure_banner()


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:  # noqa: BLE001
        sys.exit(f"error: {e}")
