extends CharacterBody3D

@export var detection_range: float = 45.0
@export var attack_range: float = 8.0
@export var chase_speed: float = 12.0
var player: CharacterBody3D
var attack_elapsed: float = 0.0
var dead := false
var active := false
var home := Vector3.ZERO

func _ready():
	add_to_group("monsters")
	player = get_tree().get_first_node_in_group("player")
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(60.0)
	var model := preload("res://Purple+Monster.glb").instantiate() as Node3D
	add_child(model)
	var bounds := AABB()
	var first := true
	for item in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		var box: AABB = (model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var factor := 4.0 / maxf(bounds.size.y, 0.01)
	model.scale = Vector3.ONE * factor
	model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * factor
	# The imported model faces the opposite direction from Godot's look_at forward axis.
	model.rotate_y(PI)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.0
	capsule.height = 4.0
	collision.shape = capsule
	collision.position.y = 2.0
	add_child(collision)
	call_deferred("_ground_spawn")

func _ground_spawn():
	await get_tree().physics_frame
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 150.0, global_position - Vector3.UP * 250.0)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position + Vector3.UP * 0.1
	home = global_position
	active = true

func _can_see_player() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 2.0, player.global_position + Vector3.UP)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == player

func _physics_process(delta: float):
	if dead or not active or not is_instance_valid(player):
		return
	var distance := global_position.distance_to(player.global_position)
	var chasing: bool = not player.on_ship and distance <= detection_range
	var close: bool = chasing and distance <= attack_range and _can_see_player()
	if close:
		attack_elapsed += delta
		player.take_monster_damage(delta)
		if attack_elapsed >= 5.0:
			attack_elapsed = 0.0
			chasing = false
	else:
		attack_elapsed = 0.0
	var direction: Vector3 = player.global_position - global_position if chasing else home - global_position
	direction.y = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	if direction.length() > 2.0 and not close:
		direction = direction.normalized()
		var ahead := global_position + direction * 3.0
		var query := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 4.0, ahead - Vector3.UP * 6.0)
		query.exclude = [get_rid(), player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var water := get_tree().current_scene.get_node_or_null("water") as Node3D
		if not hit.is_empty() and (water == null or (not water.is_ancestor_of(hit.collider) and hit.position.y > water.global_position.y)):
			velocity.x = direction.x * chase_speed
			velocity.z = direction.z * chase_speed
			look_at(global_position + direction, Vector3.UP)
	if not is_on_floor():
		velocity += get_gravity() * 2.5 * delta
	move_and_slide()

func die():
	if dead:
		return
	dead = true
	attack_elapsed = 0.0
	collision_layer = 0
	collision_mask = 0
	hide()
	queue_free()
