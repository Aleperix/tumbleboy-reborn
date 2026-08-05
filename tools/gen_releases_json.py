#!/usr/bin/env python3
"""Genera blog/xo-galaxy/releases.json para el post del blog (vía jsDelivr).

Llama una sola vez a la API pública de GitHub (60 req/h por IP) y escribe un
JSON con las últimas releases. El blog lo sirve desde jsDelivr para que los
lectores no toquen la API de GitHub.

Uso:
    python3 tools/gen_releases_json.py [--per-page 12] [--path blog/xo-galaxy/releases.json]
"""

import argparse
import json
import os
import sys
import urllib.request

REPO = "Aleperix/tumbleboy-reborn"
API_URL = f"https://api.github.com/repos/{REPO}/releases"
DEFAULT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "blog", "xo-galaxy", "releases.json",
)


def fetch_releases(per_page):
    req = urllib.request.Request(
        f"{API_URL}?per_page={per_page}",
        headers={"Accept": "application/vnd.github+json", "User-Agent": "gen_releases_json"},
    )
    with urllib.request.urlopen(req) as resp:
        remaining = resp.headers.get("X-RateLimit-Remaining")
        data = json.load(resp)
    if remaining:
        print(f"rate limit restante: {remaining}")
    if not isinstance(data, list):
        raise RuntimeError(f"respuesta inesperada: {data}")
    return data


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--per-page", type=int, default=12)
    ap.add_argument("--path", default=DEFAULT_PATH)
    args = ap.parse_args()

    releases = fetch_releases(args.per_page)
    out = []
    for r in releases:
        out.append({
            "tag_name": r.get("tag_name"),
            "name": r.get("name"),
            "published_at": r.get("published_at"),
            "body": r.get("body") or "",
            "assets": [
                {
                    "name": a.get("name"),
                    "size": a.get("size"),
                    "browser_download_url": a.get("browser_download_url"),
                }
                for a in (r.get("assets") or [])
            ],
        })

    os.makedirs(os.path.dirname(args.path), exist_ok=True)
    with open(args.path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"{len(out)} releases -> {args.path}")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # noqa: BLE001
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)
