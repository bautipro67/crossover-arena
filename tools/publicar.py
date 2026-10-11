#!/usr/bin/env python3
"""Apunta el juego al servidor publico, lo exporta y arma los .zip para itch.io.

La URL del servidor no se puede saber antes de desplegarlo: Render la inventa al crear
el servicio. Asi que el orden es: primero subis el servidor, despues corres esto con la
URL que te dio, y recien ahi subis el juego a itch.

    python tools/publicar.py wss://crossover-arena.onrender.com

Sin argumentos deja el juego SIN servidor oficial (el menu no muestra "JUGAR ONLINE" y
cada jugador escribe la direccion a mano):

    python tools/publicar.py --sin-servidor

Godot se busca solo en los lugares habituales; si no aparece, pasalo con --godot.

LA VERSION DEL CELULAR (build/android/CrossoverArena.apk) sale tambien, si el Android SDK
esta instalado (la ruta la toma de la configuracion del editor de Godot). Se firma con la
clave de depuracion de Godot de esta maquina: alcanza para instalarla a mano, y como es
siempre la misma, una version nueva se instala encima de la vieja sin perder el progreso.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CONFIG = RAIZ / "scripts" / "core" / "game_config.gd"
BUILD = RAIZ / "build"

# (preset del export_presets.cfg, salida, carpeta que se comprime, nombre del zip)
EXPORTS = [
    ("Web", BUILD / "web" / "index.html", BUILD / "web", "CrossoverArena-web.zip"),
    ("Windows Desktop", BUILD / "windows" / "CrossoverArena.exe", BUILD / "windows",
     "CrossoverArena-windows.zip"),
]


def encontrar_godot(explicito):
    if explicito:
        return explicito
    if os.environ.get("GODOT"):
        return os.environ["GODOT"]
    candidatos = ["godot", "godot4", "Godot_v4.6.3-stable_win64_console.exe"]
    for c in candidatos:
        ruta = shutil.which(c)
        if ruta:
            return ruta
    return None


def escribir_url(url):
    """Reescribe la constante OFFICIAL_SERVER_URL sin tocar el resto del archivo."""
    texto = CONFIG.read_text(encoding="utf-8")
    patron = re.compile(r'^(const OFFICIAL_SERVER_URL: String = )".*"$', re.MULTILINE)
    if not patron.search(texto):
        sys.exit("No encontre OFFICIAL_SERVER_URL en %s" % CONFIG)
    nuevo = patron.sub(lambda m: '%s"%s"' % (m.group(1), url), texto)
    CONFIG.write_text(nuevo, encoding="utf-8", newline="\n")
    print("servidor oficial -> %s" % (url or "(ninguno)"))


def normalizar(url):
    """itch.io sirve por HTTPS y el navegador bloquea ws:// desde una pagina segura.

    Render entrega https://algo.onrender.com; lo que necesita el juego es wss://algo...
    Es el error mas facil de cometer aca y el mas dificil de diagnosticar despues,
    porque falla solo en la version web y sin mensaje claro.
    """
    url = url.strip().rstrip("/")
    if url.startswith("https://"):
        url = "wss://" + url[len("https://"):]
    elif url.startswith("http://"):
        print("AVISO: http:// no sirve para la version de itch.io. Lo paso a wss://.")
        url = "wss://" + url[len("http://"):]
    elif not url.startswith("wss://") and not url.startswith("ws://"):
        url = "wss://" + url
    return url


def exportar(godot, preset, salida):
    salida.parent.mkdir(parents=True, exist_ok=True)
    print("\nexportando %s ..." % preset)
    # IMPORTAR ANTES DE EXPORTAR.
    #
    # Godot no mete en el .pck un archivo que todavia no importo, y no avisa: exporta
    # contento y el juego sale sin el. Con todo sintetizado por codigo eso nunca pasaba
    # —no habia archivos— pero desde que las voces pueden ser grabaciones, alguien puede
    # dejar caer un .ogg en assets/voces/ y exportar. Sin esto, el juego publicado saldria
    # con la voz sintetizada y sin ninguna pista de por que.
    subprocess.run([godot, "--headless", "--path", str(RAIZ), "--import"],
                   capture_output=True, text=True)

    r = subprocess.run(
        [godot, "--headless", "--path", str(RAIZ), "--export-release", preset, str(salida)],
        capture_output=True, text=True)
    if not salida.exists():
        print(r.stdout[-2000:])
        print(r.stderr[-2000:])
        sys.exit("fallo el export de %s" % preset)
    print("   ok -> %s" % salida.relative_to(RAIZ))


# ------------------------------------------------------------------ Android

AJUSTES_EDITOR = Path(os.environ.get("APPDATA", "")) / "Godot" / "editor_settings-4.6.tres"
APK = BUILD / "android" / "CrossoverArena.apk"
PRESETS = RAIZ / "export_presets.cfg"


def ajuste_editor(clave):
    """Un valor de la configuracion del editor de Godot (o "" si no esta)."""
    if not AJUSTES_EDITOR.exists():
        return ""
    for linea in AJUSTES_EDITOR.read_text(encoding="utf-8", errors="replace").splitlines():
        if linea.startswith(clave + " = "):
            return linea.split(" = ", 1)[1].strip().strip('"').replace("\\\\", "\\")
    return ""


def sdk_android():
    """La carpeta del Android SDK, si esta y tiene lo que Godot necesita para firmar."""
    ruta = Path(os.environ.get("ANDROID_HOME") or ajuste_editor("export/android/android_sdk_path") or "x")
    adb = ruta / "platform-tools" / ("adb.exe" if os.name == "nt" else "adb")
    herramientas = ruta / "build-tools"
    if adb.exists() and herramientas.is_dir() and any(herramientas.iterdir()):
        return ruta
    return None


def version_android():
    """El numero de version del APK: la cantidad de commits. Tiene que subir siempre, o el
    celular no deja instalar la nueva encima de la vieja."""
    try:
        n = int(subprocess.run(["git", "rev-list", "--count", "HEAD"], cwd=RAIZ,
                               capture_output=True, text=True).stdout.strip())
    except ValueError:
        n = 1
    return n


def exportar_android(godot):
    sdk = sdk_android()
    if sdk is None:
        print("\n(sin Android SDK: no se arma la version del celular)")
        return None
    clave = ajuste_editor("export/android/debug_keystore")
    if not clave or not Path(clave).exists():
        print("\n(sin la clave de depuracion de Godot: no se arma la version del celular)")
        return None
    # El numero de version va en el preset solo durante el export, y se devuelve como estaba.
    original = PRESETS.read_text(encoding="utf-8")
    n = version_android()
    con_version = re.sub(r"^version/code=\d+$", "version/code=%d" % n, original, flags=re.MULTILINE)
    con_version = re.sub(r'^version/name=".*"$', 'version/name="1.%d"' % n, con_version, flags=re.MULTILINE)
    PRESETS.write_text(con_version, encoding="utf-8", newline="\n")
    entorno = dict(os.environ)
    entorno["GODOT_ANDROID_KEYSTORE_RELEASE_PATH"] = clave
    entorno["GODOT_ANDROID_KEYSTORE_RELEASE_USER"] = ajuste_editor("export/android/debug_keystore_user") or "androiddebugkey"
    entorno["GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"] = ajuste_editor("export/android/debug_keystore_pass") or "android"
    try:
        APK.parent.mkdir(parents=True, exist_ok=True)
        if APK.exists():
            APK.unlink()
        print("\nexportando Android (version 1.%d) ..." % n)
        r = subprocess.run([godot, "--headless", "--path", str(RAIZ), "--export-release", "Android", str(APK)],
                           capture_output=True, text=True, env=entorno)
    finally:
        PRESETS.write_text(original, encoding="utf-8", newline="\n")
    if not APK.exists():
        print(r.stdout[-2000:])
        print(r.stderr[-2000:])
        sys.exit("fallo el export de Android")
    print("   ok -> %s (%.1f MB)" % (APK.relative_to(RAIZ), APK.stat().st_size / 1048576))
    return APK


def comprimir(carpeta, nombre):
    destino = BUILD / nombre
    if destino.exists():
        destino.unlink()
    with zipfile.ZipFile(destino, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for archivo in sorted(carpeta.rglob("*")):
            if archivo.is_file():
                # OJO: rutas RELATIVAS A LA CARPETA, sin carpeta contenedora. itch.io
                # exige index.html en la raiz del zip; si queda dentro de web/ el juego
                # sube bien pero no arranca nunca.
                z.write(archivo, archivo.relative_to(carpeta).as_posix())
    mb = destino.stat().st_size / 1048576
    print("   zip -> build/%s (%.1f MB)" % (nombre, mb))
    return destino


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("url", nargs="?", help="URL del servidor, p.ej. wss://algo.onrender.com")
    ap.add_argument("--sin-servidor", action="store_true",
                    help="deja el juego sin servidor oficial")
    ap.add_argument("--godot", help="ruta al ejecutable de Godot 4.6")
    args = ap.parse_args()

    if not args.url and not args.sin_servidor:
        ap.error("pasame la URL del servidor o --sin-servidor")

    godot = encontrar_godot(args.godot)
    if not godot:
        sys.exit("No encontre Godot. Pasalo con --godot RUTA o defini la variable GODOT.")

    url = "" if args.sin_servidor else normalizar(args.url)
    escribir_url(url)

    for preset, salida, carpeta, nombre in EXPORTS:
        exportar(godot, preset, salida)
        comprimir(carpeta, nombre)
    apk = exportar_android(godot)

    print("\nlisto. Subi a itch.io:")
    print("   build/CrossoverArena-web.zip       (HTML, sin marcar nada mas)")
    print("   build/CrossoverArena-windows.zip   (descarga opcional)")
    if apk:
        print("   build/android/CrossoverArena.apk   (version del celular, plataforma Android)")
    if url:
        print("\nel menu ya muestra JUGAR ONLINE apuntando a %s" % url)


if __name__ == "__main__":
    main()
