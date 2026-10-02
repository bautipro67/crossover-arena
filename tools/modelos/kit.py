"""Kit para modelar los personajes en Blender, por codigo.

Se corre sin ventana:
    blender -b --python tools/modelos/<personaje>.py -- <carpeta de vistas previas>

COMO SE ARMA UN PERSONAJE. Cada parte (la piel, el pelo, cada prenda) es un objeto
aparte hecho de piezas suaves —elipsoides, capsulas que se afinan, tubos curvos— que se
FUNDEN en una sola superficie con un remallado por voxeles y se suavizan: el resultado es
una forma continua, como esculpida, y no un monton de primitivas apiladas. Despues se
pintan zonas (los cuadros de un sueter, un cuello, unos puños) asignando materiales por
cara.

LOS MATERIALES SE LLAMAN COMO LA PARTE ("pelo", "sueter_a", "piel"...). En el juego cada
uno se reemplaza por el material toon con el color que diga la skin para esa parte, asi
que las skins siguen funcionando sin tocar nada.

EL ESQUELETO TIENE LOS MISMOS HUESOS QUE LA ANIMACION DEL JUEGO (PlayerVisual): caderas,
torso, cabeza, hombros, codos, piernas y rodillas. El juego mueve sus pivotes como
siempre y copia el giro a los huesos. Los pesos se calculan por distancia a cada hueso.

EJES: se modela mirando a +Y, con Z para arriba (el exportador glTF lo pasa a -Z adelante
e Y arriba, que es como mira un personaje en el juego). La izquierda del personaje es -X.
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SALIDA_MODELOS = os.path.join(RAIZ, "assets", "modelos")

# Las juntas del rig de PlayerVisual, en coordenadas de Blender (x, adelante, arriba).
JUNTAS = {
    "caderas": (0.0, 0.0, 0.95),
    "cabeza": (0.0, 0.0, 1.65),
    "hombro": (0.29, 0.0, 1.45),
    "codo": (0.29, 0.0, 1.13),
    "mano": (0.29, 0.0, 0.825),
    "pierna": (0.12, 0.0, 0.93),
    "rodilla": (0.12, 0.0, 0.53),
    "pie": (0.12, 0.0, 0.08),
}


def limpiar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)


# ------------------------------------------------------------------- Materiales

def _lineal(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


_materiales = {}


def material(nombre, color, rugosidad=0.6, metal=0.0, emision=0.0):
    """Un material con nombre de parte. El color es el de fabrica (el juego lo recolorea)."""
    if nombre in _materiales:
        return _materiales[nombre]
    m = bpy.data.materials.new(nombre)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    # LOS COLORES SE ESCRIBEN COMO EN EL JUEGO (sRGB) y aca se pasan a lineal, que es lo
    # que guarda Blender: el importador de Godot los vuelve a sRGB. Sin esto el rojo del
    # sueter llegaba rosa y el verde, menta.
    col = tuple(_lineal(c) for c in color[:3]) + (1.0,)
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Roughness"].default_value = rugosidad
    bsdf.inputs["Metallic"].default_value = metal
    if emision > 0.0:
        bsdf.inputs["Emission Color"].default_value = col
        bsdf.inputs["Emission Strength"].default_value = emision
    m.diffuse_color = col
    _materiales[nombre] = m
    return m


# ---------------------------------------------------------------------- Piezas

def _objeto(nombre, bm):
    malla = bpy.data.meshes.new(nombre)
    bm.to_mesh(malla)
    bm.free()
    obj = bpy.data.objects.new(nombre, malla)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _rot(rot):
    return (Matrix.Rotation(math.radians(rot[2]), 4, "Z")
            @ Matrix.Rotation(math.radians(rot[1]), 4, "Y")
            @ Matrix.Rotation(math.radians(rot[0]), 4, "X"))


def elipsoide(centro, radios, rot=(0, 0, 0), seg=32):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(8, seg // 2), radius=1.0)
    m = Matrix.Translation(Vector(centro)) @ _rot(rot) @ Matrix.Diagonal((radios[0], radios[1], radios[2], 1.0))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return _objeto("pieza", bm)


def capsula(a, b, ra, rb=None, seg=24):
    """Capsula entre dos puntos, que puede afinarse de un radio al otro."""
    rb = ra if rb is None else rb
    a, b = Vector(a), Vector(b)
    eje = b - a
    largo = max(eje.length, 1e-4)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=ra, radius2=rb, depth=largo)
    q = Vector((0, 0, 1)).rotation_difference(eje.normalized())
    m = Matrix.Translation((a + b) * 0.5) @ q.to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    for centro, r in ((a, ra), (b, rb)):
        esf = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(8, seg // 2), radius=r)
        bmesh.ops.translate(bm, vec=centro, verts=esf["verts"])
    return _objeto("pieza", bm)


def tubo(puntos, radios, seg=16):
    """Una cadena de capsulas por una lista de puntos: mechones, astas, colas."""
    piezas = []
    for i in range(len(puntos) - 1):
        piezas.append(capsula(puntos[i], puntos[i + 1], radios[i], radios[i + 1], seg))
    return piezas


def caja(centro, tam, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Translation(Vector(centro)) @ _rot(rot) @ Matrix.Diagonal((tam[0], tam[1], tam[2], 1.0))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return _objeto("pieza", bm)


def cono(base, punta, rb, rp=0.0, seg=20):
    a, b = Vector(base), Vector(punta)
    eje = b - a
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=rb, radius2=rp, depth=eje.length)
    q = Vector((0, 0, 1)).rotation_difference(eje.normalized())
    bmesh.ops.transform(bm, matrix=Matrix.Translation((a + b) * 0.5) @ q.to_matrix().to_4x4(), verts=bm.verts)
    return _objeto("pieza", bm)


def girar(piezas, centro, rot):
    """Gira piezas ya hechas alrededor de `centro` (grados, como `rot` de las piezas). Para
    apoyar un emblema plano —armado mirando a +Y— sobre una superficie inclinada."""
    c = Vector(centro)
    m = Matrix.Translation(c) @ _rot(rot) @ Matrix.Translation(-c)
    for p in _aplanar(piezas):
        p.data.transform(m)
    return piezas


def mover(piezas, d=(0, 0, 0), escala=1.0, centro=(0, 0, 0)):
    """Corre (y si se pide, agranda alrededor de `centro`) piezas ya hechas: para acomodar
    la cabeza entera o el torso de un personaje de otras proporciones sin reescribir cada
    medida."""
    c = Vector(centro)
    m = Matrix.Translation(Vector(d)) @ Matrix.Translation(c) @ Matrix.Scale(escala, 4) @ Matrix.Translation(-c)
    for p in _aplanar(piezas):
        p.data.transform(m)
    return piezas


def inclinacion(normal):
    """El giro en X que lleva +Y a la normal `normal` (que mira para adelante)."""
    return (math.degrees(math.atan2(normal.z, normal.y)), 0, 0)


def espejo(funcion, *args, **kw):
    """Llama a `funcion` para un lado (x>0) y para el otro, espejando las X de los puntos."""
    def esp(v):
        if isinstance(v, (tuple, list)) and len(v) == 3 and all(isinstance(c, (int, float)) for c in v):
            return (-v[0], v[1], v[2])
        if isinstance(v, (tuple, list)) and v and isinstance(v[0], (tuple, list)):
            return [esp(p) for p in v]
        return v
    uno = funcion(*args, **kw)
    otro = funcion(*[esp(a) for a in args], **{k: esp(v) for k, v in kw.items()})
    return [uno, otro]


def _aplanar(piezas):
    plano = []
    for p in piezas:
        if isinstance(p, (list, tuple)):
            plano.extend(_aplanar(p))
        else:
            plano.append(p)
    return plano


# ------------------------------------------------------------------------ Fundir

# Cuanto de las `caras` pedidas se usa de verdad. Un personaje queda en 40 a 60 mil
# triangulos: en una partida hay varios a la vez, y la version web tambien los mueve.
CALIDAD = 0.6


def _reducir(obj, caras):
    """Baja la malla a `caras` TRIANGULOS (por CALIDAD). El remallado da cuadrados y el
    decimate cuenta triangulos: con la cuenta en caras salian el doble."""
    if not caras:
        return
    meta = caras * CALIDAD
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris > meta:
        bpy.context.view_layer.objects.active = obj
        dec = obj.modifiers.new("reducir", "DECIMATE")
        dec.ratio = meta / tris
        bpy.ops.object.modifier_apply(modifier=dec.name)


def fundir(nombre, piezas, mat, voxel=0.010, suavizado=8, caras=6000):
    """Junta las piezas en UNA superficie continua: remallado por voxeles (union suave,
    sin costuras), suavizado y reduccion de caras. `mat` es el material de toda la parte;
    despues se puede pintar por zonas con pintar()."""
    piezas = _aplanar(piezas)
    bpy.ops.object.select_all(action="DESELECT")
    for p in piezas:
        p.select_set(True)
    bpy.context.view_layer.objects.active = piezas[0]
    if len(piezas) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = nombre
    obj.data.name = nombre
    rem = obj.modifiers.new("remallar", "REMESH")
    rem.mode = "VOXEL"
    rem.voxel_size = voxel
    rem.adaptivity = 0.0
    bpy.ops.object.modifier_apply(modifier=rem.name)
    if suavizado > 0:
        sm = obj.modifiers.new("suavizar", "SMOOTH")
        sm.factor = 0.6
        sm.iterations = suavizado
        bpy.ops.object.modifier_apply(modifier=sm.name)
    _reducir(obj, caras)
    for pol in obj.data.polygons:
        pol.use_smooth = True
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def cascara(nombre, piezas, mat, condicion, grosor=0.012, voxel=0.007, suavizado=6, caras=6000, bordes=4):
    """Una PLACA o una TELA con espesor: la superficie de las piezas fundidas, recortada a
    las caras cuyo centro cumple `condicion`, con el borde suavizado y un grosor hacia
    adentro. Asi salen las placas de una armadura, un chaleco abierto o una pollera que
    se separan del cuerpo y tienen canto, y no son bultos pegados."""
    obj = fundir(nombre, piezas, mat, voxel=voxel, suavizado=suavizado, caras=0)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    fuera = [f for f in bm.faces if not condicion(*(obj.matrix_world @ f.calc_center_median()))]
    bmesh.ops.delete(bm, geom=fuera, context="FACES")
    sueltos = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=sueltos, context="VERTS")
    for _ in range(bordes):
        borde = [v for v in bm.verts if v.is_boundary]
        bmesh.ops.smooth_vert(bm, verts=borde, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(obj.data)
    bm.free()
    bpy.context.view_layer.objects.active = obj
    sol = obj.modifiers.new("grosor", "SOLIDIFY")
    sol.thickness = grosor
    sol.offset = -1.0
    sol.use_even_offset = True
    bpy.ops.object.modifier_apply(modifier=sol.name)
    _reducir(obj, caras)
    for pol in obj.data.polygons:
        pol.use_smooth = True
    return obj


def cortar(obj, punto, normal=(0, 0, 1)):
    """Corta las caras de `obj` a lo largo de un plano, sin sacar nada: asi el borde entre
    dos colores pintados queda una linea recta y no la escalera de los voxeles (el negro de
    los hombros de Naruto, la cintura del overol de Mario)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    inv = obj.matrix_world.inverted()
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=inv @ Vector(punto),
                           plane_no=(inv.to_3x3() @ Vector(normal)).normalized())
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def pintar(obj, mat, condicion):
    """Pinta con `mat` las caras cuyo centro (x, y, z) cumple `condicion`."""
    if mat.name not in [m.name for m in obj.data.materials if m]:
        obj.data.materials.append(mat)
    idx = [m.name for m in obj.data.materials].index(mat.name)
    for pol in obj.data.polygons:
        c = obj.matrix_world @ pol.center
        if condicion(c.x, c.y, c.z):
            pol.material_index = idx


