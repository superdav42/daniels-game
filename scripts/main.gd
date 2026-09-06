extends Node2D

enum RaceState { COUNTDOWN, RACING, FINISHED }

const VIEW_SIZE := Vector2(720.0, 1280.0)
const PLAYER_Y := 965.0
const RACE_LENGTH := 3200.0
const CHECKPOINT_DISTANCE := 800.0
const ROAD_TOP := 118.0
const ROAD_SAMPLE := 64.0

var race_state := RaceState.COUNTDOWN
var countdown := 3.8
var race_time := 0.0
var world_distance := 0.0
var speed_kph := 0.0
var nitro := 100.0
var nitro_button_down := false
var is_boosting := false
var race_position := 6
var overtakes := 0
var collision_cooldown := 0.0
var checkpoint_index := 0
var announcement_time := 0.0
var road_shake := 0.0
var rivals: Array[Dictionary] = []

@onready var player: CharacterBody2D = $Player
@onready var position_label: Label = $Hud/PositionLabel
@onready var time_label: Label = $Hud/TimeLabel
@onready var speed_label: Label = $Hud/SpeedLabel
@onready var nitro_bar: ProgressBar = $Hud/NitroBar
@onready var progress_bar: ProgressBar = $Hud/ProgressBar
@onready var distance_label: Label = $Hud/DistanceLabel
@onready var countdown_label: Label = $Hud/CountdownLabel
@onready var announcement_label: Label = $Hud/AnnouncementLabel
@onready var result_panel: Panel = $Hud/ResultPanel
@onready var result_title: Label = $Hud/ResultPanel/ResultTitle
@onready var result_stats: Label = $Hud/ResultPanel/ResultStats
@onready var restart_button: Button = $Hud/ResultPanel/RestartButton
@onready var boost_button: Button = $Hud/BoostButton


func _ready() -> void:
	randomize()
	_build_rival_grid()
	_style_hud()
	boost_button.button_down.connect(_on_boost_down)
	boost_button.button_up.connect(_on_boost_up)
	restart_button.pressed.connect(_restart_race)
	player.global_position = Vector2(_road_center(PLAYER_Y), PLAYER_Y)
	_update_hud()
	queue_redraw()


func _process(delta: float) -> void:
	collision_cooldown = maxf(0.0, collision_cooldown - delta)
	announcement_time = maxf(0.0, announcement_time - delta)
	road_shake = maxf(0.0, road_shake - delta * 18.0)

	match race_state:
		RaceState.COUNTDOWN:
			_update_countdown(delta)
		RaceState.RACING:
			_update_race(delta)
		RaceState.FINISHED:
			speed_kph = move_toward(speed_kph, 0.0, 85.0 * delta)
			is_boosting = false

	player.set_drive_context(
		speed_kph / 330.0,
		_road_center(PLAYER_Y),
		_road_width(PLAYER_Y),
		is_boosting,
		race_state == RaceState.RACING
	)
	_update_hud()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_restart_race()


func _update_countdown(delta: float) -> void:
	countdown -= delta
	if countdown > 0.8:
		countdown_label.text = str(ceili(countdown - 0.8))
		countdown_label.modulate = Color.WHITE
	elif countdown > 0.0:
		countdown_label.text = "GO!"
		countdown_label.modulate = Color("ffda2d")
	else:
		race_state = RaceState.RACING
		countdown_label.hide()
		_show_announcement("HORIZON SPRINT", "Make every corner count")


func _update_race(delta: float) -> void:
	race_time += delta
	var road_center := _road_center(PLAYER_Y)
	var safe_half_width := _road_width(PLAYER_Y) * 0.5 - 54.0
	var off_road := absf(player.global_position.x - road_center) > safe_half_width
	var wants_brake := Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_DOWN)
	var wants_throttle := Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_UP)
	var target_speed := 228.0
	if wants_throttle:
		target_speed = 284.0
	elif wants_brake:
		target_speed = 112.0

	is_boosting = (Input.is_action_pressed("boost") or nitro_button_down) and nitro > 0.0 and not off_road
	if is_boosting:
		target_speed = 354.0
		nitro = maxf(0.0, nitro - 28.0 * delta)
	else:
		nitro = minf(100.0, nitro + 7.5 * delta)

	if off_road:
		target_speed = minf(target_speed, 142.0)
		road_shake = minf(5.0, road_shake + delta * 20.0)
		speed_kph = move_toward(speed_kph, target_speed, 155.0 * delta)
	else:
		speed_kph = move_toward(speed_kph, target_speed, (72.0 if speed_kph < target_speed else 96.0) * delta)

	world_distance += speed_kph / 3.6 * delta
	_update_rivals(delta)
	_check_checkpoints()
	_check_collisions()

	if world_distance >= RACE_LENGTH:
		_finish_race()


