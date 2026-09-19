# Cómo sumar un personaje de otro juego

Esta es la operación que el proyecto está hecho para que sea barata. Son **dos pasos**:
escribir las habilidades y registrar el personaje. No hay que tocar el HUD, ni la sala
de espera, ni la red, ni el jugador — todo eso se arma solo desde el registro.

> **El mejor ejemplo es código real del repo.** Dio Brando se agregó siguiendo
> exactamente esta guía: mirá [`scripts/characters/dio/`](../scripts/characters/dio/)
> mientras leés. Son cuatro archivos y una entrada en `CharacterDB`.

---

## Paso 1: escribir las habilidades

Creá `scripts/characters/<personaje>/` y adentro un archivo por habilidad. Cada una
hereda de `Ability`:

```gdscript
class_name MiHabilidad
extends Ability

const DAMAGE: float = 30.0

func _init() -> void:
    id = &"mi_habilidad"
    display_name = "Mi Habilidad"
    description = "Lo que se ve en la sala de espera."
    stamina_cost = 25.0     # 0 = gratis (los golpes basicos van SIEMPRE en 0)
    cooldown = 4.0
    channel_time = 0.0      # > 0 clava al jugador en el piso mientras canaliza
    icon_color = Color(1.0, 0.5, 0.2)

## CORRE EN EL SERVIDOR. Aca va el efecto real.
func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
    var source_id: int = caster.peer_id
    for target: Node3D in CombatUtils.get_players_in_cone(caster as Node3D, origin, dir, 10.0, 45.0):
        CombatUtils.deal_damage(target, DAMAGE, source_id)
```

**Lo único que hay que saber de `execute()`:**

- Corre **solo en el servidor**. No chequees `is_server()` adentro, ya está garantizado.
- No gastes stamina ni arranques cooldowns a mano: eso ya lo hizo `AbilityCaster`.
- Para pegar usá siempre `CombatUtils.deal_damage()`. Es el único camino que aplica los
  multiplicadores de estado (el +25% a los congelados, por ejemplo).

### Lo que te da `CombatUtils`

| Función | Para qué |
|---|---|
| `get_players_in_cone(caster, origin, dir, rango, angulo)` | Conos frontales. **Ya chequea línea de visión**, o sea que las coberturas funcionan. Con `angulo = 360.0` te da una esfera que igual respeta la línea de visión — así funciona ZA WARUDO. |
| `get_players_in_sphere(caster, origin, radio)` | Área alrededor de un punto, sin chequear paredes. |
| `deal_damage(target, cantidad, source_id)` | Daño, pasando por los multiplicadores de estado. |
| `apply_chill(target, stacks)` | Suma escarcha. |
| `is_frozen(target)` | Si está congelado. |
| `has_line_of_sight(from, origin, target)` | Raycast contra el mundo sólido. |

Ninguna te devuelve al propio caster ni a jugadores muertos: no hace falta filtrarlos.

### Si tu habilidad tira proyectiles

Hay una clase base, [`Projectile`](../scripts/abilities/projectile.gd). Heredás y
sobreescribís lo que cambie:

```gdscript
class_name MiProyectil
extends Projectile

func _init() -> void:
    tint = Color(0.9, 0.3, 0.2)
    hit_radius = 0.3
    fall_gravity = 0.0        # > 0 si querés que caiga. OJO: no se puede llamar
                              # "gravity" a secas, Area3D ya tiene esa propiedad.
    impact_sound = &"hit_punch"

func _build_visual() -> void:
    # Armá el mesh acá. Tenés make_glow_material(), add_trail() y add_light().
    pass

func _on_hit_player(target: Node3D) -> void:
    CombatUtils.deal_damage(target, damage, source_id)
    # ...y lo que sea propio de tu proyectil.
```

Y lo lanzás desde la habilidad:

```gdscript
static func spawn_volley(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
    var proj := MiProyectil.new()
    proj.damage = DAMAGE
    proj.speed = 30.0
    proj.lifetime = 2.5
    Projectile.launch(proj, caster, origin, dir, cosmetic)
```

**El parámetro `cosmetic` es importante.** El servidor spawnea el proyectil de verdad
(`cosmetic = false`, hace daño) y los clientes remotos spawnean una copia visual
(`cosmetic = true`, no toca nada). Si spawneás uno no-cosmético desde un cliente,
tenés daño doble. El patrón está en
[`knife_throw.gd`](../scripts/characters/dio/knife_throw.gd): `execute()` llama con
`false`, `spawn_cosmetic()` con `true`, y `FX.play_ability_cosmetic()` despacha la
versión visual cuando llega el aviso del servidor.

---

## Paso 2: registrarlo en CharacterDB

En [`scripts/core/character_db.gd`](../scripts/core/character_db.gd), los datos en
`_register_all()`:

