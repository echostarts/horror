class_name Player
extends CharacterBody3D
## Минимальный FP-контроллер M0: ходьба + обзор. Полный game-feel-контроллер
## (head bob, landing dip, sway, стамина, честное сглаживание ступеней) — M1.

const WALK_SPEED: float = 2.4
const ACCEL: float = 14.0
const DECEL: float = 16.0
const GRAVITY: float = 12.0
const PITCH_LIMIT: float = 1.48          # ~85°
const MOUSE_LOOK_SCALE: float = 0.002    # px -> rad при sensitivity = 1.0
const GAMEPAD_LOOK_SPEED: float = 2.2    # rad/s при полном отклонении стика

var _pitch: float = 0.0
var _mouse_sensitivity: float = 0.6
var _invert_y: bool = false

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera

func _ready() -> void:
	floor_snap_length = 0.3
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_pull_settings()
	EventBus.setting_changed.connect(_on_setting_changed)

## Вызывается из Main (корневой viewport) — см. ARCHITECTURE.md, D-002.
func apply_look(relative: Vector2) -> void:
	var look_delta := relative * MOUSE_LOOK_SCALE * _mouse_sensitivity
	rotate_y(-look_delta.x)
	_apply_pitch(look_delta.y if not _invert_y else -look_delta.y)

func _physics_process(delta: float) -> void:
	_gamepad_look(delta)
	var input_dir := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var target := (basis * Vector3(input_dir.x, 0.0, input_dir.y)) * WALK_SPEED
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := ACCEL if target.length_squared() > horizontal.length_squared() else DECEL
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

func _gamepad_look(delta: float) -> void:
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if look == Vector2.ZERO:
		return
	rotate_y(-look.x * GAMEPAD_LOOK_SPEED * delta)
	var dy := look.y if not _invert_y else -look.y
	_apply_pitch(dy * GAMEPAD_LOOK_SPEED * delta)

func _apply_pitch(amount: float) -> void:
	_pitch = clampf(_pitch - amount, -PITCH_LIMIT, PITCH_LIMIT)
	_head.rotation.x = _pitch

func _on_setting_changed(_key: StringName, _value: Variant) -> void:
	_pull_settings()

func _pull_settings() -> void:
	_mouse_sensitivity = SettingsService.get_float(&"input/mouse_sensitivity")
	_invert_y = SettingsService.get_bool(&"input/invert_y")
	_camera.fov = SettingsService.get_float(&"video/fov")
