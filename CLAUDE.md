# CLAUDE.md — состояние проекта «ЭТАЖ 9»

> **Ритуал начала сессии (BRIEF Section 11):** прочитай этот файл целиком +
> docs/BRIEF.md (мастер-документ) + текущий майлстоун в BRIEF Section 10.
> Затем — короткий план, затем работа. Не переспрашивай решённое брифом.

## Статус

- **Текущий майлстоун:** M1 — Vertical Slice Core: код готов, GUT 14/14,
  smoke PASS, скриншоты сняты. **DoD M1 ждёт оператора**: личный плейтест +
  «незнакомец за 10 минут понимает правило» (docs/PLAYTEST_M1.md).
- M0 принят де-факто (M0-сборка работала у оператора после D-006).
- Теги: `m0`, `m1` локально; remote окружения не принимает refs/tags (403) —
  оператор вешает теги сам.
- **Следующий:** M2 — Content & Director (все 15 аномалий, relief valves,
  silence events, 2 скер-слота, скелет концовки, кривая Tension).

## Что уже есть

**M0:** Godot 4.4 проект (рендер **GL Compatibility**, D-006 — Vulkan на
машине оператора рендерит чёрным), SubViewport 640×360 nearest + леттербокс,
автолоады EventBus → SettingsService → GameState → AudioDirector → Director,
шины Master/Music/Ambience/SFX/UI/Reverb, настройки user://settings.cfg,
debug-оверлей F3, export preset Windows.

**M1:** луп целиком —
- `src/systems/loop_manager.gd` — чистые вердикты (GUT).
- `src/anomalies/` — AnomalyDef (.tres в content/anomalies) + AnomalyEffect +
  AnomalySelector (seed-детерминизм, GUT). 6 аномалий: A1, B1, C1, D1, E3, F2.
- `src/world/flight_module.gd` — switchback-модуль (канон метрик в
  ARCHITECTURE.md «World metrics M1»); `chain_manager.gd` — тредмил 4 модулей,
  re-anchor под глитчем, reset-перемотка, финал на 9-м.
- Модель сегментов: Q(L) = площадка L + марш L+1 (ARCHITECTURE.md).
- `src/player/player.gd` — head bob+шаги в такт, dip, sway, спринт/стамина
  с дыханием, FOV-кик.
- `src/fx/transition_layer.gd` (глитч/перемотка/финал-карточка),
  `src/ui/subtitles.gd`, `src/audio/placeholder_sfx.gd` (процедурные
  PLACEHOLDER_-WAV через AudioDirector._library).
- GUT 9.4.0 в addons/gut (НЕ 9.5.0 — той нужен Godot 4.5+).

## Готчи / закреплённые решения (детали — ARCHITECTURE.md)

- **D-006:** рендер = gl_compatibility. Не переключать на Vulkan-методы.
- **D-007:** каждый commit маскируется VHS-глитчем; глитч не телеграфирует
  аномалию (он всегда). Reset = перемотка ~1.1 c, игрок заморожен.
- **D-001:** рампа по носам ступеней = постоянное stair-smoothing.
- Area-коллбеки физики → менять дерево только `call_deferred` (ChainManager).
- ChainManager строится по `EventBus.run_started` (после сидинга Director'а),
  не в собственном `_ready`.
- Тесты: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests
  -ginclude_subdirs -gexit`.
- Smoke: `ETAZH9_SMOKE=1` (+`ETAZH9_SEED=N`); скриншоты: `ETAZH9_SHOT=dir`
  (+`ETAZH9_POSE="x,y,z,yaw,pitch"`), под xvfb в контейнере.
- Шедулер дальних ваншотов Director'а живёт на ОТДЕЛЬНОМ RNG (_ambient_rng):
  основной RNG расходуется только AnomalySelector'ом — иначе ломается
  детерминизм вердиктного контента.
- Двери: {2·этаж+17, 2·этаж+18}; «№40» Жильца вне нумерации — намеренно.
- EventBus «unused signal» предупреждения — ожидаемы.

## Среда / инструменты

- Godot 4.4.1 stable; headless-бинарь в контейнере: /tmp/godot (качается с
  GitHub releases). Валидация: import → GUT → smoke → xvfb-скриншоты.
- Windows-экспорт из контейнера работает (шаблоны 4.4.1, rcedit нет — иконка
  дефолтная, не критично).

## План M2 (следующая сессия)

1. Остальные 9 аномалий (A2, A3, B2, B3, C2, C3, D2, E1, E2) — пропсы-носители
   уже частично в модуле (велосипед, глазки дверей — добавить).
2. Director: авторская кривая Tension, relief valves (≥2 спокойных пролёта
   после T3/reset), silence events (полная тишина 5–10 c перед T2/T3),
   гейт T3 финальной третью.
3. Скер-слоты 1 (E2-эскалация) и 2 (лампа+дыхание) — каркас.
4. Скелет концовки «Дом» (дверь приоткрыта, статичный кадр, лампа гаснет).
5. Тюнинг: ANOMALY_CHANCE, скорость, длина забега до 10–15 мин.
6. GUT на математику Director'а и гейты тиров.

## Оператору (Алексей)

- Как плейтестить M1 — **docs/PLAYTEST_M1.md** (DoD: незнакомец + правило).
- Шопинг-лист ассетов — ASSET_MANIFEST.md (закупка к M3).
