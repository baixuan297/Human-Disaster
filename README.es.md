# Desastre Humano (cliente Godot)

[Español](README.es.md) | [中文](README.md)

Los `.md` en `docs/` están en **chino** (detalle técnico). Esta página traduce introducción, estructura e índice.

---

## Introducción

**Desastre Humano** es un cliente de acción RPG en **tercera persona** (Godot **4.6**, Forward Plus, 1920×1080). El jugador explora niveles, combate y progresa: cambio 1ª/3ª persona, armas y habilidades, inventario (xuanBag), genes y límite de nivel **SYNC**; enemigos definidos por plantillas (melee FSM, rangos, botín). Hay ajustes locales y guardado opcional de personaje en la nube vía API HTTP.

En solo local se puede probar escenas y combate; login, `/game-data/*` y nube requieren API del juego (ver «Ejecución»).

---

## Estructura del proyecto

```
Human Disaster/          ← raíz del proyecto Godot
├── project.godot
├── autoload/            # singletons (API, guardado, escenas…)
├── Script/              # lógica por dominio
├── Scene/               # escenas (jugador, enemigos, menús…)
├── resource/            # Resources (Stats, AttackData…)
├── 素材/                 # arte y audio
├── addons/xuanBag/      # inventario
├── test/
└── docs/
```

| Ruta | Descripción |
|------|-------------|
| `autoload/` | `ApiManager`, `GameDataManager`, `CharacterDataManager`, `SceneManager`, etc. |
| `Script/player/` | Movimiento, cámara, entrada |
| `Script/gun/` | Armas, proyectiles, armas en el mundo |
| `Script/enemy/` | Enemigos, hitboxes, melee FSM |
| `Script/SkillSystem/` | Efectos de habilidades |
| `Script/menu/` | Login, menú, ajustes, paneles |
| `resource/stats/` | `Stats`: vida, nivel, EXP, resistencias |

Detalle de `Script/`: [docs/SCRIPT_LAYOUT.md](docs/SCRIPT_LAYOUT.md).

---

## Arquitectura (resumen)

Capa **Autoload** (datos/red) + componentes en escena (Player, enemigos, armas).

| Fase | Qué ocurre |
|------|------------|
| Arranque | `GameDataManager` pide plantillas; `SaveManager` carga ajustes |
| Login | `UserManager` + JWT y `character_id` |
| Entrar nivel | `CharacterDataManager.restore_to_player` |
| Combate | `AttackData` → `Stats.take_damage`; EXP al matar |
| Cambio escena | snapshot → cargar → restore |
| Guardar | `save_to_api` + copia local `.lcs` |

Más: [docs/DAMAGE_SYSTEM.md](docs/DAMAGE_SYSTEM.md), [docs/AUTOLOAD_AND_UI.md](docs/AUTOLOAD_AND_UI.md).

---

## Ejecución

1. Abrir `project.godot` en Godot 4.6, F5.
2. Solo local: sin base de datos; login, nube y `/game-data/*` limitados.
3. Guardado completo: desplegar **API del juego** (FastAPI + PostgreSQL, por defecto `http://127.0.0.1:8000`) y ajustar `API_BASE_URL` en `autoload/APIManager.gd`.

| Elemento | Descripción |
|----------|-------------|
| Godot | 4.6 (`config/features`) |
| API del juego | Puerto **8000**; rutas en [docs/APIManager.md](docs/APIManager.md) |
| App comunidad | Spring **8080**, no usa `APIManager.gd` |

**Red:** `API_BASE_URL` = URL alcanzable del API.

### Controles

WASD, Espacio, Mayús, Ctrl, ratón, 1/2/rueda, B, C, Q/E/X, F.

### Pruebas

- `test/api_test.tscn` (API en marcha; `TEST_SKIP_EMAIL_VERIFY=1` en local)
- [docs/TESTING.md](docs/TESTING.md)

---

## Índice de documentación

Ver [docs/AUTOLOAD_AND_UI.md](docs/AUTOLOAD_AND_UI.md).

### Cómo leer

1. Tabla **tema → documento principal**; abra solo uno.
2. Un tema = un documento autoritativo.
3. No use [docs/CHARACTER_AND_WEAPON_OVERVIEW.md](docs/CHARACTER_AND_WEAPON_OVERVIEW.md) como fuente definitiva.
4. Tras cambiar código, actualice ese documento y, si cambian rutas JSON, [docs/APIManager.md](docs/APIManager.md).

### Tema → documento principal

