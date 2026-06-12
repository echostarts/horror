# ASSET_MANIFEST.md — «ЭТАЖ 9»

Схема — BRIEF Appendix B. Правила:
- Строка появляется **до** интеграции файла в проект.
- Плейсхолдеры в движке носят префикс `PLACEHOLDER_`.
- `license = UNKNOWN` допустимо в разработке, но к сайн-оффу M4 — только
  подтверждённые лицензии. CC0 предпочтительнее при равных затратах.
- Файлы НЕ выдумываются: нет файла → плейсхолдер в движке + строка здесь.

> **Оператору (Алексей):** колонка «источник + запрос» — твой шопинг-лист.
> Скачал → положи в папку из «notes» → поменяй status на `delivered` и впиши
> точную лицензию файла. Основная закупка — к M3; сейчас это заготовка.

| slot_id | category | description | exact specs | status | suggested source + search query | license | notes |
|---|---|---|---|---|---|---|---|
| font_ui_main | font | Основной UI/субтитры, кириллица | TTF/OTF, полная кириллица | placeholder | Google Fonts → «PT Sans» или «Golos Text»; запрос: `PT Sans font OFL download` | OFL (подтвердить) | → assets/fonts/. Пока — встроенный шрифт Godot (кириллицу покрывает) |
| font_stencil_floor | font | Трафарет номера этажа на стене | Кириллица+цифры, stencil | placeholder | запрос: `stencil cyrillic font free OFL` (Fontstorage/Google Fonts) | UNKNOWN | → assets/fonts/. Нужен к M3 |
| tex_concrete_wall | texture | Бетон/штукатурка стен подъезда | tileable, 512–1024 px, PNG (+normal желательно) | placeholder | ambientCG; запрос: `ambientCG concrete plaster` (напр. Concrete016, Plaster001) | CC0 (ожид.) | → assets/textures/. M3 |
| tex_concrete_floor | texture | Бетон ступеней и площадок | tileable, 512–1024 px | placeholder | ambientCG; запрос: `ambientCG concrete floor` | CC0 (ожид.) | M3 |
| tex_door_padded | texture | Обивка квартирной двери (дерматин) | 512–1024 px | placeholder | itch.io; запрос: `free PSX horror texture megapack` / `soviet door texture` | UNKNOWN | M3 |
| tex_metal_painted | texture | Крашеный металл (перила, ящики, мусоропровод) | tileable, 512 px | placeholder | ambientCG; запрос: `ambientCG painted metal` | CC0 (ожид.) | M3 |
| mdl_props_pack | model | Пропсы площадки (ящики, велосипед, обувь и т.п., бюджет ≤40 мешей) | low-poly PSX, OBJ/GLTF | placeholder | itch.io; запрос: `DevilsWork.shop low poly horror pack` / `Eastern European Urban Decay asset pack` | UNKNOWN | → assets/models/. M3; альтернатива — свой greybox + текстуры |
| sfx_footstep_concrete | sfx | Шаги по бетону, ≥6 вариаций | WAV 44.1 кГц mono | placeholder | Sonniss GameAudioGDC / freesound; запрос: `footsteps concrete interior single` | UNKNOWN | → assets/audio/. В M1 — процедурные PLACEHOLDER_-тоны |
| sfx_footstep_metal | sfx | Шаги по металлу, ≥6 вариаций | WAV 44.1 кГц mono | placeholder | freesound; запрос: `footsteps metal stairs single` | UNKNOWN | M4 |
| amb_l1_roomtone | sfx | L1: room tone + ветер в шахте | WAV stereo, луп ≥60 с | placeholder | freesound; запрос: `apartment building room tone hum wind loop` | UNKNOWN | M2 (заглушка) / M4 (финал) |
| amb_l2_building | sfx | L2: стоны здания, стук труб, дальний город | WAV, луп | placeholder | freesound; запрос: `pipe knock radiator building creak distant city night` | UNKNOWN | M2/M4 |
| amb_l3_drone | sfx | L3: суб-бас дрон, давление воздуха | WAV, луп | placeholder | freesound / itch.io; запрос: `dark ambient sub bass drone loop` | UNKNOWN | M2/M4 |
| mus_menu_drone | music | Дарк-эмбиент дрон главного меню | OGG, луп ≥2 мин | placeholder | itch.io; запрос: `free dark ambient horror music pack` | UNKNOWN | M3/M4 |
| mus_ending | music | Финальная пьеса («Дом») | OGG | placeholder | itch.io; запрос: `free dark ambient horror music pack` | UNKNOWN | M4 |

Сгенерированное нами (скрипты/шейдеры/греябокс/UI) в манифест не вносится —
оно не внешнее (BRIEF Section 7.3). Процедурные tileable-текстуры базового
слоя появятся отдельными строками, когда будут сгенерированы (M3).