func _build_rival_grid() -> void:
	var names := ["MAYA", "LEO", "NOVA", "JAX", "ARIA"]
	var colors := [Color("ff4c61"), Color("47d7ff"), Color("ffb52e"), Color("a878ff"), Color("f5f7fa")]
	var lanes := [-0.55, 0.48, -0.12, 0.62, -0.62]
	var starts := [52.0, 92.0, 132.0, 172.0, 212.0]
	var pace := [230.0, 238.0, 246.0, 253.0, 260.0]
	for i in names.size():
		rivals.append({
			"name": names[i],
			"color": colors[i],
			"lane": lanes[i],
			"progress": starts[i],
			"pace": pace[i],
			"overtaken": false,
			"phase": randf_range(0.0, TAU),
		})


func _update_rivals(delta: float) -> void:
	for rival in rivals:
		var surge := sin(race_time * 0.55 + float(rival["phase"])) * 12.0
		var catch_up := clampf((world_distance - float(rival["progress"])) * 0.025, -10.0, 18.0)
		rival["progress"] = float(rival["progress"]) + (float(rival["pace"]) + surge + catch_up) / 3.6 * delta
		if not bool(rival["overtaken"]) and world_distance > float(rival["progress"]) + 12.0:
			rival["overtaken"] = true
			overtakes += 1
			nitro = minf(100.0, nitro + 16.0)
			_show_announcement("CLEAN PASS +%d" % (overtakes * 250), "+16 nitro")

	race_position = 1
	for rival in rivals:
		if float(rival["progress"]) > world_distance:
			race_position += 1


func _check_checkpoints() -> void:
	var reached := int(world_distance / CHECKPOINT_DISTANCE)
	if reached > checkpoint_index and world_distance < RACE_LENGTH:
		checkpoint_index = reached
		nitro = minf(100.0, nitro + 24.0)
		_show_announcement("CHECKPOINT %d/3" % checkpoint_index, "Nitro recharged")


func _check_collisions() -> void:
	if collision_cooldown > 0.0:
		return
	for rival in rivals:
		var relative := float(rival["progress"]) - world_distance
		if absf(relative) > 18.0:
			continue
		var rival_x := _rival_x(rival, PLAYER_Y - relative * 3.1)
		if absf(rival_x - player.global_position.x) < 52.0:
			collision_cooldown = 1.1
			speed_kph *= 0.58
			nitro = maxf(0.0, nitro - 20.0)
			road_shake = 10.0
			player.bump_away(signf(player.global_position.x - rival_x))
			_show_announcement("CONTACT", "Hold your line")
			break


func _finish_race() -> void:
	race_state = RaceState.FINISHED
	player.set_drive_context(0.0, _road_center(PLAYER_Y), _road_width(PLAYER_Y), false, false)
	result_panel.show()
	boost_button.hide()
	result_title.text = "P%d  FINISH" % race_position
	var rating := "PODIUM DRIVE" if race_position <= 3 else "SPRINT COMPLETE"
	result_stats.text = "%s\n\nTIME  %s\nOVERTAKES  %d\nTOP SPEED  354 KM/H" % [rating, _format_time(race_time), overtakes]
	_show_announcement("FINISH", "Great drive")


func _update_hud() -> void:
	position_label.text = "P%d / 6" % race_position
	time_label.text = _format_time(race_time)
	speed_label.text = "%03d" % roundi(speed_kph)
	nitro_bar.value = nitro
	progress_bar.value = clampf(world_distance / RACE_LENGTH * 100.0, 0.0, 100.0)
	distance_label.text = "%0.1f KM" % maxf(0.0, (RACE_LENGTH - world_distance) / 1000.0)
	announcement_label.visible = announcement_time > 0.0
	boost_button.modulate = Color("ffda2d") if is_boosting else Color.WHITE


