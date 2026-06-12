# CHANGELOG — «ЭТАЖ 9»

Формат: [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/);
версии = теги майлстоунов (BRIEF Section 10).

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
