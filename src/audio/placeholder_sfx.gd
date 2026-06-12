class_name PlaceholderSfx
extends RefCounted
## Процедурные ВРЕМЕННЫЕ звуки (BRIEF Section 6: допустимы с тегом PLACEHOLDER_).
## К M4 каждый ключ заменяется реальным файлом по ASSET_MANIFEST.md — имена
## ключей совпадают со slot_id манифеста, где это возможно.

const RATE: int = 22050

static func build_library() -> Dictionary:
	var lib: Dictionary = {}
	var steps: Array[AudioStream] = []
	for i: int in 6:
		steps.append(_wav(_footstep(0.07 + 0.02 * float(i % 3), 0.1 + 0.04 * float(i))))
	lib[&"PLACEHOLDER_footstep_concrete"] = steps
	lib[&"PLACEHOLDER_note_wire"] = [_wav(_wire_note())] as Array[AudioStream]
	lib[&"PLACEHOLDER_glitch"] = [_wav(_noise_burst(0.13, 0.42))] as Array[AudioStream]
	lib[&"PLACEHOLDER_rewind"] = [_wav(_rewind())] as Array[AudioStream]
	lib[&"PLACEHOLDER_door_slam"] = [_wav(_slam(55.0)), _wav(_slam(47.0))] as Array[AudioStream]
	var breaths: Array[AudioStream] = []
	for i: int in 3:
		breaths.append(_wav(_breath(0.6 + 0.1 * float(i))))
	lib[&"PLACEHOLDER_breath"] = breaths
	lib[&"PLACEHOLDER_amb_l1"] = [_wav(_ambience_loop(4.0), true)] as Array[AudioStream]
	lib[&"PLACEHOLDER_amb_l2"] = [_wav(_ambience_l2(8.0), true)] as Array[AudioStream]
	lib[&"PLACEHOLDER_amb_l3"] = [_wav(_ambience_l3(6.0), true)] as Array[AudioStream]
	lib[&"PLACEHOLDER_sting"] = [_wav(_sting())] as Array[AudioStream]
	lib[&"PLACEHOLDER_lamp_click"] = [_wav(_lamp_click())] as Array[AudioStream]
	return lib

# ------------------------------------------------------------- генераторы

