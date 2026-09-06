extends Node2D

const GEM_RADIUS := 28.0

var score := 0
var gem: Area2D

@onready var player: CharacterBody2D = $Player
@onready var score_label: Label = $Hud/ScoreLabel

func _ready() -> void:
	randomize()
	_spawn_gem()
	_update_score_label()

func _process(_delta: float) -> void:
	if gem == null:
		return
	if player.global_position.distance_to(gem.global_position) <= 80.0:
		score += 1
		_spawn_gem()
		_update_score_label()

func _spawn_gem() -> void:
	if gem != null:
		gem.queue_free()

	gem = Area2D.new()
	gem.name = "Gem"
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = GEM_RADIUS
	collision.shape = shape

	var visual := Polygon2D.new()
	visual.color = Color(1.0, 0.86, 0.26)
	visual.polygon = PackedVector2Array([Vector2(0, -GEM_RADIUS), Vector2(GEM_RADIUS, 0), Vector2(0, GEM_RADIUS), Vector2(-GEM_RADIUS, 0)])

	gem.add_child(collision)
	gem.add_child(visual)
	add_child(gem)

	var viewport_size := get_viewport_rect().size
	gem.global_position = Vector2(randf_range(80.0, viewport_size.x - 80.0), randf_range(160.0, viewport_size.y - 120.0))

func _update_score_label() -> void:
	score_label.text = "Score: %d" % score
