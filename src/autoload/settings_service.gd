extends Node
## Персистентные настройки игрока (user://settings.cfg).
## Ключи — StringName вида "секция/имя"; неизвестный ключ — ошибка программиста
## (assert в debug-сборках). Изменение громкостей сразу применяется к шинам.

const SETTINGS_PATH: String = "user://settings.cfg"

const DEFAULTS: Dictionary = {
	&"video/internal_height": 360,        # внутреннее разрешение: 180 / 270 / 360
	&"video/vhs_intensity": 1.0,          # 0..1 (M3)
	&"video/film_grain": 1.0,             # 0..1 (M3)
	&"video/fov": 85.0,                   # 70..100
	&"video/head_bob": true,
	&"video/brightness": 1.0,             # калибровка (M3)
	&"video/crt_curvature": false,
	&"video/photosensitivity_mode": false,
	&"audio/master_volume": 1.0,
	&"audio/music_volume": 1.0,
	&"audio/ambience_volume": 1.0,
	&"audio/sfx_volume": 1.0,
	&"audio/ui_volume": 1.0,
	&"input/mouse_sensitivity": 0.6,
	&"input/invert_y": false,
	&"meta/brightness_calibrated": false,
}

const _VOLUME_BUSES: Dictionary = {
	&"audio/master_volume": &"Master",
	&"audio/music_volume": &"Music",
	&"audio/ambience_volume": &"Ambience",
	&"audio/sfx_volume": &"SFX",
	&"audio/ui_volume": &"UI",
}

var _config := ConfigFile.new()

func _ready() -> void:
	var err := _config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("SettingsService: не удалось прочитать %s (код %d), используем дефолты" % [SETTINGS_PATH, err])
	_apply_all_volumes()

func get_setting(key: StringName) -> Variant:
	assert(DEFAULTS.has(key), "Неизвестный ключ настройки: %s" % key)
	var section_key := String(key).split("/", false, 1)
	return _config.get_value(section_key[0], section_key[1], DEFAULTS[key])

func get_float(key: StringName) -> float:
	return float(get_setting(key))

func get_int(key: StringName) -> int:
	return int(get_setting(key))

func get_bool(key: StringName) -> bool:
	return bool(get_setting(key))

func set_setting(key: StringName, value: Variant) -> void:
	assert(DEFAULTS.has(key), "Неизвестный ключ настройки: %s" % key)
	var section_key := String(key).split("/", false, 1)
	_config.set_value(section_key[0], section_key[1], value)
	var err := _config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsService: не удалось сохранить настройки (код %d)" % err)
	if _VOLUME_BUSES.has(key):
		_apply_volume(key)
	EventBus.setting_changed.emit(key, value)

func _apply_all_volumes() -> void:
	for key: StringName in _VOLUME_BUSES:
		_apply_volume(key)

func _apply_volume(key: StringName) -> void:
	var bus_name: StringName = _VOLUME_BUSES[key]
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("SettingsService: аудио-шина '%s' не найдена" % bus_name)
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(get_float(key), 0.0001)))
