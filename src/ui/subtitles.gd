class_name Subtitles
extends CanvasLayer
## Субтитры (единственный HUD-элемент по брифу, Section 8): нижний центр,
## плавное появление/затухание. Слушает EventBus.subtitle_requested.

var _label: Label
var _tween: Tween

func _init() -> void:
	layer = 80

func _ready() -> void:
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_label.position.y -= 64.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override(&"font_size", 20)
	_label.add_theme_color_override(&"font_color", Color(0.85, 0.86, 0.82))
	_label.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_label.modulate.a = 0.0
	add_child(_label)
	EventBus.subtitle_requested.connect(_on_subtitle)

func _on_subtitle(text: String, duration: float) -> void:
	_label.text = text
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(maxf(duration, 0.5))
	_tween.tween_property(_label, "modulate:a", 0.0, 0.4)