func _style_hud() -> void:
	var dark_panel := StyleBoxFlat.new()
	dark_panel.bg_color = Color(0.025, 0.035, 0.055, 0.94)
	dark_panel.border_color = Color("ffda2d")
	dark_panel.set_border_width_all(2)
	dark_panel.corner_radius_top_left = 18
	dark_panel.corner_radius_top_right = 18
	dark_panel.corner_radius_bottom_left = 18
	dark_panel.corner_radius_bottom_right = 18
	result_panel.add_theme_stylebox_override("panel", dark_panel)

	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color(0.055, 0.075, 0.11, 0.9)
	button_style.border_color = Color(1.0, 0.85, 0.18, 0.85)
	button_style.set_border_width_all(3)
	button_style.corner_radius_top_left = 42
	button_style.corner_radius_top_right = 42
	button_style.corner_radius_bottom_left = 42
	button_style.corner_radius_bottom_right = 42
	boost_button.add_theme_stylebox_override("normal", button_style)
	boost_button.add_theme_stylebox_override("hover", button_style)
	boost_button.add_theme_stylebox_override("pressed", button_style)

	var nitro_fill := StyleBoxFlat.new()
	nitro_fill.bg_color = Color("ffcf24")
	nitro_fill.corner_radius_top_left = 6
	nitro_fill.corner_radius_top_right = 6
	nitro_fill.corner_radius_bottom_left = 6
	nitro_fill.corner_radius_bottom_right = 6
	nitro_bar.add_theme_stylebox_override("fill", nitro_fill)
	var progress_fill := nitro_fill.duplicate()
	progress_fill.bg_color = Color("40d9ff")
	progress_bar.add_theme_stylebox_override("fill", progress_fill)


func _show_announcement(title: String, subtitle: String) -> void:
	announcement_label.text = "%s\n%s" % [title, subtitle]
	announcement_time = 2.2


func _on_boost_down() -> void:
	nitro_button_down = true


func _on_boost_up() -> void:
	nitro_button_down = false


func _restart_race() -> void:
	get_tree().reload_current_scene()


func _format_time(value: float) -> String:
	var minutes := int(value) / 60
	var seconds := fmod(value, 60.0)
	return "%02d:%05.2f" % [minutes, seconds]


func _road_center(y: float) -> float:
	var look_ahead := world_distance + (PLAYER_Y - y) * 1.7
	return VIEW_SIZE.x * 0.5 + sin(look_ahead / 430.0) * 80.0 + sin(look_ahead / 185.0) * 24.0


func _road_width(y: float) -> float:
	return lerpf(300.0, 660.0, clampf((y - ROAD_TOP) / (VIEW_SIZE.y - ROAD_TOP), 0.0, 1.0))


func _rival_x(rival: Dictionary, y: float) -> float:
	return _road_center(y) + float(rival["lane"]) * _road_width(y) * 0.32


func _draw() -> void:
	_draw_environment()
	_draw_road()
	_draw_checkpoint_gate()
	_draw_rivals()
	if road_shake > 0.0:
		var alpha := minf(0.12, road_shake * 0.012)
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(1.0, 0.28, 0.15, alpha))


func _draw_environment() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("17263a"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 215), Vector2(0, 122), Vector2(96, 62), Vector2(186, 142),
		Vector2(294, 45), Vector2(402, 136), Vector2(520, 54), Vector2(720, 160), Vector2(720, 260)
	]), Color("28465a"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 248), Vector2(0, 175), Vector2(132, 112), Vector2(236, 205),
		Vector2(372, 116), Vector2(515, 209), Vector2(632, 132), Vector2(720, 190), Vector2(720, 275)
	]), Color("35616a"))
	draw_rect(Rect2(0, 215, VIEW_SIZE.x, VIEW_SIZE.y - 215), Color("294f3c"))
	var scenery_shift := fmod(world_distance * 2.2, 170.0)
	for i in range(10):
		var y := float(i) * 170.0 - scenery_shift + 175.0
		var size := lerpf(8.0, 32.0, clampf(y / VIEW_SIZE.y, 0.0, 1.0))
		var left_x := _road_center(y) - _road_width(y) * 0.5 - 54.0
		var right_x := _road_center(y) + _road_width(y) * 0.5 + 54.0
		draw_circle(Vector2(left_x, y), size, Color("162e2a"))
		draw_circle(Vector2(right_x, y + 46.0), size * 0.85, Color("1b382f"))


