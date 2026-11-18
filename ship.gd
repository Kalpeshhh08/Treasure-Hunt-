extends CharacterBody3D

@export var speed := 50.0
@export var turn_speed := 0.7
@export var seat_position := Vector3(0, 5, 0)
@export_range(1.0, 2.5) var camera_padding := 1.2

@export var water_surface: Node3D
@export_range(0.2, 1.0) var hull_length_factor := 0.8
@export_range(0.2, 1.0) var hull_width_factor := 0.7

const SHIP_MOUSE_SENSITIVITY := 0.003

var camera_target_local := Vector3.ZERO
var camera_radius := 1.0
var camera_yaw := 0.0
var camera_pitch := 0.54

var passenger: CharacterBody3D
var sailing_camera: Camera3D
var movement_audio: AudioStreamPlayer

var old_layer := 0
var old_mask := 0
var sailing_height := 0.0

var hull_shape: BoxShape3D
var hull_center_local := Vector3.ZERO
var water_colliders: Array[RID] = []
var setup_complete := false
var spawn_transform := Transform3D.IDENTITY


func _ready():
	spawn_transform = global_transform
	sailing_height = global_position.y

	# Scene mein "water" naam ka node automatically dhoondho.
	if water_surface == null:
		water_surface = get_tree().current_scene.get_node_or_null("water") as Node3D

	if water_surface == null:
		push_error("Ship: Inspector mein Water Surface assign karo.")
		return

	_collect_water_colliders(water_surface)

	movement_audio = AudioStreamPlayer.new()
	movement_audio.name = "BoatMovementAudio"

	var movement_stream = preload(
		"res://Boat-moving-through-waves-sound-effect.mp3"
	).duplicate() as AudioStreamMP3
	movement_stream.loop = true

	movement_audio.stream = movement_stream
	movement_audio.volume_db = -8.0
	add_child(movement_audio)

	sailing_camera = Camera3D.new()
	sailing_camera.far = 10000.0
	sailing_camera.fov = 70.0
	sailing_camera.near = 0.5
	add_child(sailing_camera)
	sailing_camera.top_level = true

	var ship_mesh: MeshInstance3D = get_node("pirate ship")
	var bounds: AABB = ship_mesh.transform * ship_mesh.get_aabb()
	var world_size: Vector3 = bounds.size * global_basis.get_scale().abs()

	camera_target_local = bounds.get_center()
	camera_radius = world_size.length() * 0.5
	hull_center_local = bounds.get_center()

	# Ship footprint ke across waterline par land detection.
	hull_shape = BoxShape3D.new()
	hull_shape.size = Vector3(
		maxf(world_size.x * hull_length_factor, 1.0),
		2.0,
		maxf(world_size.z * hull_width_factor, 1.0)
	)

	$CollisionShape3D.position.y = 3.0
	setup_complete = true


func _collect_water_colliders(node: Node):
	if node is PhysicsBody3D:
		var body := node as PhysicsBody3D
		water_colliders.append(body.get_rid())
		add_collision_exception_with(body)

	for child in node.get_children():
		_collect_water_colliders(child)


func _make_land_query(
	ship_transform: Transform3D
) -> PhysicsShapeQueryParameters3D:
	var center: Vector3 = ship_transform * hull_center_local

	# Box ka bottom water surface ke just upar rahega.
	center.y = water_surface.global_position.y + 1.05

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hull_shape
	query.transform = Transform3D(
		ship_transform.basis.orthonormalized(),
		center
	)
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = 0.1

	var excluded: Array[RID] = []
	excluded.append(get_rid())
	excluded.append_array(water_colliders)

	if is_instance_valid(passenger):
		excluded.append(passenger.get_rid())

	query.exclude = excluded
	return query


func _touches_land(ship_transform: Transform3D) -> bool:
	var query := _make_land_query(ship_transform)
	var hits := get_world_3d().direct_space_state.intersect_shape(
		query, 1
	)
	return not hits.is_empty()


func board(player: CharacterBody3D):
	if passenger != null or not setup_complete:
		return

	passenger = player
	old_layer = player.collision_layer
	old_mask = player.collision_mask

	player.collision_layer = 0
	player.collision_mask = 0
	player.on_ship = true
	player.in_water = false
	player.water_timer = player.health / 5.0
	player.velocity = Vector3.ZERO

	update_passenger()
	sailing_camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func reset_to_spawn():
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	sailing_height = global_position.y
	if movement_audio != null:
		movement_audio.stop()