static func _footstep(duration: float, lowpass: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	var y := 0.0
	for i: int in n:
		var t := float(i) / float(n)
		var x := rng.randf_range(-1.0, 1.0)
		y += lowpass * (x - y)
		out[i] = y * pow(1.0 - t, 3.0) * 0.9
	return out

static func _wire_note() -> PackedFloat32Array:
	var n := int(1.4 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t := float(i) / float(RATE)
		out[i] = sin(TAU * 1318.0 * t) * exp(-5.0 * t) * 0.28 \
			+ sin(TAU * 2659.0 * t) * exp(-9.0 * t) * 0.09
	return out

static func _noise_burst(duration: float, amp: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	for i: int in n:
		out[i] = rng.randf_range(-amp, amp)
	return out

static func _rewind() -> PackedFloat32Array:
	var n := int(1.1 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	var y := 0.0
	for i: int in n:
		var t := float(i) / float(RATE)
		var x := rng.randf_range(-1.0, 1.0)
		y += 0.35 * (x - y)
		var warble := 0.55 + 0.45 * sin(TAU * 13.0 * t * (1.0 + t))
		out[i] = y * warble * 0.4 + sin(TAU * (300.0 + 1400.0 * t) * t) * 0.07
	return out

static func _slam(freq: float) -> PackedFloat32Array:
	var n := int(0.55 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	for i: int in n:
		var t := float(i) / float(RATE)
		out[i] = sin(TAU * freq * t) * exp(-11.0 * t) * 0.8 \
			+ rng.randf_range(-1.0, 1.0) * exp(-32.0 * t) * 0.35
	return out

static func _breath(duration: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	var y := 0.0
	for i: int in n:
		var t := float(i) / float(n)
		var x := rng.randf_range(-1.0, 1.0)
		y += 0.06 * (x - y)
		out[i] = y * pow(sin(PI * t), 1.5) * 1.6
	return out

static func _ambience_loop(duration: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	var brown := 0.0
	var wind := 0.0
	for i: int in n:
		var t := float(i) / float(RATE)
		brown = clampf(brown * 0.997 + rng.randf_range(-1.0, 1.0) * 0.08, -1.0, 1.0)
		wind += 0.002 * (rng.randf_range(-1.0, 1.0) - wind)
		out[i] = brown * 0.22 + wind * 2.2 * (0.6 + 0.4 * sin(TAU * 0.11 * t)) \
			+ sin(TAU * 50.0 * t) * 0.025
	# плавный кроссфейд краёв, чтобы луп не щёлкал
	var fade := int(0.05 * RATE)
	for i: int in fade:
		var k := float(i) / float(fade)
		out[i] *= k
		out[n - 1 - i] *= k
	return out

## L2: стоны здания и стуки труб (вплывает на средней Tension).
static func _ambience_l2(duration: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	var groan := 0.0
	for i: int in n:
		var t := float(i) / float(RATE)
		groan += 0.0012 * (rng.randf_range(-1.0, 1.0) - groan)
		var sample := groan * 14.0 * (0.5 + 0.5 * sin(TAU * 0.07 * t))
		for knock_t: float in [1.7, 4.2, 6.9]:
			var dt := t - knock_t
			if dt >= 0.0 and dt < 0.7:
				sample += sin(TAU * 82.0 * dt) * exp(-9.0 * dt) * 0.5
		out[i] = sample
	_fade_edges(out)
	return out

## L3: саб-дрон с биением + давление воздуха (верхняя треть Tension).
static func _ambience_l3(duration: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	var air := 0.0
	for i: int in n:
		var t := float(i) / float(RATE)
		air += 0.004 * (rng.randf_range(-1.0, 1.0) - air)
		# 38 и 41.667 Гц — целое число периодов на 6 c: луп без щелчка.
		out[i] = (sin(TAU * 38.0 * t) + sin(TAU * 41.666667 * t)) * 0.17 \
			+ air * 1.6 * (0.6 + 0.4 * sin(TAU * 0.17 * t))
	return out

## Жёсткий стингер скер-слота 1: нисходящий металлический скрежет.
static func _sting() -> PackedFloat32Array:
	var n := int(0.9 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	var phase := 0.0
	for i: int in n:
		var t := float(i) / float(RATE)
		var k := t / 0.9
		var freq := lerpf(2600.0, 620.0, pow(k, 0.6))
		phase += TAU * freq / float(RATE)
		var env := minf(t / 0.012, 1.0) * pow(1.0 - k, 1.3)
		var sample := (sin(phase) * 0.7 + rng.randf_range(-1.0, 1.0) * 0.45) * env
		out[i] = clampf(sample * 1.5, -0.95, 0.95)   # лёгкий клип — грязнее
	return out

## Щелчок гаснущей лампы (скер-слот 2, финал).
static func _lamp_click() -> PackedFloat32Array:
	var n := int(0.09 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	for i: int in n:
		var t := float(i) / float(RATE)
		var click := (0.85 if i < 5 else 0.0) * (1.0 if i % 2 == 0 else -1.0)
		out[i] = click + sin(TAU * 64.0 * t) * exp(-40.0 * t) * 0.5 \
			+ rng.randf_range(-1.0, 1.0) * exp(-90.0 * t) * 0.3
	return out

static func _fade_edges(samples: PackedFloat32Array) -> void:
	var fade := int(0.05 * RATE)
	var n := samples.size()
	for i: int in fade:
		var k := float(i) / float(fade)
		samples[i] *= k
		samples[n - 1 - i] *= k

static func _wav(samples: PackedFloat32Array, looped: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream
