extends Area3D

@export var ship: Node3D
@export var dock_a: Marker3D
@export var dock_b: Marker3D
@export var player_seat: Marker3D
@export var travel_time: float = 5.0

var player_in_range := false
var player_body: CharacterBody3D = null
var is_sailing := false
var ship_at_a := true


func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body):
	if body.is_in_group("player") and not is_sailing:
		player_in_range = true
		player_body = body
		print("Player can board the ship")


func _on_body_exited(body):
	if body == player_body and not is_sailing:
		player_in_range = false
		player_body = null


func _process(_delta):
	if player_in_range and not is_sailing:
		if Input.is_action_just_pressed("interact"):
			start_sailing()


func start_sailing():
	if player_body == null:
		print("Missing player!")
		return

	if ship == null:
		print("Missing ship!")
		return

	if dock_a == null or dock_b == null:
		print("Missing dock!")
		return

	if player_seat == null:
		print("Missing player seat!")
		return


	# --------------------------------
	# Choose destination
	# --------------------------------

	var target_dock: Marker3D

	if ship_at_a:
		target_dock = dock_b
	else:
		target_dock = dock_a


	# --------------------------------
	# Calculate direction
	# --------------------------------

	var direction := target_dock.global_position - ship.global_position
	direction.y = 0

	if direction.length() > 0.01:
		direction = direction.normalized()


	# --------------------------------
	# Rotate ship toward destination
	# --------------------------------

	var target_rotation := atan2(-direction.x, -direction.z)

	# Smooth rotation
	var rotation_tween := create_tween()

	rotation_tween.tween_property(
		ship,
		"global_rotation:y",
		target_rotation,
		0.5
	)


	# --------------------------------
	# Start sailing
	# --------------------------------

	is_sailing = true
	player_in_range = false

	var body := player_body

	# Stop player movement
	body.set_physics_process(false)
	body.velocity = Vector3.ZERO


	# Disable player collision
	var player_collision := body.get_node_or_null("CollisionShape3D")

	if player_collision:
		player_collision.disabled = true


	# --------------------------------
	# Put player on ship
	# --------------------------------

	body.reparent(ship)

	body.global_position = player_seat.global_position


	# --------------------------------
	# Move ship
	# --------------------------------

	var tween := create_tween()

	tween.tween_property(
		ship,
		"global_position",
		target_dock.global_position,
		travel_time
	)


	# --------------------------------
	# Arrival
	# --------------------------------

	tween.tween_callback(func():

		var world := get_tree().current_scene


		# Remove player from ship
		body.reparent(world)


		# Drop player at shore
		body.global_position = target_dock.global_position + Vector3(2, 1, 0)


		# Restore collision
		if player_collision:
			player_collision.disabled = false


		# Restore player movement
		body.set_physics_process(true)


		# Change direction for next trip
		ship_at_a = not ship_at_a


		is_sailing = false


		print("Ship arrived at destination!")

	)
