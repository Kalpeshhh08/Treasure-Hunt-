extends CharacterBody3D

const SPEED = 20.0
const JUMP_VELOCITY = 10.0
@export var gravity_multiplier: float = 2.5
const MOUSE_SENSITIVITY = 0.002

@onready var head = $Head
@onready var spawn_point = $"../Marker3D"

var in_water := false
var on_ship := false
var water_timer := 20.0
var health := 100.0
var health_label: Label
var recovery_rate := 0.0
var recovering := false
var monster_damage_grace := 0.0
var water_countdown_label: Label
var treasure_count_label: Label
var treasure_count := 0
var gold := 0
var gold_label: Label
var water_episode := false
var dry_ground_time := 0.0


func _ready():
	_create_water_countdown()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_start_ambience("Waves", preload("res://dragon-studio-soothing-ocean-waves-372489.mp3"), -8.0)
	_start_ambience("Birds", preload("res://freesound_community-birds-chirping-ambiance-26052.mp3"), -8.0)

func _start_ambience(audio_name: String, source: AudioStreamMP3, level: float):
	# Non-positional ambience stays audible through player/ship camera switches.
	var ambience = AudioStreamPlayer.new()
	ambience.name = audio_name
	var loop_stream = source.duplicate() as AudioStreamMP3
	loop_stream.loop = true
	ambience.stream = loop_stream
	ambience.volume_db = level
	add_child(ambience)
	ambience.play()


func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not on_ship and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_attack_monster()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and not on_ship and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Left / Right
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)

		# Up / Down
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)

		head.rotation.x = clamp(
			head.rotation.x,
			deg_to_rad(-80),
			deg_to_rad(80)
		)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta: float) -> void:
	if on_ship:
		water_episode = false
		dry_ground_time = 0.0
		_update_health(delta)
		return
	if in_water:
		water_episode = true
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * gravity_multiplier * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# WASD
	var input_dir := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	var direction := (
		transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	).normalized()

	if direction.length() > 0:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	if water_episode:
		if _standing_on_dry_ground() and velocity.y <= 0.1:
			dry_ground_time += delta
		else:
			dry_ground_time = 0.0
		if dry_ground_time >= 0.3:
			in_water = false
			water_episode = false
			water_timer = health / 5.0
			dry_ground_time = 0.0

	_update_health(delta)


func _create_water_countdown():
	var hud := CanvasLayer.new()
	hud.name = "WaterCountdownHUD"
	hud.layer = 10
	add_child(hud)
	water_countdown_label = Label.new()
	water_countdown_label.name = "WaterCountdown"
	water_countdown_label.position = Vector2(20, 116)
	water_countdown_label.add_theme_font_size_override("font_size", 22)
	water_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	water_countdown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	water_countdown_label.add_theme_constant_override("outline_size", 5)
	water_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(water_countdown_label)
	water_countdown_label.hide()
	treasure_count_label = water_countdown_label.duplicate() as Label
	treasure_count_label.name = "TreasureCount"
	treasure_count_label.position = Vector2(20, 52)
	treasure_count_label.text = "Treasure collected count: 0"
	hud.add_child(treasure_count_label)
	treasure_count_label.show()
	gold_label = treasure_count_label.duplicate() as Label
	gold_label.name = "Gold"
	gold_label.position = Vector2(20, 84)
	gold_label.text = "Gold: $0"
	hud.add_child(gold_label)
	health_label = treasure_count_label.duplicate() as Label
	health_label.name = "Health"
	health_label.position = Vector2(20, 20)
	health_label.text = "Health: 100%"
	hud.add_child(health_label)
	_create_crosshair(hud)


func _process(_delta):
	health_label.text = "Health: %d%%" % int(ceil(health))
	water_countdown_label.visible = (water_episode or in_water) and not on_ship
	if water_countdown_label.visible:
		water_countdown_label.text = "Exit from water before: %d seconds" % int(ceil(maxf(water_timer, 0.0)))


func collect_treasure():
	treasure_count += 1
	gold = 50000 if treasure_count == 1 else 2000000
	gold_label.text = "Gold: $%d" % gold
	treasure_count_label.text = "Treasure collected count: %d" % treasure_count


func _standing_on_dry_ground() -> bool:
	if not is_on_floor():
		return false
	var water := get_tree().current_scene.get_node_or_null("water") as Node3D
	for index in get_slide_collision_count():
		var contact := get_slide_collision(index)
		var collider := contact.get_collider() as Node
		if water != null and (collider == water or water.is_ancestor_of(collider)):
			continue
		if contact.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
			continue
		if water != null and contact.get_position().y <= water.global_position.y + 0.05:
			continue
		return true
	return false


func _create_crosshair(hud: CanvasLayer):
	var crosshair := Control.new()
	crosshair.name = "Crosshair"
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	# Thin white plus with a dark border, centered at every window size.
	var rectangles: Array[Rect2] = [
		Rect2(-9, -2, 18, 4), Rect2(-2, -9, 4, 18),
		Rect2(-8, -1, 16, 2), Rect2(-1, -8, 2, 16)
	]
	for index in rectangles.size():
		var bar := ColorRect.new()
		bar.position = rectangles[index].position
		bar.size = rectangles[index].size
		bar.color = Color(0.0, 0.0, 0.0, 0.8) if index < 2 else Color.WHITE
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(bar)


func _update_health(delta: float):
	if monster_damage_grace > 0.0:
		monster_damage_grace = maxf(0.0, monster_damage_grace - delta)
		return
	if (water_episode or in_water) and not on_ship:
		recovering = false
		health = maxf(0.0, health - 5.0 * delta)
		if health <= 0.00001:
			_respawn_player()
	else:
		if health < 100.0:
			if not recovering:
				recovery_rate = (100.0 - health) / 5.0
				recovering = true
			health = minf(100.0, health + recovery_rate * delta)
		else:
			recovering = false
	water_timer = health / 5.0


func take_monster_damage(delta: float):
	if on_ship:
		return
	# Same five-second danger period as the monster's close-range attack timer.
	monster_damage_grace = 0.1
	recovering = false
	health = maxf(0.0, health - 20.0 * delta)
	water_timer = health / 5.0
	if health <= 0.00001:
		_respawn_player()


func _respawn_player():
	var ship := get_tree().current_scene.get_node_or_null("ship")
	if ship != null and ship.has_method("reset_to_spawn"):
		ship.reset_to_spawn()
	global_position = spawn_point.global_position
	velocity = Vector3.ZERO
	health = 100.0
	in_water = false
	water_episode = false
	dry_ground_time = 0.0
	recovering = false
	monster_damage_grace = 0.0
	water_timer = 20.0


func _attack_monster():
	var camera := get_viewport().get_camera_3d()
	if camera == null or on_ship:
		return
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * 8.0)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.is_in_group("monsters"):
		if global_position.distance_to(hit.collider.global_position) <= 8.0:
			hit.collider.die()
