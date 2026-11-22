extends Node2D

@export var min_point_distance: float = 12.0
@export var line_width: float = 6.0
@export var neon_color: Color = Color(0.2, 1.5, 2.5, 1.0) # Cyan glow
@export var stuck_speed_threshold: float = 15.0 # Speed below this counts as "stuck"

@onready var rider: RigidBody2D = $Rider
@onready var stuck_timer: Timer = $StuckTimer
@onready var progress_timer: Timer = $ProgressTimer
@onready var stuck_label: Label = $CanvasLayer/StuckLabel
@onready var score_label: Label = $CanvasLayer/ScoreLabel

var start_position: Vector2
var current_score: float = 0.0
var high_score: float = 0.0
var beat_record_this_run: bool = false
const SAVE_PATH := "user://highscore.save"

var current_line: Line2D
var current_body: StaticBody2D
var last_point: Vector2

func _ready() -> void:
	start_position = rider.global_position
	stuck_timer.timeout.connect(_reset_rider)
	progress_timer.timeout.connect(_reset_rider)
	stuck_label.visible = false
	_load_high_score()
	_update_score_ui()

func _process(_delta: float) -> void:
	# Press SPACE to drop/pause the rider
	if Input.is_action_just_pressed("ui_accept"):
		rider.freeze = !rider.freeze
		stuck_timer.stop()
		stuck_label.visible = false
		if rider.freeze:
			progress_timer.stop()
		else:
			progress_timer.start()
		
	# Press ESCAPE to reset the rider back to the start
	if Input.is_action_just_pressed("ui_cancel"):
		_reset_rider()

	if not rider.freeze:
		# 1. CONTINUOUS SCORE & PROGRESS TIMER CHECK (1 meter = 50 pixels)
		var distance_meters = max(0.0, (rider.global_position.x - start_position.x) / 50.0)
		if distance_meters > current_score:
			current_score = distance_meters
			progress_timer.start() # Reset the 30s inactivity timer whenever new distance is gained!
			
			if current_score > high_score:
				high_score = current_score
				_save_high_score()
				
				if not beat_record_this_run and high_score > 1.0:
					beat_record_this_run = true
					_trigger_new_best_flash()
					
			_update_score_ui()

		# 2. STUCK TIMER CHECK (3 seconds if completely stopped)
		if rider.linear_velocity.length() < stuck_speed_threshold:
			if stuck_timer.is_stopped():
				stuck_timer.start()
			stuck_label.visible = true
			var seconds_left = ceili(stuck_timer.time_left)
			stuck_label.text = "Stuck! Resetting in %d..." % seconds_left
		else:
			stuck_timer.stop()
			# Show a warning during the last 5 seconds of the 30-second fall/inactivity timer
			if progress_timer.time_left <= 5.0 and not progress_timer.is_stopped():
				stuck_label.visible = true
				var seconds_left = ceili(progress_timer.time_left)
				stuck_label.text = "No progress! Resetting in %d..." % seconds_left
			else:
				stuck_label.visible = false

func _trigger_new_best_flash() -> void:
	score_label.pivot_offset = score_label.size / 2.0
	var tween = create_tween()
	tween.tween_property(score_label, "modulate", Color(2.5, 2.0, 0.2, 1.0), 0.12)
	tween.parallel().tween_property(score_label, "scale", Vector2(1.2, 1.2), 0.12)
	tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(score_label, "modulate", Color(1.0, 0.85, 0.2, 1.0), 0.3)

func _reset_rider() -> void:
	stuck_timer.stop()
	progress_timer.stop()
	stuck_label.visible = false
	rider.freeze = true
	rider.linear_velocity = Vector2.ZERO
	rider.angular_velocity = 0.0
	rider.global_position = start_position
	rider.rotation = 0.0
	
	current_score = 0.0
	beat_record_this_run = false
	score_label.modulate = Color.WHITE
	score_label.scale = Vector2.ONE
	_update_score_ui()

func _update_score_ui() -> void:
	var tag = "  ★ NEW BEST!" if beat_record_this_run else ""
	score_label.text = "Distance: %.1fm\nBest: %.1fm%s" % [current_score, high_score, tag]

func _save_high_score() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_float(high_score)

func _load_high_score() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			high_score = file.get_float()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_new_stroke(get_global_mouse_position())
		else:
			current_line = null
			current_body = null

	elif event is InputEventMouseMotion and current_line != null:
		var mouse_pos = get_global_mouse_position()
		if mouse_pos.distance_to(last_point) >= min_point_distance:
			_add_segment(mouse_pos)

func _start_new_stroke(start_pos: Vector2) -> void:
	current_line = Line2D.new()
	current_line.width = line_width
	current_line.default_color = neon_color
	current_line.joint_mode = Line2D.LINE_JOINT_ROUND
	current_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	current_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	current_line.add_point(start_pos)
	$TrackContainer.add_child(current_line)

	current_body = StaticBody2D.new()
	var physics_mat = PhysicsMaterial.new()
	physics_mat.friction = 0.05
	physics_mat.bounce = 1.0
	current_body.physics_material_override = physics_mat
	$TrackContainer.add_child(current_body)

	last_point = start_pos

func _add_segment(new_pos: Vector2) -> void:
	current_line.add_point(new_pos)

	var collision = CollisionShape2D.new()
	var segment = SegmentShape2D.new()
	segment.a = last_point
	segment.b = new_pos
	collision.shape = segment
	current_body.add_child(collision)

	last_point = new_pos
