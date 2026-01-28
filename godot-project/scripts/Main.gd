extends Node2D

# States
enum GameState { MENU, DRAWING, LAUNCHED, VICTORY, DEFEAT }
var state: GameState = GameState.DRAWING

# Drawing properties
var drawing: bool = false
var points: PackedVector2Array = PackedVector2Array()
const MAX_POINTS: int = 2000
const MIN_POINT_DISTANCE: float = 6.0

# References
@onready var ball: Node2D = $Ball
@onready var line_canvas: Line2D = $Line2D
@onready var reset_button: Button = $CanvasLayer/Control/ResetButton
@onready var hud_score: Label = $CanvasLayer/Control/HUD/Score
@onready var hud_best: Label = $CanvasLayer/Control/HUD/Best

# Player metadata
var player_name: String = "Player"

# physics
var ball_velocity: Vector2 = Vector2.ZERO
const GRAVITY: float = 900.0

func _ready():
	# Hook reset
	reset_button.pressed.connect(_on_reset_pressed)
	# Initialize HUD high score to 0 immediately (mandatory)
	if hud_best:
		hud_best.text = "Best: 0"
		hud_best.visible = true
	# Show current score init
	_update_score_ui()
	# Obtain player name if passed
	if get_current_scene().has_meta("player_name"):
		player_name = str(get_current_scene().get_meta("player_name"))
	# Connect to Global score_changed
	if Global:
		Global.reset_score()
		Global.connect("score_changed", Callable(self, "_on_score_changed"))
		hud_best.text = "Best: %d" % Global.high_score
	# Prepare line
	line_canvas.width = 3
	line_canvas.default_color = Color(0, 0, 0)
	line_canvas.clear_points()
	points = PackedVector2Array()
	set_process(true)
	set_physics_process(true)

func _input(event):
	# Accept both mouse drag and touch
	if state != GameState.DRAWING:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drawing(event.position)
			else:
				_finish_drawing()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_start_drawing(event.position)
		else:
			_finish_drawing()
	elif event is InputEventMouseMotion:
		if drawing:
			_add_point(event.position)

func _start_drawing(pos: Vector2) -> void:
	if drawing:
		return
	drawing = true
	points = PackedVector2Array()
	points.append(pos)
	_redraw_line()

func _add_point(pos: Vector2) -> void:
	if not drawing:
		return
	var last = points[points.size() - 1]
	if last.distance_to(pos) < MIN_POINT_DISTANCE:
		return
	if points.size() >= MAX_POINTS:
		return
	points.append(pos)
	_redraw_line()

func _finish_drawing() -> void:
	if not drawing:
		return
	drawing = false
	# Lock the line - start ball launch phase
	state = GameState.LAUNCHED
	# compute initial velocity from last segment
	if points.size() >= 2:
		var a = points[points.size() - 2]
		var b = points[points.size() - 1]
		var dir = (b - a).normalized()
		ball_velocity = dir * 400.0
	else:
		ball_velocity = Vector2.ZERO
	# Add collision shapes approximating the line by creating StaticBody2D along segments
	_build_collision_for_line()
	# Add a small score for attempting
	Global.add_score(0) # ensures HUD update

func _build_collision_for_line() -> void:
	# Remove any previous collision segments
	if $LineCollision:
		$LineCollision.queue_free()
	var container = Node2D.new()
	container.name = "LineCollision"
	add_child(container)
	# For each segment create a StaticBody2D with CollisionShape2D using RectangleShape2D rotated
	for i in range(points.size() - 1):
		var a = points[i]
		var b = points[i + 1]
		var seg = StaticBody2D.new()
		var col = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		var length = a.distance_to(b)
		rect.size = Vector2(length, 4)
		col.shape = rect
		var sprite = Node2D.new()
		seg.position = a
		col.position = Vector2(length / 2, 0)
		# Rotate to face the segment
		seg.rotation = (b - a).angle()
		seg.add_child(col)
		container.add_child(seg)

func _physics_process(delta: float) -> void:
	if state == GameState.LAUNCHED:
		# Physics movement of the ball
		ball_velocity.y += GRAVITY * delta
		var new_pos = ball.position + ball_velocity * delta
		# Simple collision checks with line collisions (approximate)
		# If ball collides with exit area -> victory
		if $ExitArea and $ExitArea.get_overlapping_bodies().has(ball):
			_on_victory()
			return
		# If ball falls off screen -> defeat
		if new_pos.y > 2000:
			_on_defeat()
			return
		ball.position = new_pos
		# Basic collision detection with LineCollision segments - approximate using intersect_point on shapes
		# We'll do an overlap_area check: if ball intersects any CollisionShape2D, reflect velocity slightly
		var collided = false
		var container = $LineCollision
		if container:
			for seg in container.get_children():
				for shape in seg.get_children():
					if shape is CollisionShape2D:
						var global_shape = shape.shape
						# approximate: check distance to segment line
						var seg_a = seg.position
						var seg_b = seg.position + Vector2(global_shape.size.x, 0).rotated(seg.rotation)
						var dist = Geometry.get_closest_point_to_segment(ball.position, seg_a, seg_b)
						if dist.distance_to(ball.position) < 16: # ball radius approximate
							collided = true
							# simple bounce
							ball_velocity = ball_velocity.bounced((seg_b - seg_a).normalized())
							ball_velocity *= 0.7
							break
				if collided:
					break

func _on_victory():
	state = GameState.VICTORY
	# reward points
	Global.add_score(100)
	# Save score to storage
	Global.save_score_to_storage(player_name, Global.score)
	# Transition to victory screen
	get_tree().change_scene_to_file("res://scenes/VictoryScreen.tscn")

func _on_defeat():
	state = GameState.DEFEAT
	# show final state
	get_tree().change_scene_to_file("res://scenes/DefeatScreen.tscn")

func _on_reset_pressed():
	# reset scene to allow drawing again
	get_tree().reload_current_scene()

func _on_score_changed(new_score: int):
	_update_score_ui()

func _update_score_ui():
	if hud_score:
		hud_score.text = "Score: %d" % Global.score
	if hud_best:
		hud_best.text = "Best: %d" % Global.high_score

func _redraw_line():
	line_canvas.clear_points()
	for p in points:
		line_canvas.add_point(p)