class_name Player
extends CharacterBody3D
## FP-контроллер M1: ходьба/спринт с кривыми разгона, head bob с синком шагов,
## landing dip, дыхательный sway от Tension, стамина со звуковым (не UI)
## фидбеком, FOV-кик спринта. Обзор: мышь приходит из Main.apply_look (D-002),
## правый стик — локально.

const WALK_SPEED: float = 2.4
const SPRINT_SPEED: float = 3.7
const ACCEL: float = 14.0
const DECEL: float = 16.0
const GRAVITY: float = 12.0
const PITCH_LIMIT: float = 1.48          # ~85°
const MOUSE_LOOK_SCALE: float = 0.002
const GAMEPAD_LOOK_SPEED: float = 2.2

const STRIDE_LENGTH: float = 0.78        # м/шаг: фаза боба = метроном шагов
const BOB_AMP_Y: float = 0.042
const BOB_AMP_X: float = 0.024
const DIP_RECOVERY: float = 6.0
const FOV_KICK: float = 6.0
const STAMINA_DRAIN: float = 1.0 / 4.5   # сек спринта до нуля
const STAMINA_REGEN: float = 1.0 / 7.0

var _pitch: float = 0.0
var _mouse_sensitivity: float = 0.6
var _invert_y: bool = false
var _base_fov: float = 85.0
var _head_bob_enabled: bool = true

var _bob_phase: float = 0.0
var _dip: float = 0.0
var _was_on_floor: bool = true
var _sway_time: float = 0.0
var _stamina: float = 1.0
var _winded: bool = false
var _breath_timer: float = 0.0
var _shake: float = 0.0
var _shake_rng := RandomNumberGenerator.new()

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera

func _ready() -> void:
	add_to_group(&"player")
	floor_snap_length = 0.3
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_pull_settings()
	EventBus.setting_changed.connect(_on_setting_changed)

## Вызывается из Main (корневой viewport) — см. ARCHITECTURE.md, D-002.
func apply_look(relative: Vector2) -> void:
	var look_delta := relative * MOUSE_LOOK_SCALE * _mouse_sensitivity
	rotate_y(-look_delta.x)
	_apply_pitch(look_delta.y if not _invert_y else -look_delta.y)

## Жёсткий перенос мира при re-anchor тредмила (вызывает ChainManager).
func teleport(delta_transform: Transform3D) -> void:
	global_transform = delta_transform * global_transform
	velocity = delta_transform.basis * velocity

## Микро-шейк на стингерах (Section 8: ≤0.3 c, с капом).
func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 0.3)

func _physics_process(delta: float) -> void:
	_gamepad_look(delta)
	var sprinting := _update_stamina(delta)
	var input_dir := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	var target := (basis * Vector3(input_dir.x, 0.0, input_dir.y)) * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := ACCEL if target.length_squared() > horizontal.length_squared() else DECEL
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var falling := not is_on_floor()
	if falling:
		velocity.y -= GRAVITY * delta
	else:
		if not _was_on_floor and velocity.y < -2.0:
			_dip = clampf(-velocity.y * 0.022, 0.03, 0.09)  # landing dip
		velocity.y = minf(velocity.y, 0.0)
	_was_on_floor = not falling
	move_and_slide()
	_update_camera_feel(delta, horizontal.length(), sprinting)

# ------------------------------------------------------------- камера/фил

func _update_camera_feel(delta: float, ground_speed: float, sprinting: bool) -> void:
	_sway_time += delta
	var moving := ground_speed > 0.3 and is_on_floor()
	if moving and _head_bob_enabled:
		var prev := _bob_phase
		_bob_phase += ground_speed * delta * PI / STRIDE_LENGTH
		if int(prev / PI) != int(_bob_phase / PI):
			AudioDirector.play_footstep(global_position)  # шаг строго в такт бобу
	elif moving:
		# Боб выключен в настройках — шаги по таймеру той же фазы, но камера не качается.
		var prev_silent := _bob_phase
		_bob_phase += ground_speed * delta * PI / STRIDE_LENGTH
		if int(prev_silent / PI) != int(_bob_phase / PI):
			AudioDirector.play_footstep(global_position)
	_dip = maxf(_dip - DIP_RECOVERY * _dip * delta, 0.0)

	var tension01 := Director.tension / 100.0
	var bob_y := sin(_bob_phase * 2.0) * BOB_AMP_Y if _head_bob_enabled and moving else 0.0
	var bob_x := sin(_bob_phase) * BOB_AMP_X if _head_bob_enabled and moving else 0.0
	var sway_x := sin(_sway_time * 0.7) * 0.006 * tension01
	var sway_y := sin(_sway_time * 1.1) * 0.004 * tension01
	var shake_x := 0.0
	var shake_y := 0.0
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		shake_x = _shake_rng.randf_range(-1.0, 1.0) * _shake * 0.045
		shake_y = _shake_rng.randf_range(-1.0, 1.0) * _shake * 0.045
	_camera.position = Vector3(bob_x + sway_x + shake_x, bob_y + sway_y - _dip + shake_y, 0.0)
	_camera.rotation.z = sin(_sway_time * 0.9) * 0.0035 * tension01 \
		+ (_shake_rng.randf_range(-1.0, 1.0) * _shake * 0.03 if _shake > 0.0 else 0.0)
	var target_fov := _base_fov + (FOV_KICK if sprinting else 0.0)
	_camera.fov = lerpf(_camera.fov, target_fov, minf(6.0 * delta, 1.0))

# ---------------------------------------------------------------- стамина

func _update_stamina(delta: float) -> bool:
	var wants_sprint := Input.is_action_pressed(&"sprint") \
		and Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back").y < -0.1
	var sprinting := wants_sprint and not _winded and _stamina > 0.02
	if sprinting:
		_stamina = maxf(_stamina - STAMINA_DRAIN * delta, 0.0)
		if _stamina <= 0.02:
			_winded = true
	else:
		_stamina = minf(_stamina + STAMINA_REGEN * delta, 1.0)
		if _winded and _stamina > 0.4:
			_winded = false
	# Звуковой фидбек вместо полоски (BRIEF Section 8): дыхание учащается.
	var effort := maxf(1.0 - _stamina, Director.tension / 100.0 * 0.6)
	_breath_timer -= delta
	if _breath_timer <= 0.0 and effort > 0.25:
		_breath_timer = lerpf(4.5, 1.1, effort)
		AudioDirector.play_breath(effort)
	return sprinting

# ------------------------------------------------------------------ обзор

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
	_base_fov = SettingsService.get_float(&"video/fov")
	_head_bob_enabled = SettingsService.get_bool(&"video/head_bob")
	_camera.fov = _base_fov
