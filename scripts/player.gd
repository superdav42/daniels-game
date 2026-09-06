extends CharacterBody2D

@export var steering_speed := 460.0
@export var touch_follow := 7.5

var speed_factor := 0.0
var road_center := 360.0
var road_width := 620.0
var is_boosting := false
var drive_enabled := false
var touch_active := false
var touch_target_x := 360.0
var bump_velocity := 0.0


func _ready() -> void:
	queue_redraw()


func set_drive_context(new_speed_factor: float, new_road_center: float, new_road_width: float, boosting: bool, enabled: bool) -> void:
	speed_factor = new_speed_factor
	road_center = new_road_center
	road_width = new_road_width
	is_boosting = boosting
	drive_enabled = enabled
	queue_redraw()


func bump_away(direction: float) -> void:
	bump_velocity = (direction if direction != 0.0 else 1.0) * 330.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_active = event.pressed
		if touch_active:
			touch_target_x = event.position.x
	elif event is InputEventScreenDrag:
		touch_active = true
		touch_target_x = event.position.x
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.y < 1080.0:
			touch_active = event.pressed
			if touch_active:
				touch_target_x = event.position.x
	elif event is InputEventMouseMotion and touch_active:
		touch_target_x = event.position.x


func _physics_process(delta: float) -> void:
	var steering := Input.get_axis("move_left", "move_right")
	if Input.is_key_pressed(KEY_LEFT):
		steering -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		steering += 1.0
	steering = clampf(steering, -1.0, 1.0)
	if not is_zero_approx(steering):
		touch_active = false
	var desired_velocity := steering * steering_speed * lerpf(0.62, 1.0, clampf(speed_factor, 0.0, 1.0))
	if touch_active:
		desired_velocity = clampf((touch_target_x - global_position.x) * touch_follow, -steering_speed, steering_speed)
	if not drive_enabled:
		desired_velocity = 0.0

	bump_velocity = move_toward(bump_velocity, 0.0, 520.0 * delta)
	velocity = Vector2(desired_velocity + bump_velocity, 0.0)
	move_and_slide()
	global_position.x = clampf(global_position.x, 42.0, 678.0)
	global_position.y = 965.0
	rotation = lerp_angle(rotation, clampf(-velocity.x / 980.0, -0.3, 0.3), 1.0 - exp(-9.0 * delta))
	queue_redraw()


func _draw() -> void:
	if is_boosting:
		for i in range(3):
			var x := -18.0 + i * 18.0
			draw_line(Vector2(x, 48), Vector2(x, 82 + i * 7), Color(0.25, 0.86, 1.0, 0.65), 7.0)
	_draw_custom_ellipse(Vector2(0, 15), 45.0, 72.0, Color(0.0, 0.0, 0.0, 0.34))
	for wheel_x in [-43.0, 43.0]:
		draw_rect(Rect2(wheel_x - 7.0, -38.0, 14.0, 34.0), Color("090d12"), true)
		draw_rect(Rect2(wheel_x - 7.0, 22.0, 14.0, 34.0), Color("090d12"), true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-36, 68), Vector2(-49, 34), Vector2(-43, -47),
		Vector2(-27, -70), Vector2(27, -70), Vector2(43, -47),
		Vector2(49, 34), Vector2(36, 68)
	]), Color("ffd21f"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-29, -36), Vector2(29, -36), Vector2(35, 8), Vector2(-35, 8)
	]), Color("102c43"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-34, 15), Vector2(34, 15), Vector2(29, 42), Vector2(-29, 42)
	]), Color("193d54"))
	draw_line(Vector2(0, -67), Vector2(0, 66), Color(1.0, 0.95, 0.62, 0.55), 3.0)
	draw_circle(Vector2(-26, -55), 7.0, Color("e8faff"))
	draw_circle(Vector2(26, -55), 7.0, Color("e8faff"))
	draw_rect(Rect2(-31, 51, 16, 8), Color("ff354f"), true)
	draw_rect(Rect2(15, 51, 16, 8), Color("ff354f"), true)


func _draw_custom_ellipse(center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_colored_polygon(points, color)
