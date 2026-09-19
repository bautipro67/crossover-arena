#!/usr/bin/env python3
"""Verifica que un servidor de CrossoverArena este vivo y aceptando conexiones.

    python tools/probar_servidor.py wss://crossover-arena.onrender.com
    python tools/probar_servidor.py 127.0.0.1 27015

POR QUE EXISTE: cuando el juego no conecta, la pregunta es "esta caido el servidor o
esta mal el juego?". Sin una forma de preguntarselo al servidor directamente, la unica
manera de averiguarlo es reexportar el juego entero y probar, que son varios minutos
por intento.

Esto hace el apretón de manos de WebSocket a mano y te dice exactamente donde fallo:
DNS, TCP, TLS o el propio protocolo. No usa ninguna libreria de afuera.

En el plan gratuito de Render la instancia se duerme, asi que el primer intento puede
tardar cerca de un minuto en contestar. El script espera y te dice cuanto tardo: ese
numero ES el arranque en frio que van a sufrir tus jugadores.
"""

import base64
import hashlib
import os
import socket
import ssl
import sys
import time
from urllib.parse import urlparse

# Constante del protocolo (RFC 6455). El servidor la concatena a nuestra clave y
# devuelve el SHA-1; verificarlo es lo que distingue un WebSocket de verdad de un
# proxy que contesta cualquier cosa.
GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
TIMEOUT = 90.0


def parsear(argv):
    """Acepta una URL entera, o host + puerto sueltos."""
    if not argv:
        sys.exit(__doc__)
    crudo = argv[0].strip().rstrip("/")

    # https:// es lo que copias de Render; el juego habla wss:// contra el mismo lugar.
    if crudo.startswith("https://"):
        crudo = "wss://" + crudo[len("https://"):]
    elif crudo.startswith("http://"):
        crudo = "ws://" + crudo[len("http://"):]

    if "://" not in crudo:
        puerto = int(argv[1]) if len(argv) > 1 else 27015
        return "ws", crudo, puerto, "/"

    u = urlparse(crudo)
    seguro = u.scheme == "wss"
    puerto = u.port or (443 if seguro else 80)
    if len(argv) > 1 and argv[1].isdigit():
        puerto = int(argv[1])
    return u.scheme, u.hostname, puerto, u.path or "/"


def probar(esquema, host, puerto, ruta):
    seguro = esquema == "wss"
    print("servidor : %s://%s:%d%s" % (esquema, host, puerto, ruta))
    print("tls      : %s" % ("si" if seguro else "no"))
    print()

    t0 = time.time()

    # --- DNS ---
    try:
        ip = socket.gethostbyname(host)
        print("  [ok]  DNS resuelve a %s" % ip)
    except socket.gaierror as e:
        print("  [NO]  DNS no resuelve: %s" % e)
        print("\nEl nombre no existe. Revisa que copiaste bien la URL de Render.")
        return 1

    # --- TCP ---
    try:
        cru = socket.create_connection((host, puerto), timeout=TIMEOUT)
    except OSError as e:
        print("  [NO]  no se pudo abrir el puerto %d: %s" % (puerto, e))
        print("\nHay nombre pero nadie escuchando. Si es Render, mira los logs del")
        print("servicio: probablemente el deploy fallo o la instancia murio al arrancar.")
        return 1
    print("  [ok]  TCP conectado (%.1fs)" % (time.time() - t0))

    # --- TLS ---
    sock = cru
    if seguro:
        try:
            ctx = ssl.create_default_context()
            sock = ctx.wrap_socket(cru, server_hostname=host)
            print("  [ok]  TLS negociado (%s)" % sock.version())
        except ssl.SSLError as e:
            print("  [NO]  fallo el TLS: %s" % e)
            print("\nSin TLS valido, la version de itch.io no va a poder conectarse:")
            print("el navegador bloquea WebSocket inseguro desde una pagina HTTPS.")
            return 1

    # --- Apreton de manos WebSocket ---
    clave = base64.b64encode(os.urandom(16)).decode()
    pedido = (
        "GET %s HTTP/1.1\r\n"
        "Host: %s\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        "Sec-WebSocket-Key: %s\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        "\r\n"
    ) % (ruta, host, clave)

    sock.settimeout(TIMEOUT)
    sock.sendall(pedido.encode())

    datos = b""
    try:
        while b"\r\n\r\n" not in datos and len(datos) < 65536:
            trozo = sock.recv(4096)
            if not trozo:
                break
            datos += trozo
    except socket.timeout:
        print("  [NO]  el servidor no contesto en %.0fs" % TIMEOUT)
        return 1
    finally:
        sock.close()

    if not datos:
        print("  [NO]  el servidor cerro la conexion sin contestar")
        return 1

    cabeceras = datos.split(b"\r\n\r\n")[0].decode("latin-1")
    primera = cabeceras.splitlines()[0] if cabeceras else "(vacio)"

    if "101" not in primera:
        print("  [NO]  el servidor contesto: %s" % primera)
        print()
        if "404" in primera or "502" in primera or "503" in primera:
            print("Eso es el proxy de Render, no tu juego. 502/503 suele ser la instancia")
            print("todavia despertando o un deploy caido: espera y volve a probar, y si")
            print("sigue igual mira los logs del servicio.")
        else:
            print("Hay algo escuchando pero no habla WebSocket.")
        return 1

    # Verificamos que la respuesta sea de un WebSocket real y no de un proxy.
    esperado = base64.b64encode(
        hashlib.sha1((clave + GUID).encode()).digest()).decode()
    if esperado.lower() not in cabeceras.lower():
        print("  [NO]  contesto 101 pero la clave no valida: no es un WebSocket real")
        return 1

    total = time.time() - t0
    print("  [ok]  apreton de manos WebSocket completo")
    print()
    print("SERVIDOR VIVO. Tardo %.1f segundos en contestar." % total)
    if total > 8.0:
        print()
        print("Ese tiempo es el ARRANQUE EN FRIO del plan gratuito: la instancia estaba")
        print("dormida. El juego lo aguanta (insiste hasta 75s y avisa que espera), pero")
        print("es lo que va a esperar el primer jugador que entre.")
    return 0


if __name__ == "__main__":
    sys.exit(probar(*parsear(sys.argv[1:])))
