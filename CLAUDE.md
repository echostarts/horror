# CLAUDE.md — состояние проекта «ЭТАЖ 9»

> **Ритуал начала сессии (BRIEF Section 11):** прочитай этот файл целиком +
> docs/BRIEF.md (мастер-документ) + текущий майлстоун в BRIEF Section 10.
> Затем — короткий план, затем работа. Не переспрашивай решённое брифом.

## Статус

- **Текущий майлстоун:** M0 — Foundation: код готов, коммит `540bc10`.
  Тег `m0` создан локально, но remote этого окружения принимает пуш только
  в рабочую ветку (403 на refs/tags) — оператор: повесь тег `m0` на коммит
  M0 сам (`git tag -a m0 540bc10 && git push origin m0`).
  **DoD M0 ждёт подтверждения оператора** (прогулка по греябоксу при 60 fps
  в Windows-сборке — см. docs/PLAYTEST_M0.md). Контейнер разработки не может
  собрать/запустить Windows-билд, поэтому fps-цифры НЕ заявлены.
- **Следующий:** M1 — Vertical Slice Core (BRIEF Section 10).

## Что уже есть (M0)

- Godot 4.4 проект, рендер **OpenGL Compatibility** (D-006! Vulkan на машине
  оператора рендерит чёрным), главная сцена `scenes/main.tscn`.
- Низкое внутреннее разрешение: `SubViewportContainer (nearest)` + `SubViewport`
  640×360 (настройка `video/internal_height`: 180/270/360), леттербокс при ресайзе — `src/main.gd`.
- Автолоады (порядок важен): `EventBus` → `SettingsService` → `GameState` →
  `AudioDirector` → `Director`. Все в `src/autoload/`.
- `SettingsService`: user://settings.cfg, дефолты всех будущих настроек,
  громкости сразу применяются к шинам.
- Аудио-шины: Master / Music / Ambience / SFX / UI / Reverb (бетонный хвост,
  send-эмуляция — см. ARCHITECTURE.md D-004). `AudioDirector.play_varied()` —
  пул из 12 `AudioStreamPlayer3D`, ±4% питч.
- `src/player/player.gd` — минимальный FP-контроллер (ходьба/обзор/геймпад).
- `src/world/greybox_flight.gd` — процедурный CSG-модуль: 12 ступеней,
  2 площадки, 2 двери (35/36), 2 лампы, окно. Размеры = канонический референс.
- Debug-оверлей F3 (`src/dev/debug_overlay.gd`): FPS, этаж, фаза, seed,
  график Tension. Только при `OS.is_debug_build()`.
- Export preset «Windows Desktop» (`export_presets.cfg`), embed_pck.
- Input map: WASD/стрелки + мышь + геймпад (стики, Start=пауза), F3, Esc.

## Готчи / закреплённые решения (подробно — ARCHITECTURE.md)

- **D-001:** ступени греябокса — визуальные; капсулу несёт невидимая рампа
  `StairRamp` по линии носов ступеней. В M1 заменить честным stair-smoothing.
- **D-002:** мышиный look обрабатывает `src/main.gd` (корневой viewport) и
  пробрасывает в `Player.apply_look()` — иначе масштаб SubViewportContainer
  влиял бы на чувствительность.
- **D-003:** debug-оверлей не «компилируется out» (GDScript), а не
  инстанцируется в release. FPS проверять в debug-экспорте.
- **D-004:** в Godot нет aux-send'ов; reverb-хвост в M4 — дублированием
  позиционных ваншотов на шину Reverb вторым плеером пула.
- SubViewport: `audio_listener_enable_3d = true` обязателен (камера внутри него).
- EventBus даёт предупреждения "unused signal" — ожидаемо, сигналы эмитят другие скрипты.
- `.uid`-сайдкары скриптов и `.import`-файлы коммитим; `.godot/` — в .gitignore.
- Никаких сырых `play()` в геймплее — только `AudioDirector.play_varied()`.

## Среда / инструменты

- Godot 4.4.x stable, GDScript со статической типизацией везде.
- GUT ещё НЕ установлен — ставим в начале M1 (AssetLib «GUT», MIT, в addons/gut).
- Валидация в headless-контейнере: `godot --headless --import` +
  `godot --headless --quit-after N` (см. docs/PLAYTEST_M0.md).

## План M1 (следующая сессия)

1. GUT в addons/ + первый тестовый прогон.
2. Loop Manager — чистый класс `(anomaly_state, direction) -> advance|reset`,
   GUT-тесты вердиктов; delayed verdict (трафарет на следующей площадке).
3. Греябокс-кит с switchback-чейнингом модулей (вверх/вниз, телепорт-луп).
4. Полный контроллер: head bob + синхронизация шагов, landing dip, sway,
   стамина (звуковой фидбек), stair smoothing (убрать D-001).
5. 6 аномалий — по одной на категорию (A1, B1, C1, D1, E3, F2 — обсудить выбор).
6. Reset-переход (VHS rewind можно заглушкой до M3).
7. Временный звук (PLACEHOLDER_ процедурные тоны) через AudioDirector.

## Оператору (Алексей)

- Шопинг-лист ассетов — ASSET_MANIFEST.md (пока заготовка, основной список к M3).
- Как проверить M0 — docs/PLAYTEST_M0.md.