func _draw_road() -> void:
	var left: PackedVector2Array = []
	var right: PackedVector2Array = []
	var y := ROAD_TOP
	while y <= VIEW_SIZE.y + ROAD_SAMPLE:
		var center := _road_center(y)
		var half_width := _road_width(y) * 0.5
		left.append(Vector2(center - half_width, y))
		right.append(Vector2(center + half_width, y))
		y += ROAD_SAMPLE
	var road_polygon := left.duplicate()
	for i in range(right.size() - 1, -1, -1):
		road_polygon.append(right[i])
	draw_colored_polygon(road_polygon, Color("202730"))

	for i in range(left.size() - 1):
		draw_line(left[i], left[i + 1], Color("f5f2df"), 10.0)
		draw_line(right[i], right[i + 1], Color("f5f2df"), 10.0)
		draw_line(left[i].lerp(right[i], 0.02), left[i + 1].lerp(right[i + 1], 0.02), Color("ff4b3e"), 4.0)
		draw_line(left[i].lerp(right[i], 0.98), left[i + 1].lerp(right[i + 1], 0.98), Color("ff4b3e"), 4.0)

	var dash_shift := fmod(world_distance * 3.1, 130.0)
	for lane_fraction in [0.333, 0.666]:
		var dash_y := ROAD_TOP - dash_shift
		while dash_y < VIEW_SIZE.y:
			var next_y := minf(dash_y + 62.0, VIEW_SIZE.y)
			if next_y > ROAD_TOP:
				var start_y := maxf(dash_y, ROAD_TOP)
				var start := Vector2(_road_center(start_y) + (lane_fraction - 0.5) * _road_width(start_y), start_y)
				var end := Vector2(_road_center(next_y) + (lane_fraction - 0.5) * _road_width(next_y), next_y)
				draw_line(start, end, Color(1.0, 1.0, 1.0, 0.72), lerpf(3.0, 8.0, next_y / VIEW_SIZE.y))
			dash_y += 130.0


func _draw_checkpoint_gate() -> void:
	var next_distance := (float(checkpoint_index) + 1.0) * CHECKPOINT_DISTANCE
	if next_distance >= RACE_LENGTH:
		next_distance = RACE_LENGTH
	var relative := next_distance - world_distance
	if relative < 0.0 or relative > 280.0:
		return
	var y := PLAYER_Y - relative * 3.05
	if y < ROAD_TOP or y > VIEW_SIZE.y:
		return
	var center := _road_center(y)
	var half_width := _road_width(y) * 0.5
	var post_height := lerpf(34.0, 105.0, y / VIEW_SIZE.y)
	var line_width := lerpf(4.0, 10.0, y / VIEW_SIZE.y)
	draw_line(Vector2(center - half_width, y), Vector2(center - half_width, y - post_height), Color("40d9ff"), line_width)
	draw_line(Vector2(center + half_width, y), Vector2(center + half_width, y - post_height), Color("40d9ff"), line_width)
	draw_line(Vector2(center - half_width, y - post_height), Vector2(center + half_width, y - post_height), Color("ffda2d"), line_width)


func _draw_rivals() -> void:
	for rival in rivals:
		var relative := float(rival["progress"]) - world_distance
		var y := PLAYER_Y - relative * 3.1
		if y < ROAD_TOP - 80.0 or y > VIEW_SIZE.y + 90.0:
			continue
		var perspective := lerpf(0.48, 1.0, clampf(y / PLAYER_Y, 0.0, 1.0))
		_draw_car(Vector2(_rival_x(rival, y), y), rival["color"], perspective)


func _draw_car(car_position: Vector2, color: Color, car_scale: float) -> void:
	var w := 48.0 * car_scale
	var h := 82.0 * car_scale
	draw_circle(car_position + Vector2(0, h * 0.34), w * 0.7, Color(0.0, 0.0, 0.0, 0.28))
	draw_colored_polygon(PackedVector2Array([
		car_position + Vector2(-w * 0.46, h * 0.5),
		car_position + Vector2(-w * 0.58, h * 0.22),
		car_position + Vector2(-w * 0.42, -h * 0.5),
		car_position + Vector2(w * 0.42, -h * 0.5),
		car_position + Vector2(w * 0.58, h * 0.22),
		car_position + Vector2(w * 0.46, h * 0.5),
	]), color)
	draw_colored_polygon(PackedVector2Array([
		car_position + Vector2(-w * 0.31, -h * 0.25),
		car_position + Vector2(w * 0.31, -h * 0.25),
		car_position + Vector2(w * 0.36, h * 0.08),
		car_position + Vector2(-w * 0.36, h * 0.08),
	]), Color("173147"))
	draw_circle(car_position + Vector2(-w * 0.29, h * 0.38), 4.0 * car_scale, Color("ff3d52"))
	draw_circle(car_position + Vector2(w * 0.29, h * 0.38), 4.0 * car_scale, Color("ff3d52"))