```gdscript
    var mi_pj := CharacterData.new()
    mi_pj.id = &"mi_pj"
    mi_pj.display_name = "Nombre Visible"
    mi_pj.origin_game = "De que juego sale"
    mi_pj.body_color = Color(0.5, 0.5, 0.9)
    mi_pj.accent_color = Color(1.0, 0.4, 0.2)
    mi_pj.max_health = 100.0
    mi_pj.max_stamina = 100.0
    mi_pj.move_speed = 6.2
    mi_pj.silhouette = &"antlers"   # ver abajo
    _add(mi_pj)
```

Y el kit en `build_abilities_for()`:

```gdscript
        &"mi_pj":
            list.append(MiGolpeBasico.new())   # 0 -> click izquierdo
            list.append(MiHabilidad.new())     # 1 -> click derecho
            list.append(MiSegunda.new())       # 2 -> E
            list.append(MiUltimate.new())      # 3 -> Q, SIEMPRE ultimo
```

El orden del array es el que mandan las teclas:

| Índice | Tecla | Convención |
|---|---|---|
| 0 | Click izquierdo | Golpe básico — **siempre `stamina_cost = 0.0`** |
| 1 | Click derecho | Habilidad con costo |
| 2 | `Q` | Ultimate — **`stamina_cost = 100.0` y `requires_charge = true`** |

### Los ultimates tienen dos condiciones

Un ultimate se marca con `requires_charge = true` y cuesta la barra entera:

```gdscript
    stamina_cost = 100.0
    requires_charge = true
    cooldown = 10.0   # corto: lo que frena es la carga, no el reloj
```

El medidor de carga (`UltimateCharge`) **se llena pegando**, no esperando. `AbilityCaster`
chequea las dos condiciones y consume las dos; vos no tenés que hacer nada.

**Lo único que sí tenés que hacer:** el daño de tu ultimate va con `grants_charge = false`:

```gdscript
    CombatUtils.deal_damage(target, DAMAGE, source_id, false)
```

Si no, un ultimate que pega fuerte recarga su propio medidor y se paga el siguiente solo.

Listo. Aparece en la sala de espera con su kit, el HUD le dibuja los iconos con costos
y cooldowns, las marcas de la barra de stamina se recalculan solas, y la red lo maneja
igual que a los demás.

### La silueta

Sin modelos, lo único que distingue a un personaje de otro a 20 metros es la silueta.
Están en `PlayerVisual._build_silhouette()`:

- `&"antlers"` — las astas de Noelle (finas, altas)
- `&"shoulders"` — las hombreras y la banda de Dio (ancha, cuadrada)
- `&"none"` — sin nada (la usan los maniquíes)

Para uno nuevo, agregá un `match` más y una función que arme las piezas. Usá
`_accent_material` así toma el `accent_color` del personaje automáticamente.

---

## Reglas que conviene respetar

**El golpe básico va siempre en 0 de stamina.** No es una casualidad de Noelle: es una
regla del juego. Con la barra vacía siempre tenés que poder pelear. El HUD muestra
"GRATIS" en el icono y hay un test que lo verifica para *cada* personaje.

**Aturdir ≠ congelar.** `StatusEffects` tiene los dos estados y son distintos a
propósito: `freeze_for()` marca al objetivo como ejecutable por Snowgrave, `stun_for()`
no. Si hacés una habilidad de control, elegí bien cuál usás. Un stun que congele
convierte a cualquier dúo en un combo de dos botones.

**Usá `FX` solo para lo visual y `Sfx` solo para sonido.** Nunca apliquen daño ni estado.
Si borrás `fx.gd` y `sfx.gd` enteros, el juego tiene que seguir funcionando igual.

**Si le ponés `channel_time`**, el jugador queda clavado en el piso (la cámara sigue
libre) y si lo congelan durante el canalizado se cancela solo y se le devuelve la mitad
de la stamina. Eso ya está resuelto en `AbilityCaster`.

**Si agregás un RPC nuevo en un nodo de partida**, usá `Net.rpc_ready()` y no `.rpc()`.
Está explicado en [ARQUITECTURA.md](ARQUITECTURA.md) — es el bug que más fácil se cuela.

---

## Después de sumarlo, corré los tests

```bash
godot --headless --path . res://tests/smoke_test.tscn
```

Y si tocaste algo de red o de estados, también:

```bash
godot --headless --path . res://tests/solo_test.tscn
```

Conviene agregarle al `smoke_test.gd` un bloque como `_test_dio()` para tu personaje:
que tenga 4 habilidades, que el slot 0 sea gratis y que los costos sean los que creés.

El **orden del array es el de las teclas y el del HUD**, y el ultimate va siempre último.
Si los desordenás, la Q deja de tirar el ultimate y no hay ningún error que te avise.
Son diez líneas y te avisa cuando lo rompas dentro de seis meses.
