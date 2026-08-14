#!/usr/bin/env python3
"""Genera export_presets.cfg desde tools/export_presets.example.cfg.

El template está versionado; el archivo generado NO se commitea (contiene la
contraseña del keystore de release) y está en .gitignore. Los secretos entran
por variables de entorno o flags CLI; el número de versión vive por defecto en
este script (DEFAULTS), de modo que el bump es un cambio de git visible.

Uso:
    export TB_KEYSTORE_PATH=~/.android/tumbleboy-release.keystore
    export TB_KEYSTORE_USER=tumbleboy
    export TB_KEYSTORE_PASS='...'
    python3 tools/setup_export_presets.py

Flags alternativos (anulan env):
    python3 tools/setup_export_presets.py \\
        --keystore-path ~/.android/tumbleboy-release.keystore \\
        --keystore-user tumbleboy --keystore-pass '...' \\
        --version-code 6 --version-name 1.1.4
"""

import argparse
import os
import stat
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = os.path.join(REPO_ROOT, "tools", "export_presets.example.cfg")
OUT = os.path.join(REPO_ROOT, "export_presets.cfg")

# La versión vive aquí: el bump de versión es editar estos defaults y regenerar.
DEFAULTS = {
    "KEYSTORE_PATH": "~/.android/tumbleboy-release.keystore",
    "VERSION_CODE": "9",
    "VERSION_NAME": "1.3.0",
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


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:  # noqa: BLE001
        sys.exit(f"error: {e}")
