# ARCHITECTURE.md — «ЭТАЖ 9»

Живой документ. Обновляется каждую сессию (BRIEF Section 4).

## Обзор

Godot 4.4+, Forward+, GDScript со статической типизацией. Сигналы вместо
полупериодического опроса; контент — данные (Resource), композиция сцен
вместо наследования. Сложность проекта живёт в «ощущении», не в алгоритмах —
код скучный и отлаживаемый.

## Автолоады (порядок инициализации фиксирован)

| # | Имя | Файл | Ответственность |
|---|-----|------|-----------------|
| 1 | `EventBus` | src/autoload/event_bus.gd | Только сигналы. Вся межсистемная связь. |
| 2 | `SettingsService` | src/autoload/settings_service.gd | user://settings.cfg, дефолты, применение громкостей к шинам. |
| 3 | `GameState` | src/autoload/game_state.gd | Этаж/seed/фаза/стрик. Чистые данные. Мутирует Loop Manager (M1). |
| 4 | `AudioDirector` | src/autoload/audio_director.gd | Пул AudioStreamPlayer3D, `play_varied()`, имена шин. |
| 5 | `Director` | src/autoload/director.gd | Tension 0..100, сидированный RNG (детерминизм). Полная логика — M2. |

Порядок: EventBus первым (все на него подписываются), SettingsService раньше
потребителей настроек, Director последним (зависит от EventBus).

## Поток сигналов (M0-срез)

```
Main._ready() ──► GameState.start_run() ──► EventBus.run_started(seed)
                                                  └─► Director: seed RNG, tension = 0
SettingsService.set_setting() ──► EventBus.setting_changed(key, value)
       ├─► Main: video/internal_height → пересоздать размер SubViewport
       └─► Player: чувствительность / инверсия / FOV
Director.tension (setter) ──► EventBus.tension_changed ──► (M2+: ambience mix, lamps…)
```

## Пайплайн рендера (низкое разрешение)

```
Window (1280×720, resizable)
└── Main (Node, src/main.gd)
    ├── GameViewportContainer (SubViewportContainer, texture_filter = NEAREST,
    │   │                      stretch = false; scale/position задаёт Main)
    │   └── GameViewport (SubViewport 640×360 | 480×270 | 320×180,
    │       │             audio_listener_enable_3d = true  ← ОБЯЗАТЕЛЬНО)
    │       └── World (Node3D): WorldEnvironment, Flight, Player
    └── DebugOverlay (CanvasLayer, только debug-сборки) — рисуется в нативном
        разрешении, НЕ внутри low-res вьюпорта (читаемость).
```

UI (субтитры, меню) живёт вне SubViewport — в нативном разрешении.
Масштабирование: единый float-скейл по меньшей стороне + леттербокс;
целочисленный скейл не форсируем.

## World metrics (канон, из greybox_flight.gd)

- Ступень: подъём **0.175 м**, проступь **0.28 м**, **12 ступеней** на пролёт
  (аномалия B1 = 13).
- Пролёт: подъём 2.1 м, длина 3.36 м. Ширина коридора **2.2 м**.
- Площадка: глубина **1.5 м**. Потолок: +**2.5 м** над верхней площадкой
  (аномалия B2 = −15%).
- Дверь: 0.9 × 2.05 м. Игрок: капсула r=0.3, h=1.7, глаза на 1.62 м.

## Аудио-шины

```
Master ← Music, Ambience, SFX, UI, Reverb(−6 dB, AudioEffectReverb:
                                          room 1.0, predelay 60 ms, dry 0)
```

Громкости шин управляются SettingsService (`audio/*_volume`).
Дакинг стингеров (−6 dB Ambience, релиз 0.8 с) — M2/M4, через tween в AudioDirector.

## Журнал решений

- **D-001 (M0, временно).** Ступени CSG — визуальные; коллизия — невидимый
  наклонный `StairRamp` точно по линии носов ступеней. Причина: капсула не
  умеет step-up 0.175 м (угол контакта > floor_max_angle). Снести в M1 при
  реализации stair-step smoothing из Section 8.
- **D-002 (M0, постоянно).** Сырая мышь обрабатывается в корневом viewport
  (`src/main.gd`) и пробрасывается в `Player.apply_look()`. Причина: события,
  проходящие через SubViewportContainer, трансформируются его масштабом —
  чувствительность зависела бы от размера окна.
- **D-003 (M0, постоянно).** «Compiled out» для debug-оверлея в GDScript
  недостижимо буквально; гейтим инстанцирование `OS.is_debug_build()`.
  Release-экспорт оверлей не создаёт. Перед публичной раздачей билда можно
  дополнительно исключить `src/dev/*` фильтром экспорта.
- **D-004 (M0, решение для M4).** В Godot нет per-bus aux-send'ов. Реверб-хвост
  для позиционных SFX делаем дублированием ваншота на шину Reverb вторым
  плеером пула (стандартный обходной путь). Реализация в M4.
- **D-005 (M0).** Greybox-модуль прямой (площадка→пролёт→площадка). Switchback
  (разворот на 180°) и чейнинг модулей проектируются в M1 вместе с Loop Manager.

## Тесты

GUT ставится в M1. Объекты тестирования (BRIEF Section 4): вердикты Loop
Manager, математика Director, выбор аномалий, детерминизм seed. Loop Manager
пишется как чистый класс без ссылок на сцену — тестируется без рантайма.

## Производительность

Бюджет: 60 fps на интегрированной графике при 640×360; ноль аллокаций на кадр
в hot path (пул аудиоплееров уже соблюдает это; `play_varied` не аллоцирует).
Профилировка после каждого майлстоуна. Заявленных цифр пока НЕТ — контейнер
разработки headless, замеры делает оператор (docs/PLAYTEST_M0.md).