def pieza_fija(nombre, piezas, mat):
    """Una parte dura que NO se funde (botones, un emblema): se juntan las piezas tal cual."""
    piezas = _aplanar(piezas)
    bpy.ops.object.select_all(action="DESELECT")
    for p in piezas:
        p.select_set(True)
    bpy.context.view_layer.objects.active = piezas[0]
    if len(piezas) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = nombre
    for pol in obj.data.polygons:
        pol.use_smooth = True
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


# ---------------------------------------------------------------------- Esqueleto

HUESOS = [
    # nombre, padre, cabeza, cola
    ("caderas", None, "caderas", None),
    ("torso", "caderas", "caderas", None),
    ("cabeza", "torso", "cabeza", None),
    ("hombro_l", "torso", "hombro_l", "codo_l"),
    ("codo_l", "hombro_l", "codo_l", "mano_l"),
    ("hombro_r", "torso", "hombro_r", "codo_r"),
    ("codo_r", "hombro_r", "codo_r", "mano_r"),
    ("pierna_l", "caderas", "pierna_l", "rodilla_l"),
    ("rodilla_l", "pierna_l", "rodilla_l", "pie_l"),
    ("pierna_r", "caderas", "pierna_r", "rodilla_r"),
    ("rodilla_r", "pierna_r", "rodilla_r", "pie_r"),
]