| Tema | Documento | No cubre |
|------|-----------|----------|
| Entrada | **esta página** | — |
| Autoload / pausa / UI | [docs/AUTOLOAD_AND_UI.md](docs/AUTOLOAD_AND_UI.md) | Gameplay |
| `Script/` | [docs/SCRIPT_LAYOUT.md](docs/SCRIPT_LAYOUT.md) | Lógica |
| HTTP / JWT | [docs/APIManager.md](docs/APIManager.md) | Guardado |
| Snapshot / nube | [docs/CharacterDataManager.md](docs/CharacterDataManager.md) | Daño |
| Guardado local | [docs/LOCAL_AND_CLOUD_SAVE.md](docs/LOCAL_AND_CLOUD_SAVE.md) | Ajustes |
| Ajustes | [docs/SaveManager.md](docs/SaveManager.md) | Progreso |
| `/game-data/*` | [docs/GameDataManager.md](docs/GameDataManager.md) | Runtime enemigo |
| Inventario | [docs/INVENTORY.md](docs/INVENTORY.md) | Armas |
| Armas | [docs/WEAPON_SYSTEM.md](docs/WEAPON_SYSTEM.md) | Habilidades |
| Habilidades | [docs/SKILL_SYSTEM.md](docs/SKILL_SYSTEM.md) | Genes |
| Cámara | [docs/PLAYER_CAMERA_AND_MOVEMENT.md](docs/PLAYER_CAMERA_AND_MOVEMENT.md) | Campos save |
| Física | [docs/COLLISION_LAYERS.md](docs/COLLISION_LAYERS.md) | Daño |
| Daño | [docs/DAMAGE_SYSTEM.md](docs/DAMAGE_SYSTEM.md) | IA enemiga |
| Enemigos | [docs/ENEMY_SYSTEM.md](docs/ENEMY_SYSTEM.md) | Fórmulas daño |
| Experiencia | [docs/EXPERIENCE_SYSTEM.md](docs/EXPERIENCE_SYSTEM.md) | Genes |
| Genes | [docs/GENE_SYSTEM.md](docs/GENE_SYSTEM.md) | IA |
| Peligros | [docs/HAZARD_SYSTEM_ALIGNMENT.md](docs/HAZARD_SYSTEM_ALIGNMENT.md) | Daño genérico |
| Menú / SYNC | [docs/CHARACTER_MENU.md](docs/CHARACTER_MENU.md) | Stats |
| Incidencias | [docs/PROJECT_ISSUES_AND_FIXES.md](docs/PROJECT_ISSUES_AND_FIXES.md) | Tutorial |
| Pruebas | [docs/TESTING.md](docs/TESTING.md) | pytest servidor |

**Vista rápida:** [docs/CHARACTER_AND_WEAPON_OVERVIEW.md](docs/CHARACTER_AND_WEAPON_OVERVIEW.md)

### Todos los módulos

| Archivo | Resumen |
|---------|---------|
| [docs/AUTOLOAD_AND_UI.md](docs/AUTOLOAD_AND_UI.md) | Autoload, pausa, UI |
| [docs/SCRIPT_LAYOUT.md](docs/SCRIPT_LAYOUT.md) | `Script/` |
| [docs/APIManager.md](docs/APIManager.md) | Cliente HTTP |
| [docs/CharacterDataManager.md](docs/CharacterDataManager.md) | restore / save |
| [docs/LOCAL_AND_CLOUD_SAVE.md](docs/LOCAL_AND_CLOUD_SAVE.md) | `.lcs` |
| [docs/SaveManager.md](docs/SaveManager.md) | Ajustes |
| [docs/GameDataManager.md](docs/GameDataManager.md) | game-data |
| [docs/INVENTORY.md](docs/INVENTORY.md) | Inventario |
| [docs/WEAPON_SYSTEM.md](docs/WEAPON_SYSTEM.md) | Armas |
| [docs/SKILL_SYSTEM.md](docs/SKILL_SYSTEM.md) | Habilidades |
| [docs/PLAYER_CAMERA_AND_MOVEMENT.md](docs/PLAYER_CAMERA_AND_MOVEMENT.md) | Cámara |
| [docs/COLLISION_LAYERS.md](docs/COLLISION_LAYERS.md) | Capas |
| [docs/DAMAGE_SYSTEM.md](docs/DAMAGE_SYSTEM.md) | Daño |
| [docs/ENEMY_SYSTEM.md](docs/ENEMY_SYSTEM.md) | Enemigos |
| [docs/EXPERIENCE_SYSTEM.md](docs/EXPERIENCE_SYSTEM.md) | EXP |
| [docs/GENE_SYSTEM.md](docs/GENE_SYSTEM.md) | Genes |
| [docs/HAZARD_SYSTEM_ALIGNMENT.md](docs/HAZARD_SYSTEM_ALIGNMENT.md) | Hazard |
| [docs/CHARACTER_MENU.md](docs/CHARACTER_MENU.md) | Menú |
| [docs/CHARACTER_AND_WEAPON_OVERVIEW.md](docs/CHARACTER_AND_WEAPON_OVERVIEW.md) | Resumen |
| [docs/PROJECT_ISSUES_AND_FIXES.md](docs/PROJECT_ISSUES_AND_FIXES.md) | Issues |
| [docs/TESTING.md](docs/TESTING.md) | Tests |
