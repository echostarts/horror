extends Node
## Глобальная шина сигналов. Вся межсистемная коммуникация идёт через неё:
## системы подключаются в _ready() и эмитят через EventBus.<signal>.emit(...).
## Здесь живут ТОЛЬКО сигналы — никакой логики.
##
## Примечание: предупреждения "unused signal" для этого файла ожидаемы —
## сигналы эмитятся из других скриптов.

# --- Ход забега ---
signal run_started(seed_value: int)
signal run_ended
signal floor_committed(direction: int)         # игрок пересёк порог площадки; -1 вниз / +1 вверх
signal verdict_resolved(correct: bool, floor: int)
signal floor_revealed(floor: int)              # отложенный показ трафарета на СЛЕДУЮЩЕЙ площадке
signal run_reset                               # ошибка -> сброс на первый этаж

# --- Аномалии ---
signal anomaly_spawned(anomaly_id: StringName)
signal anomaly_cleared(anomaly_id: StringName)

# --- Director ---
signal tension_changed(value: float)           # 0..100
signal silence_event_started(duration: float)
signal silence_event_ended
signal scare_triggered(slot: int)              # 1 или 2 (см. BRIEF Appendix A)

# --- UI ---
signal subtitle_requested(text: String, duration: float)

# --- Настройки / оболочка ---
signal setting_changed(key: StringName, value: Variant)
signal pause_toggled(paused: bool)