def juntas(cambios=None):
    """Las juntas del personaje: las del rig, con lo que este personaje cambie."""
    j = {}
    for k, v in JUNTAS.items():
        if k in ("hombro", "codo", "mano", "pierna", "rodilla", "pie"):
            j[k + "_r"] = v
            j[k + "_l"] = (-v[0], v[1], v[2])
        else:
            j[k] = v
    for k, v in (cambios or {}).items():
        if k.endswith("_r") or k in j and not k.endswith("_l"):
            j[k] = v
            if k.endswith("_r"):
                j[k[:-2] + "_l"] = (-v[0], v[1], v[2])
        else:
            j[k] = v
    return j


def esqueleto(j):
    arm_data = bpy.data.armatures.new("esqueleto")
    arm = bpy.data.objects.new("esqueleto", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    colas = {
        "caderas": Vector(j["caderas"]) + Vector((0, 0, 0.10)),
        "torso": Vector(j["cabeza"]) - Vector((0, 0, 0.05)),
        "cabeza": Vector(j["cabeza"]) + Vector((0, 0, 0.30)),
    }
    for nombre, padre, cab, cola in HUESOS:
        b = arm_data.edit_bones.new(nombre)
        b.head = Vector(j[cab])
        b.tail = Vector(j[cola]) if cola else colas[nombre]
        if padre:
            b.parent = arm_data.edit_bones[padre]
        b.roll = 0.0
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def _segmento(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-8)))
    return (p - (a + ab * t)).length