func leave() -> bool:
	if passenger == null:
		return false

	var player := passenger
	var side_direction := global_basis.orthonormalized().z
	var exit_distance := hull_shape.size.z / hull_width_factor * 0.5 + 5.0
	var destination := to_global(hull_center_local) + side_direction * exit_distance
	destination.y = water_surface.global_position.y + 2.0

	# Water is a valid exit. Raise the landing point if shore is underneath.
	var ray := PhysicsRayQueryParameters3D.create(
		Vector3(destination.x, water_surface.global_position.y + 200.0, destination.z),
		Vector3(destination.x, water_surface.global_position.y - 50.0, destination.z)
	)
	ray.exclude = [get_rid(), player.get_rid()]
	ray.collision_mask = old_mask
	var ground := get_world_3d().direct_space_state.intersect_ray(ray)
	if not ground.is_empty():
		destination.y = maxf(destination.y, ground.position.y + 2.0)

	player.global_position = destination
	player.velocity = Vector3.ZERO
	player.collision_layer = old_layer
	player.collision_mask = old_mask
	player.on_ship = false
	player.in_water = destination.y <= water_surface.global_position.y + 2.01
	player.water_timer = player.health / 5.0
	player.get_node("Head/Camera3D").make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	passenger = null
	velocity = Vector3.ZERO
	movement_audio.stop()
	return true


func _unhandled_input(event):
	if passenger == null:
		return

	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return

		camera_yaw -= event.relative.x * SHIP_MOUSE_SENSITIVITY
		camera_pitch += event.relative.y * SHIP_MOUSE_SENSITIVITY
		camera_pitch = clampf(
			camera_pitch,
			deg_to_rad(-15.0),
			deg_to_rad(75.0)
		)

		update_passenger()


func _physics_process(delta):
	if not setup_complete:
		return

	if passenger == null:
		if movement_audio.playing:
			movement_audio.stop()
		return

	var previous_position := global_position

	# Turn karte waqt land overlap check karo.
	var previous_transform := global_transform

	rotate_y(
		Input.get_axis("move_right", "move_left")
		* turn_speed
		* delta
	)

	if _touches_land(global_transform):
		global_transform = previous_transform

	# Is model ka forward local +X hai.
	var requested_velocity: Vector3 = (
		global_basis.x.normalized()
		* Input.get_axis("move_back", "move_forward")
		* speed
	)
	requested_velocity.y = 0.0

	var motion: Vector3 = requested_velocity * delta
	var safe_fraction := 1.0

	if _touches_land(global_transform):
		safe_fraction = 0.0
	elif motion.length_squared() > 0.000001:
		var query := _make_land_query(global_transform)
		query.motion = motion

		var result := get_world_3d().direct_space_state.cast_motion(query)
		if result.size() == 2:
			safe_fraction = maxf(0.0, result[0] - 0.1 / motion.length()) if result[0] < 1.0 else 1.0

	velocity = requested_velocity * safe_fraction

	var before_move := global_transform
	move_and_slide()

	# Ship ko land par chadhne se roko.
	global_position.y = sailing_height
	velocity.y = 0.0

	if _touches_land(global_transform):
		global_transform = before_move
		velocity = Vector3.ZERO

	var moving: bool = (
		global_position.distance_to(previous_position)
		> 0.1 * delta
	)

	if moving and not movement_audio.playing:
		movement_audio.play()
	elif not moving and movement_audio.playing:
		movement_audio.stop()

	update_passenger()


func update_passenger():
	if passenger == null:
		return

	passenger.global_position = to_global(seat_position)

	var flat := global_basis.orthonormalized()
	var target := to_global(camera_target_local)

	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)

	var vertical_half_fov := deg_to_rad(sailing_camera.fov * 0.5)
	var horizontal_half_fov := atan(tan(vertical_half_fov) * aspect)
	var fit_angle := minf(vertical_half_fov, horizontal_half_fov)
	var distance := camera_radius / sin(fit_angle) * camera_padding

	var horizontal_direction := (-flat.x).rotated(
		Vector3.UP,
		camera_yaw
	)

	var camera_direction := (
		horizontal_direction * cos(camera_pitch)
		+ Vector3.UP * sin(camera_pitch)
	)

	sailing_camera.global_position = target + camera_direction * distance
	sailing_camera.look_at(target, Vector3.UP)
