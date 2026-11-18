extends StaticBody3D

@export var interaction_distance := 14.0
var opened := false
var can_interact := false
var lid: Node3D
var prompt: Label3D
var player: CharacterBody3D
var target_offset := Vector3(0, 3, 0)

func _ready():
	call_deferred("_spawn_guard")
	player = get_tree().get_first_node_in_group("player")
	var source = preload("res://chestisland.glb").instantiate()
	var model = source.get_node("TREASURE CHEST/chest").duplicate() as MeshInstance3D
	source.free()
	model.name = "ChestModel"
	model.transform = Transform3D.IDENTITY
	model.scale = Vector3.ONE * 4.0
	var bounds = model.get_aabb()
	model.position.y = -bounds.position.y * 4.0
	add_child(model)
	lid = model.get_node("lid")
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = bounds.size * 4.0
	collision.shape = box
	collision.position = bounds.get_center() * 4.0 + model.position
	add_child(collision)
	target_offset = collision.position + Vector3.UP * 1.0
	prompt = Label3D.new()
	prompt.name = "InteractionPrompt"
	prompt.text = "[E]  Open Chest"
	prompt.font_size = 48
	prompt.outline_size = 12
	prompt.pixel_size = 0.008
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.position = Vector3(0, box.size.y + 3.0, 0)
	prompt.modulate = Color(1.0, 0.88, 0.45)
	prompt.visible = false
	add_child(prompt)

func _physics_process(_delta):
	can_interact = false
	if not is_instance_valid(player) or player.on_ship:
		prompt.visible = false
		return
	var camera = get_viewport().get_camera_3d()
	var target = to_global(target_offset)
	if camera == null or player.global_position.distance_to(target) > interaction_distance:
		prompt.visible = false
		return
	var direction = target - camera.global_position
	if direction.normalized().dot(-camera.global_basis.z) < 0.85:
		prompt.visible = false
		return
	var ray = PhysicsRayQueryParameters3D.create(camera.global_position, target)
	ray.exclude = [player.get_rid()]
	var hit = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit.collider != self:
		prompt.visible = false
		return
	prompt.visible = true
	can_interact = not opened

func _unhandled_input(event):
	if can_interact and event.is_action_pressed("interact") and not event.is_echo():
		open_chest()
		get_viewport().set_input_as_handled()

func open_chest():
	if opened or not can_interact:
		return
	opened = true
	if is_instance_valid(player):
		player.collect_treasure()
	can_interact = false
	prompt.text = "TREASURE FOUND!"
	create_tween().tween_property(lid, "rotation:x", deg_to_rad(-110), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _spawn_guard():
	var guard := CharacterBody3D.new()
	guard.set_script(preload("res://monster.gd"))
	guard.name = String(name) + "Guard"
	get_tree().current_scene.add_child(guard)
	guard.global_position = global_position + Vector3(10, 2, 0)
