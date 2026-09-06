extends CharacterBody2D

@export var speed: float = 720.0
@export var touch_follow_lerp: float = 16.0

var target_position: Vector2
var is_touching := false

func _ready() -> void:
	target_position = global_position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		is_touching = event.pressed
		if is_touching:
			target_position = event.position
	elif event is InputEventScreenDrag:
		is_touching = true
		target_position = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_touching = event.pressed
		if is_touching:
			target_position = event.position
	elif event is InputEventMouseMotion and is_touching:
		target_position = event.position

func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length_squared() > 0.0:
		is_touching = false
		velocity = input_vector * speed
	elif is_touching:
		var next_position := global_position.lerp(target_position, 1.0 - exp(-touch_follow_lerp * delta))
		velocity = (next_position - global_position) / max(delta, 0.001)
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_keep_inside_viewport()

func _keep_inside_viewport() -> void:
	var viewport_rect := get_viewport_rect()
	global_position.x = clampf(global_position.x, 48.0, viewport_rect.size.x - 48.0)
	global_position.y = clampf(global_position.y, 48.0, viewport_rect.size.y - 48.0)