def pesar(obj, arm, j, solo=None, permitidos=None, potencia=5.0):
    """Pesos por distancia a cada hueso. `solo`: todo a un hueso (partes duras, el pelo).
    `permitidos`: a cuales huesos puede ir esta parte (una manga no va a la pierna)."""
    segs = {}
    for nombre, padre, cab, cola in HUESOS:
        a = Vector(j[cab])
        if cola:
            b = Vector(j[cola])
        elif nombre == "caderas":
            b = a + Vector((0, 0, 0.05))
        elif nombre == "torso":
            b = Vector(j["cabeza"]) - Vector((0, 0, 0.06))
        else:
            b = a + Vector((0, 0, 0.30))
        segs[nombre] = (a, b)
    grupos = {n: obj.vertex_groups.new(name=n) for n, _p, _c, _t in HUESOS}
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        if solo:
            grupos[solo].add([v.index], 1.0, "REPLACE")
            continue
        cand = permitidos or [n for n in segs if n != "caderas"]
        ds = sorted((_segmento(p, *segs[n]), n) for n in cand)
        mejores = ds[:2]
        pesos = [(1.0 / max(d, 0.004) ** potencia, n) for d, n in mejores]
        suma = sum(w for w, _ in pesos)
        for w, n in pesos:
            if w / suma > 0.02:
                grupos[n].add([v.index], w / suma, "REPLACE")
    obj.parent = arm
    mod = obj.modifiers.new("esqueleto", "ARMATURE")
    mod.object = arm


