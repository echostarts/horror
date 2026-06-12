class_name GreyboxFlight
extends Node3D
## Процедурный CSG-греябокс одного модуля подъезда (M0): нижняя площадка,
## пролёт из step_count ступеней, верхняя площадка с двумя дверями, лампы, окно.
## В M1 его сменит настоящий модульный кит; размеры отсюда — канонический
## метрический референс (ARCHITECTURE.md, «World metrics»).

@export var step_count: int = 12
@export var step_rise: float = 0.175
@export var step_run: float = 0.28
@export var corridor_width: float = 2.2
@export var landing_depth: float = 1.5
@export var ceiling_clearance: float = 2.5

func _ready() -> void:
	var wall_mat := _flat_material(Color(0.34, 0.37, 0.33))
	var floor_mat := _flat_material(Color(0.42, 0.42, 0.43))
	var step_mat := _flat_material(Color(0.47, 0.46, 0.45))
	var door_mat := _flat_material(Color(0.3, 0.22, 0.16))
	var lamp_mat := _emissive_material(Color(0.85, 0.93, 1.0), 2.5)
	var window_mat := _emissive_material(Color(0.1, 0.14, 0.22), 1.2)

	var run_total := step_run * float(step_count)
	var rise_total := step_rise * float(step_count)
	var stairs_z0 := landing_depth
	var stairs_z1 := landing_depth + run_total
	var module_z1 := stairs_z1 + landing_depth   # внутренняя плоскость торцевой стены
	var ceiling_y := rise_total + ceiling_clearance
	var w := corridor_width

	# --- Площадки ---
	_box("LowerLanding", Vector3(w + 0.2, 0.1, landing_depth + 0.2),
		Vector3(0.0, -0.05, landing_depth * 0.5 - 0.05), floor_mat, true)
	_box("UpperLanding", Vector3(w + 0.2, 0.1, landing_depth + 0.1),
		Vector3(0.0, rise_total - 0.05, stairs_z1 + landing_depth * 0.5 + 0.05), floor_mat, true)

	# --- Ступени (визуальные; капсулу несёт невидимая рампа — заменить в M1
	# на честное сглаживание ступеней) ---
	for i: int in step_count:
		var height := step_rise * float(i + 1)
		_box("Step%d" % (i + 1), Vector3(w, height, step_run),
			Vector3(0.0, height * 0.5, stairs_z0 + step_run * (float(i) + 0.5)), step_mat, false)
	_add_stair_ramp(w, run_total, rise_total, stairs_z0)

	# --- Коробка ---
	var shell_h := ceiling_y + 0.3
	var shell_z := module_z1 + 0.2
	_box("WallLeft", Vector3(0.1, shell_h, shell_z),
		Vector3(-(w * 0.5 + 0.05), shell_h * 0.5 - 0.15, module_z1 * 0.5), wall_mat, true)
	_box("WallRight", Vector3(0.1, shell_h, shell_z),
		Vector3(w * 0.5 + 0.05, shell_h * 0.5 - 0.15, module_z1 * 0.5), wall_mat, true)
	_box("WallStart", Vector3(w + 0.2, shell_h, 0.1),
		Vector3(0.0, shell_h * 0.5 - 0.15, -0.05), wall_mat, true)
	_box("WallEnd", Vector3(w + 0.2, shell_h, 0.1),
		Vector3(0.0, shell_h * 0.5 - 0.15, module_z1 + 0.05), wall_mat, true)
	_box("Ceiling", Vector3(w + 0.2, 0.1, shell_z),
		Vector3(0.0, ceiling_y + 0.05, module_z1 * 0.5), wall_mat, true)

	# --- Квартирные двери на торцевой стене ---
	for door: Dictionary in [{"x": -0.55, "number": "35"}, {"x": 0.55, "number": "36"}]:
		var door_x: float = door["x"]
		var door_number: String = door["number"]
		_box("Door%s" % door_number, Vector3(0.9, 2.05, 0.08),
			Vector3(door_x, rise_total + 1.025, module_z1 - 0.04), door_mat, true)
		var label := Label3D.new()
		label.name = "DoorNumber%s" % door_number
		label.text = door_number
		label.font_size = 64
		label.pixel_size = 0.003
		label.modulate = Color(0.85, 0.82, 0.7)
		label.position = Vector3(door_x, rise_total + 2.3, module_z1 - 0.1)
		label.rotation.y = PI
		add_child(label)

	# --- Лампы (холодный люминесцент, BRIEF Section 5) ---
	_box("LampUpper", Vector3(0.5, 0.06, 0.14),
		Vector3(0.0, ceiling_y - 0.03, stairs_z1 + landing_depth * 0.5), lamp_mat, false)
	var upper_light := OmniLight3D.new()
	upper_light.name = "LampUpperLight"
	upper_light.position = Vector3(0.0, ceiling_y - 0.25, stairs_z1 + landing_depth * 0.5)
	upper_light.light_color = Color(0.82, 0.9, 1.0)
	upper_light.light_energy = 1.6
	upper_light.omni_range = 8.0
	upper_light.shadow_enabled = true
	add_child(upper_light)

	_box("LampLower", Vector3(0.5, 0.06, 0.14), Vector3(0.0, 2.5, 0.12), lamp_mat, false)
	var lower_light := OmniLight3D.new()
	lower_light.name = "LampLowerLight"
	lower_light.position = Vector3(0.0, 2.4, 0.5)
	lower_light.light_color = Color(0.82, 0.9, 1.0)
	lower_light.light_energy = 1.1
	lower_light.omni_range = 6.0
	add_child(lower_light)

	# --- Окно (ночь) над пролётом, правая стена ---
	_box("Window", Vector3(0.06, 1.2, 0.9),
		Vector3(w * 0.5 - 0.01, rise_total * 0.5 + 1.6, (stairs_z0 + stairs_z1) * 0.5),
		window_mat, false)

## Невидимая наклонная коллизия поверх ступеней: капсула M0 не умеет step-up,
## рампа проходит точно по линии носов ступеней. Удалить в M1.
func _add_stair_ramp(width: float, run_total: float, rise_total: float, z0: float) -> void:
	var body := StaticBody3D.new()
	body.name = "StairRamp"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.1, Vector2(run_total, rise_total).length())
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	var angle := atan2(rise_total, run_total)
	body.rotation.x = -angle
	var surface_mid := Vector3(0.0, rise_total * 0.5, z0 + run_total * 0.5)
	var surface_normal := Vector3(0.0, cos(angle), -sin(angle))
	body.position = surface_mid - surface_normal * (box.size.y * 0.5)

func _box(box_name: String, size: Vector3, pos: Vector3, mat: Material, collide: bool) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = box_name
	box.size = size
	box.position = pos
	box.material = mat
	box.use_collision = collide
	add_child(box)
	return box

func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	return mat

func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.5)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.9
	return mat
