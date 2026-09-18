"""Servidor local para probar el build web antes de subirlo.

Por defecto manda las cabeceras de aislamiento:

    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp

Un export web de Godot COMPILADO CON HILOS las necesita, porque los hilos en el navegador
usan SharedArrayBuffer y eso solo existe si la pagina viene "cross-origin isolated".
`python -m http.server` a secas no las manda.

    python tools/serve_web.py [puerto]

MODO IMPORTANTE:

    python tools/serve_web.py [puerto] --sin-aislamiento

Sirve SIN esas cabeceras, que es como se ve el juego en itch.io si no marcaste
"SharedArrayBuffer support". Probar asi antes de subir es la unica forma de saber que el
build entra igual con la configuracion por defecto de itch: un build con hilos muere ahi
con "Cross-Origin Isolation ... missing", y uno sin hilos arranca normal.

Despues abri http://localhost:8060 en el navegador.
"""

import http.server
import os
import socketserver
import sys

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
AISLADO = "--sin-aislamiento" not in sys.argv

PORT = int(ARGS[0]) if ARGS else 8060
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")


class IsolatedHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        if AISLADO:
            self.send_header("Cross-Origin-Opener-Policy", "same-origin")
            self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("[web] %s\n" % (fmt % args))


if __name__ == "__main__":
    if not os.path.isdir(ROOT):
        sys.exit("No existe %s. Exporta el build web primero." % ROOT)
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", PORT), IsolatedHandler) as httpd:
        modo = "CON aislamiento" if AISLADO else "SIN aislamiento (como itch.io por defecto)"
        print("Sirviendo %s en http://localhost:%d  [%s]"
              % (os.path.abspath(ROOT), PORT, modo))
        httpd.serve_forever()