# ------------------------------------------------------------------- Exportar

def exportar(nombre, arm, cara=None):
    os.makedirs(SALIDA_MODELOS, exist_ok=True)
    # Un objeto que se llama como un hueso ("cabeza", "torso") hace que el importador de
    # Godot le cambie el nombre AL HUESO ("cabeza_2"), y el juego ya no lo encuentra: la
    # cabeza dejaba de seguir a la animacion.
    huesos = {h[0] for h in HUESOS}
    for o in arm.children:
        if o.name in huesos:
            o.name = o.name + "_malla"
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for o in arm.children:
        o.select_set(True)
    ruta = os.path.join(SALIDA_MODELOS, nombre + ".glb")
    bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB", use_selection=True,
                              export_skins=True, export_apply=False, export_yup=True,
                              export_animations=False, export_materials="EXPORT")
    if cara is not None:
        with open(os.path.join(SALIDA_MODELOS, nombre + ".json"), "w", encoding="utf-8") as f:
            json.dump(cara, f, indent=1)
    print("[modelos] exportado", ruta)
    return ruta


def a_juego(v, j):
    """Un punto de Blender pasado a coordenadas del juego, relativo a la junta de la cabeza."""
    c = Vector(j["cabeza"])
    d = Vector(v) - c
    return [round(d.x, 4), round(d.z, 4), round(-d.y, 4)]


# ------------------------------------------------------------------- Vistas

