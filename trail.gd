extends Line2D

@export var max_points: int = 25
@onready var rider: RigidBody2D = get_parent()

func _ready() -> void:
	# Ensures the trail stays in world coordinates rather than moving with the rider
	top_level = true

func _process(_delta: float) -> void:
	# Clear the trail if the rider is frozen/reset at the start
	if rider.freeze:
		clear_points()
		return

	# Add the rider's current position to the front of the line
	add_point(rider.global_position)

	# Remove the oldest point once the trail reaches max length
	if get_point_count() > max_points:
		remove_point(0)
