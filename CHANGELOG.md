# CHANGELOG — «ЭТАЖ 9»

Формат: [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/);
версии = теги майлстоунов (BRIEF Section 10).

## [m1] — 2026-06-12 — Vertical Slice Core

### Added
- **Loop Manager** (`src/systems/loop_manager.gd`) — чистый класс вердиктов
  `(аномалия, направление) → advance|reset`, отложенный вердикт через стенсил.
- **Каркас аномалий**: `AnomalyDef` (.tres-ресурсы), `AnomalyEffect`
  (pre_build/post_build/on_flight_entered), `AnomalySelector` (взвешенный,
  детерминированный по seed, без мгновенных повторов, гейт min_tension).
- **6 аномалий** (по одной на категорию): A1 обувь, B1 тринадцать ступеней,
  C1 тёплая лампа, D1 граффити «НЕ ПОДНИМАЙСЯ», E3 мокрые следы вниз,
  F2 субтитр без звука.
- **Switchback-кит** `flight_module.gd`: параметрический модуль (марш+площадка),
  двери с нумерацией от этажа, стенсил, перила, лампа, граффити, ящики,
  мусоропровод, окно, скрытые носители аномалий.
- **ChainManager**: тредмил 4 модулей, re-anchor мира под глитчем, рециклинг,
  reveal стенсила, reset-перемотка с заморозкой игрока, финал на 9-м этаже.
- **Контроллер M1**: head bob с шагами строго в такт, landing dip, sway от
  Tension, спринт + стамина со звуковым фидбеком (дыхание), FOV-кик.
- **Временный звук** (PLACEHOLDER_, процедурная генерация WAV): шаги ×6,
  нота-«струна» на стенсил, глитч, перемотка, дальние хлопки дверей,
  дыхание, эмбиент-луп L1. Всё через финальную архитектуру AudioDirector.
- **Субтитры** (единственный HUD) + шедулер дальних ваншотов Director'а
  (приучает к паре «звук+титр» — без этого F2 не читается).
- **GUT 9.4.0** (MIT) в addons/gut; 14 тестов: вердикты Loop Manager,
  детерминизм/гейты/повторы AnomalySelector. Все зелёные.
- Smoke-тест M1: телепорт-коммиты, проверка re-anchor (|y| ограничен).

### Changed
- Канон метрик: ступень 0.2×0.3, марш 2.4×3.6 м, модуль 5.1 м
  (потолок площадки ~2.3 м — место для B2). Номера квартир {2n+17, 2n+18}.
- D-001 закрыто: рампа принята как постоянное stair-smoothing.

### Removed
- M0-греябокс `greybox_flight.gd` (заменён китом).

## [m0.1] — 2026-06-12 — Renderer hotfix

## [m0.1] — 2026-06-12 — Renderer hotfix

### Changed
- Базовый рендер: Forward+ → **OpenGL Compatibility** (решение оператора,
  ARCHITECTURE.md D-006): на машине гейм-директора Vulkan-путь Godot
  (Forward+ и Mobile) рендерит освещаемые материалы чёрным; OpenGL работает.
  Forward+ доступен флагами `--rendering-method forward_plus --rendering-driver vulkan`.

### Added
- `src/dev/shot_check.gd` — рендер-диагностика (env `ETAZH9_SHOT=каталог`):
  PNG-дампы корневого окна и SubViewport + средняя яркость.

## [m0] — 2026-06-12 — Foundation

### Added
- Godot 4.4 проект: Forward+, главная сцена, иконка, тёмный boot splash.
- Дерево папок по BRIEF Section 4 (src/scenes/content/assets/shaders/ui/tests/docs).
- Автолоады-скелеты: EventBus (сигналы), SettingsService (user://settings.cfg,
  дефолты, громкости шин), GameState (этаж/seed/фаза), AudioDirector
  (пул 12 × AudioStreamPlayer3D, play_varied ±4% питч), Director
  (Tension 0..100, сидированный RNG).
- Аудио-шины: Master/Music/Ambience/SFX/UI + Reverb-send («бетонный» хвост).
- Low-res пайплайн: SubViewport 640×360 (опции 320×180/480×270) с
  nearest-neighbor апскейлом и леттербоксом.
- Минимальный FP-контроллер: ходьба с ускорением/замедлением, мышь+геймпад,
  FOV/чувствительность/инверсия из настроек.
- Процедурный CSG-греябокс модуля подъезда: 12 ступеней, две площадки,
  двери 35/36, две холодные лампы, окно; невидимая рампа для капсулы (D-001).
- Debug-оверлей (F3, только debug-сборки): FPS, этаж, фаза, seed, график Tension.
- Input map: WASD/стрелки, мышь, геймпад (стики/кнопки), Esc, F3.
- Export preset «Windows Desktop» (x86_64, embed_pck).
- Документация: BRIEF.md, CLAUDE.md, ARCHITECTURE.md (журнал решений D-001…D-005),
  ASSET_MANIFEST.md (заготовка шопинг-листа), docs/PLAYTEST_M0.md.

### Validation
- `godot --headless --import` и headless-прогон главной сцены в контейнере —
  без ошибок скриптов/сцен (см. PLAYTEST_M0). Замеры fps и Windows-сборка —
  на стороне оператора: контейнер не запускает оконные/Windows-билды.