def vistas(carpeta, nombre, alto=1.0):
    """Fotos de frente, tres cuartos y espalda, con los colores de fabrica."""
    os.makedirs(carpeta, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.show_object_outline = True
    sh.show_specular_highlight = True
    sc.render.resolution_x = 520
    sc.render.resolution_y = 720
    sc.render.film_transparent = False
    sc.world = bpy.data.worlds.new("mundo") if not sc.world else sc.world
    cam = bpy.data.objects.new("camara", bpy.data.cameras.new("camara"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 60
    centro = Vector((0, 0, 1.0 * alto))
    for vista, ang in (("frente", 0.0), ("tres_cuartos", 35.0), ("costado", 90.0), ("espalda", 180.0)):
        r = math.radians(ang)
        cam.location = centro + Vector((math.sin(r) * 5.2, math.cos(r) * 5.2, 0.15))
        cam.rotation_euler = (centro - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(carpeta, "%s_%s.png" % (nombre, vista))
        bpy.ops.render.render(write_still=True)
    # Y la cara de cerca.
    cam.location = Vector((0.6, 1.9, 1.78 * alto))
    cam.rotation_euler = (Vector((0, 0, 1.72 * alto)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(carpeta, "%s_cara.png" % nombre)
    bpy.ops.render.render(write_still=True)


def carpeta_vistas():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return args[0] if args else os.path.join(RAIZ, "build", "vistas_modelos")


# --------------------------------------------------------- Pegar cosas a la piel

def superficie(obj, x, z, desde=(0.0, 1.5), hacia=(0.0, -1.0)):
    """Donde un rayo que viene de adelante (de +Y) toca `obj` a la altura (x, z). Devuelve
    (punto, normal) en el mundo, o (None, None). Sirve para que los ojos y la boca queden
    pegados a la cara y no flotando ni hundidos."""
    import mathutils
    origen = obj.matrix_world.inverted() @ Vector((x, desde[1], z))
    direccion = (obj.matrix_world.inverted().to_3x3() @ Vector((hacia[0], hacia[1], 0.0))).normalized()
    ok, punto, normal, _i = obj.ray_cast(origen, direccion)
    if not ok:
        return None, None
    return obj.matrix_world @ punto, (obj.matrix_world.to_3x3() @ normal).normalized()


def pegar(obj, punto, afuera=0.002):
    """El punto de la superficie de `obj` mas cercano a `punto`, corrido `afuera` por la
    normal: para que una linea dibujada sobre una forma aproximada quede apoyada en la piel."""
    inv = obj.matrix_world.inverted()
    ok, loc, normal, _i = obj.closest_point_on_mesh(inv @ Vector(punto))
    if not ok:
        return tuple(punto)
    n = (obj.matrix_world.to_3x3() @ normal).normalized()
    return tuple(obj.matrix_world @ loc + n * afuera)


def lineas(nombre, polilineas, radio, mat):
    """Lineas finas (costuras, la telaraña del traje) como UNA malla liviana: una curva con
    bisel de cuatro lados por cada polilinea, en vez de cientos de capsulas."""
    curva = bpy.data.curves.new(nombre, "CURVE")
    curva.dimensions = "3D"
    curva.bevel_depth = radio
    curva.bevel_resolution = 0
    curva.use_fill_caps = True
    for pl in polilineas:
        if len(pl) < 2:
            continue
        sp = curva.splines.new("POLY")
        sp.points.add(len(pl) - 1)
        for i, p in enumerate(pl):
            sp.points[i].co = (p[0], p[1], p[2], 1.0)
    obj = bpy.data.objects.new(nombre, curva)
    bpy.context.scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    obj.name = nombre
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def orientar(piezas, centro, normal):
    """Gira piezas armadas mirando a +Y para que miren a `normal`, alrededor de `centro`:
    los lentes de una mascara, un emblema sobre una superficie curva."""
    c = Vector(centro)
    q = Vector((0, 1, 0)).rotation_difference(Vector(normal).normalized())
    m = Matrix.Translation(c) @ q.to_matrix().to_4x4() @ Matrix.Translation(-c)
    for p in _aplanar(piezas):
        p.data.transform(m)
    return piezas


def escala_desde(centro, k):
    """Una funcion que agranda un punto `k` veces alrededor de `centro`: para agrandar la
    cabeza entera sin reescribir cada pieza."""
    c = Vector(centro)

    def f(p):
        return tuple(c + (Vector(p) - c) * k)
    return f


# ------------------------------------------------------------- Piezas de humano
#
# Lo que tienen en comun casi todos: una cabeza de persona, brazos, manos, piernas y
# zapatos. Cada personaje las llama con sus medidas y despues agrega lo propio.

def cabeza_humana(c=(0.0, 0.0, 1.80), ancho=0.150, alto=0.180, fondo=0.160, mandibula=1.0,
                  nariz=1.0, orejas=True, menton=1.0):
    """Craneo, mandibula, menton, nariz y orejas. `c` es el centro del craneo."""
    x, y, z = c
    piezas = [
        elipsoide((x, y - 0.005, z + 0.01), (ancho, fondo, alto)),
        # La mandibula: mas angosta que el craneo y un poco adelante.
        elipsoide((x, y + 0.035, z - 0.085), (ancho * 0.80 * mandibula, fondo * 0.72, alto * 0.50)),
        # El menton.
        elipsoide((x, y + 0.085, z - 0.140 * menton), (ancho * 0.34, fondo * 0.30, alto * 0.18)),
        # La nariz.
        elipsoide((x, y + fondo * 0.98, z - 0.035), (0.020 * nariz, 0.028 * nariz, 0.032 * nariz), rot=(20, 0, 0)),
    ]
    if orejas:
        for lado in (-1, 1):
            piezas.append(elipsoide((x + lado * ancho * 0.97, y - 0.005, z - 0.02),
                                    (0.018, 0.034, 0.048), rot=(0, lado * 15, 0)))
    return piezas


def brazo(lado, r_hombro=0.066, r_codo=0.056, r_muneca=0.046, j=None, hasta=0.875):
    """El brazo entero (de hombro a muñeca), colgando de las juntas del rig."""
    j = j or juntas()
    s = "_l" if lado < 0 else "_r"
    h, c = j["hombro" + s], j["codo" + s]
    m = (j["mano" + s][0], j["mano" + s][1], hasta)
    return tubo([h, c, m], [r_hombro, r_codo, r_muneca])


def antebrazo(lado, r_codo=0.056, r_muneca=0.046, j=None, hasta=0.875):
    j = j or juntas()
    s = "_l" if lado < 0 else "_r"
    return tubo([j["codo" + s], (j["mano" + s][0], j["mano" + s][1], hasta)], [r_codo, r_muneca])


def mano(lado, j=None, r=0.046, dedos=True, guante=1.0):
    """Palma, pulgar y, si se pide, los cuatro dedos juntos en dos falanges."""
    j = j or juntas()
    s = "_l" if lado < 0 else "_r"
    x, y, z = j["mano" + s]
    g = guante
    piezas = [elipsoide((x, y, z + 0.005), (r * g, r * 0.70 * g, r * 1.20 * g))]
    # El pulgar, por delante y hacia adentro.
    piezas.append(capsula((x - lado * 0.010, y + 0.030 * g, z + 0.025), (x - lado * 0.022, y + 0.052 * g, z - 0.012),
                          0.016 * g, 0.014 * g))
    if dedos:
        for k in range(4):
            dy = (-0.024 + k * 0.016) * g
            piezas.append(capsula((x + lado * 0.004, y + dy, z - 0.035 * g), (x + lado * 0.010, y + dy, z - 0.072 * g),
                                  0.0115 * g, 0.0105 * g, seg=12))
    return piezas


def pierna(lado, r_muslo=0.082, r_rodilla=0.064, r_tobillo=0.050, j=None, hasta=0.12):
    j = j or juntas()
    s = "_l" if lado < 0 else "_r"
    p, r = j["pierna" + s], j["rodilla" + s]
    return tubo([p, r, (r[0], r[1], hasta)], [r_muslo, r_rodilla, r_tobillo])


def zapato(lado, j=None, largo=0.115, ancho=0.066, alto=0.058, suela=None, punta=1.0):
    """El zapato: el talon, la capellada y la punta. `suela` = material de la suela, si se
    quiere aparte (devuelve [zapato, suela])."""
    j = j or juntas()
    s = "_l" if lado < 0 else "_r"
    x, y, z = j["pie" + s]
    piezas = [
        elipsoide((x, y - 0.020, z + 0.010), (ancho, largo * 0.55, alto * 1.05)),
        elipsoide((x, y + largo * 0.45, z - 0.005), (ancho * 0.95 * punta, largo * 0.55, alto * 0.80)),
        capsula((x, y - 0.01, z + 0.02), (x, y - 0.01, z + 0.11), ancho * 0.80, ancho * 0.72),
    ]
    return piezas


def torso_humano(pecho=0.200, cintura=0.165, fondo=0.125, alto_pecho=1.38, alto_cintura=1.10, hombros=0.165):
    """Pecho, cintura y la linea de los hombros, fundidos en un torso."""
    return [
        elipsoide((0, 0.0, alto_pecho), (pecho, fondo * 1.05, 0.190)),
        elipsoide((0, 0.0, alto_cintura), (cintura, fondo * 0.95, 0.150)),
        capsula((-hombros, 0.0, 1.47), (hombros, 0.0, 1.47), 0.075),
        elipsoide((0, 0.0, 0.99), (cintura * 1.02, fondo * 0.95, 0.090)),
    ]


def perfil(puntos, paso=0.02, x=0.0, seg=28):
    """Un cuerpo LOFTEADO: secciones elipticas apiladas que siguen un perfil
    [(z, ancho, fondo) o (z, ancho, fondo, y), ...], interpoladas cada `paso`. Fundidas dan
    una superficie pareja, sin los bultos de dos elipsoides encimados: un saco recto, una
    cintura que se afina de a poco, un pecho que se ensancha."""
    puntos = [p if len(p) == 4 else (p[0], p[1], p[2], 0.0) for p in puntos]
    piezas = []
    for i in range(len(puntos) - 1):
        z0, a0, f0, y0 = puntos[i]
        z1, a1, f1, y1 = puntos[i + 1]
        n = max(1, int(round(abs(z1 - z0) / paso)))
        for k in range(n + (1 if i == len(puntos) - 2 else 0)):
            t = k / n
            piezas.append(elipsoide((x, y0 + (y1 - y0) * t, z0 + (z1 - z0) * t),
                                    (a0 + (a1 - a0) * t, f0 + (f1 - f0) * t, paso * 1.6), seg=seg))
    return piezas


def pesar_estandar(partes, arm, j):
    """Los pesos de la forma de siempre, segun el nombre de cada parte:
    'cabeza'/'torso'/... = todo a ese hueso; 'brazos'/'mangas' = brazos y torso;
    'manos' = codos; 'piernas'/'botas'/'zapatos' = piernas; 'falda'/'pantalon' = torso y
    piernas; cualquier otra = por distancia a todos."""
    brazos = ["torso", "hombro_l", "codo_l", "hombro_r", "codo_r"]
    piernas = ["pierna_l", "rodilla_l", "pierna_r", "rodilla_r"]
    for obj, regla in partes:
        if regla in ("cabeza", "torso", "caderas", "codo_l", "codo_r", "rodilla_l", "rodilla_r"):
            pesar(obj, arm, j, solo=regla)
        elif regla == "brazos":
            pesar(obj, arm, j, permitidos=brazos)
        elif regla == "manos":
            pesar(obj, arm, j, permitidos=["codo_l", "codo_r"])
        elif regla == "piernas":
            pesar(obj, arm, j, permitidos=piernas)
        elif regla == "pies":
            pesar(obj, arm, j, permitidos=["rodilla_l", "rodilla_r"])
        elif regla == "cadera":
            pesar(obj, arm, j, permitidos=["torso"] + piernas)
        else:
            pesar(obj, arm, j)


def cara_estandar(cabeza_obj, j, ojo_x, ojo_z, ojos_extra=None, boca_z=None, boca_extra=None,
                  cejas=None, escala=None):
    """Ojos y boca pegados a la superficie de la cabeza (un rayo desde adelante)."""
    f = escala or (lambda p: p)
    ojos = {}
    giro = 8.0
    for lado, clave in ((-1, "l"), (1, "r")):
        p0 = f((lado * ojo_x, 0.0, ojo_z))
        p, n = superficie(cabeza_obj, p0[0], p0[2])
        if p is None:
            p, n = Vector(p0) + Vector((0, 0.15, 0)), Vector((0, 1, 0))
        ojos[clave] = a_juego(tuple(p + n * 0.003), j)
        giro = math.degrees(math.atan2(abs(n.x), max(0.05, n.y)))
    cara = {"ojos": dict({"l": ojos["l"], "r": ojos["r"], "giro": round(giro, 1)}, **(ojos_extra or {}))}
    if cejas:
        cara["cejas"] = cejas
    if boca_z is not None:
        pb = f((0.0, 0.0, boca_z))
        p, n = superficie(cabeza_obj, 0.0, pb[2])
        if p is not None:
            cara["boca"] = dict({"pos": a_juego(tuple(p + n * 0.003), j)}, **(boca_extra or {}))
    return cara
