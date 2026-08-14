#!/usr/bin/env python3
# Publica blog/xo-galaxy/post.html en Blogger (XO Galaxy) via la Blogger API.
#
# OAuth 2.0 tipo "Desktop app" (loopback redirect). Solo stdlib.
#
# Uso:
#   tools/blogger_publish.py --auth             # 1a vez: autorizar y guardar token
#   tools/blogger_publish.py                     # publica (actualiza) el post
#   tools/blogger_publish.py --post <archivo>    # con otro archivo
#   tools/blogger_publish.py --blog-id <id>      # fuerza el blog (--list-blogs)
#   tools/blogger_publish.py --list-blogs        # lista blogs del usuario
#
# Credenciales: ~/.config/tumbleboy-reborn/blogger_creds.json (0600) o
# BLOGGER_CLIENT_ID / BLOGGER_CLIENT_SECRET. Token:
# ~/.config/tumbleboy-reborn/blogger_token.json (0600).

import json
import os
import random
import socket
import sys
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer

APP = "tumbleboy-reborn"
CONF_DIR = os.path.expanduser("~/.config/" + APP)
CREDS_FILE = os.path.join(CONF_DIR, "blogger_creds.json")
TOKEN_FILE = os.path.join(CONF_DIR, "blogger_token.json")
SCOPE = "https://www.googleapis.com/auth/blogger"
AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_URL = "https://oauth2.googleapis.com/token"
BLOGS_URL = "https://www.googleapis.com/blogger/v3/users/self/blogs"
TITLE = "TumbleBoy Reborn en XO Galaxy"


def die(msg):
    print("error:", msg, file=sys.stderr)
    sys.exit(1)


def load_creds():
    if os.path.exists(CREDS_FILE):
        with open(CREDS_FILE) as f:
            d = json.load(f)
        if d.get("client_id") and d.get("client_secret"):
            return d["client_id"], d["client_secret"]
    cid = os.environ.get("BLOGGER_CLIENT_ID")
    csec = os.environ.get("BLOGGER_CLIENT_SECRET")
    if cid and csec:
        return cid, csec
    die("no hay credenciales (revisa " + CREDS_FILE + " o BLOGGER_CLIENT_ID/SECRET)")


def load_token():
    if not os.path.exists(TOKEN_FILE):
        return None
    with open(TOKEN_FILE) as f:
        return json.load(f)


def save_token(token, blog_id=None):
    if blog_id is not None:
        token["blog_id"] = blog_id
    os.makedirs(CONF_DIR, exist_ok=True)
    with open(TOKEN_FILE, "w") as f:
        json.dump(token, f, indent=2)
    os.chmod(TOKEN_FILE, 0o600)


def http_json(url, data=None, headers=None, method=None):
    req = urllib.request.Request(url, data=data, headers=headers or {}, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read().decode()), r.status
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        try:
            err = json.loads(body).get("error", {}).get("message", body)
        except Exception:
            err = body
        die("HTTP %s: %s" % (e.code, err))


def refresh_token(client_id, client_secret, token):
    print("refrescando token de acceso...")
    body = urllib.parse.urlencode({
        "client_id": client_id,
        "client_secret": client_secret,
        "refresh_token": token["refresh_token"],
        "grant_type": "refresh_token",
    }).encode()
    data, _ = http_json(TOKEN_URL, data=body,
                        headers={"Content-Type": "application/x-www-form-urlencoded"})
    token["access_token"] = data["access_token"]
    if data.get("expires_in"):
        token["expires_in"] = data["expires_in"]
    save_token(token, token.get("blog_id"))
    return token


class _Handler(BaseHTTPRequestHandler):
    code = None

    def do_GET(self):
        q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        if "code" in q:
            type(self).code = q["code"][0]
            body = b"Autorizacion recibida. Ya puedes cerrar esta pestana."
        else:
            body = ("No se recibio codigo de autorizacion: " + self.path).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


