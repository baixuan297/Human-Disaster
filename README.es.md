# Desastre Humano (cliente Godot)

[Español](README.es.md) | [中文](README.md)

Proyecto 3D en Godot 4.6 (`config/name="Desastre Humano"`, Forward Plus, 1920×1080). Documentación de sistemas: [docs/README.es.md](docs/README.es.md) (índice; el detalle técnico está en chino en los `.md` enlazados).

## Qué incluye

Combate 1ª/3ª persona, inventario (xuanBag), armas y habilidades, genes, experiencia y SYNC, IA de enemigos, tutorial, ajustes locales y guardado en nube (FastAPI).

## Requisitos

- Godot 4.6
- Guardado en línea: `StarshipBackend/PSQL_DH` (por defecto `http://127.0.0.1:8000`)
- La app Ionic usa Spring en 8080, no `APIManager.gd`

## Carpetas

`autoload/`, `Script/`, `Scene/`, `resource/`, `素材/`, `addons/xuanBag/`, `test/`, `docs/`

## Ejecución

1. Abrir `project.godot`, F5.
2. Con guardado: PostgreSQL + FastAPI ([../StarshipBackend/PSQL_DH/README.es.md](../StarshipBackend/PSQL_DH/README.es.md)).
3. URL: `autoload/APIManager.gd` → `API_BASE_URL`.

Red: [../StarshipBackend/docs/NETWORK_DEPLOYMENT.md](../StarshipBackend/docs/NETWORK_DEPLOYMENT.md).

## Autoload

`SettingData`, `SettingSignal`, `SaveManager`, `LocalCharacterSave`, `ApiManager`, `GameDataManager`, `GeneManager`, `CharacterDataManager`, `ExperienceRewards`, `EnemyLootService`, `InventoryManager`, `SceneManager`, `PauseManager`, `UiManager`, `UserManager`, `GBMssage`, `TutorialManager`, `AudioManager`, `SkillResourceRegistry`, `SkillManager`, `ScreenEffect`, `SignalBus`.

Detalle: [docs/AUTOLOAD_AND_UI.md](docs/AUTOLOAD_AND_UI.md) (chino).

## Teclas

WASD, Espacio, Mayús, Ctrl, ratón, B/C/Q/E/X/F (ver README chino).

## Pruebas

`test/api_test.tscn` — [../StarshipBackend/docs/TESTING.md](../StarshipBackend/docs/TESTING.md).

## Enlaces

- [docs/README.es.md](docs/README.es.md)
- [../README.es.md](../README.es.md)