def oauth_flow(client_id, client_secret):
    port = random.randint(20000, 50000)
    redirect_uri = "http://localhost:%d/" % port
    params = {
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": SCOPE,
        "access_type": "offline",
        "prompt": "consent",
    }
    url = AUTH_URL + "?" + urllib.parse.urlencode(params)

    srv = HTTPServer(("localhost", port), _Handler)
    srv.timeout = 600
    print("Abre esta URL en tu navegador (con la cuenta de XO Galaxy):")
    print("  " + url)
    try:
        if webbrowser.open(url):
            print("(se abrio el navegador)")
        else:
            print("Copia y pega la URL en tu navegador y autoriza.")
    except Exception:
        print("Copia y pega la URL en tu navegador y autoriza.")
    while _Handler.code is None:
        srv.handle_request()
    srv.server_close()
    code = _Handler.code

    print("intercambiando el codigo por tokens...")
    body = urllib.parse.urlencode({
        "code": code,
        "client_id": client_id,
        "client_secret": client_secret,
        "redirect_uri": redirect_uri,
        "grant_type": "authorization_code",
    }).encode()
    data, _ = http_json(TOKEN_URL, data=body,
                        headers={"Content-Type": "application/x-www-form-urlencoded"})
    token = {
        "access_token": data["access_token"],
        "refresh_token": data.get("refresh_token"),
        "expires_in": data.get("expires_in"),
    }
    save_token(token)
    if not token.get("refresh_token"):
        print("aviso: no se emitio refresh_token (consent screen en 'Testing' o revisar prompt=consent).")
    return token


def list_blogs(token):
    h = {"Authorization": "Bearer " + token["access_token"]}
    data, _ = http_json(BLOGS_URL, headers=h)
    return data.get("items", [])


def pick_blog(token, forced=None):
    if forced:
        return forced
    if token.get("blog_id"):
        return token["blog_id"]
    blogs = list_blogs(token)
    if not blogs:
        die("el usuario no tiene blogs en Blogger")
    if len(blogs) == 1:
        b = blogs[0]
        print("blog:", b["name"], "<" + b.get("url", "") + ">")
        return b["id"]
    print("Selecciona el blog (--blog-id):")
    for b in blogs:
        print("  %-20s %s" % (b["id"], b.get("url", "")))
    die("usa --blog-id <id> para elegir")


def find_post(token, blog_id):
    q = urllib.parse.quote(TITLE)
    url = ("https://www.googleapis.com/blogger/v3/blogs/%s/posts/search?q=%s"
           % (blog_id, q))
    h = {"Authorization": "Bearer " + token["access_token"]}
    data, _ = http_json(url, headers=h)
    items = data.get("items", [])
    items.sort(key=lambda p: p.get("updated", ""), reverse=True)
    return items[0] if items else None


def publish(post_file, forced_blog=None):
    client_id, client_secret = load_creds()
    token = load_token()
    if not token:
        die("no hay token: ejecuta primero 'tools/blogger_publish.py --auth'")
    token = refresh_token(client_id, client_secret, token)

    blog_id = pick_blog(token, forced=forced_blog)
    if blog_id != token.get("blog_id"):
        save_token(token, blog_id)

    existing = find_post(token, blog_id)
    if existing:
        print("post existente: '%s' (actualizado %s)" % (existing.get("title"), existing.get("updated")))
        title = existing.get("title") or TITLE
        labels = existing.get("labels") or ["TumbleBoy", "Godot", "Android", "Plan Ceibal", "Código abierto", "Retro"]
    else:
        print("no se encontro el post '%s': se creara uno nuevo" % TITLE)
        title = TITLE
        labels = ["TumbleBoy", "Godot", "Android", "Plan Ceibal", "Código abierto", "Retro"]

    with open(post_file, encoding="utf-8") as f:
        content = f.read()

    payload = json.dumps({"title": title, "labels": labels, "content": content}).encode()
    h = {"Authorization": "Bearer " + token["access_token"], "Content-Type": "application/json"}

    if existing:
        url = "https://www.googleapis.com/blogger/v3/blogs/%s/posts/%s" % (blog_id, existing["id"])
        data, _ = http_json(url, data=payload, headers=h, method="PUT")
        print("post ACTUALIZADO:", data.get("url"))
    else:
        url = "https://www.googleapis.com/blogger/v3/blogs/%s/posts" % blog_id
        data, _ = http_json(url, data=payload, headers=h, method="POST")
        print("post CREADO:", data.get("url"))


def main():
    args = sys.argv[1:]
    if "--auth" in args:
        client_id, client_secret = load_creds()
        oauth_flow(client_id, client_secret)
        print("token guardado en", TOKEN_FILE)
        return
    if "--list-blogs" in args:
        client_id, client_secret = load_creds()
        token = load_token() or die("ejecuta primero --auth")
        token = refresh_token(client_id, client_secret, token)
        for b in list_blogs(token):
            print("%-20s %s" % (b["id"], b.get("url", "")))
        return
    post_file = "blog/xo-galaxy/post.html"
    blog_id = None
    if "--post" in args:
        i = args.index("--post")
        post_file = args[i + 1]
    if "--blog-id" in args:
        i = args.index("--blog-id")
        blog_id = args[i + 1]
    publish(post_file, forced_blog=blog_id)


if __name__ == "__main__":
    main()
