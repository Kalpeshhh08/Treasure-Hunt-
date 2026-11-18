extends Area3D

@export var get_in_button: Button

var nearby_player: CharacterBody3D
var object_prompt: Label3D
var can_board := false
var exit_message_until := 0

@onready var ship = get_parent()


func _ready():
	if get_in_button:
		get_in_button.hide()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	object_prompt = Label3D.new()
	object_prompt.name = "ShipInteractionPrompt"
	object_prompt.font_size = 48
	object_prompt.outline_size = 12
	object_prompt.pixel_size = 0.008
	object_prompt.fixed_size = false
	object_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	object_prompt.modulate = Color(1.0, 0.88, 0.45)
	object_prompt.no_depth_test = true

	add_child(object_prompt)

	# Ship ka scale text par apply nahi hoga.
	object_prompt.top_level = true
	object_prompt.global_basis = Basis.IDENTITY
	object_prompt.hide()


func _on_body_entered(body):
	if body.is_in_group("player"):
		nearby_player = body


func _on_body_exited(body):
	if body == nearby_player:
		nearby_player = null


func _physics_process(_delta):
	refresh_prompt()


func refresh_prompt():
	can_board = false
	object_prompt.hide()

	var target = ship.to_global(
		Vector3(ship.camera_target_local.x, 3.0, 0)
	)
	object_prompt.global_position = target + Vector3.UP * 6.0

	if ship.passenger != null:
		if Time.get_ticks_msec() < exit_message_until:
			object_prompt.text = "No safe exit nearby"
		else:
			object_prompt.text = "[E] Get Out"

		object_prompt.show()
		return

	if not is_instance_valid(nearby_player):
		return

	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return

	var direction = target - camera.global_position
	if direction.normalized().dot(-camera.global_basis.z) < 0.85:
		return

	var ray = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		target
	)
	ray.exclude = [nearby_player.get_rid(), ship.get_rid()]

	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return

	can_board = true
	object_prompt.text = "[E] Get In"
	object_prompt.show()


func _unhandled_input(event):
	if event.is_action_pressed("interact") and not event.is_echo():
		refresh_prompt()

		if ship.passenger != null or can_board:
			_interact()
			get_viewport().set_input_as_handled()


func _interact():
	if ship.passenger != null:
		if not ship.leave():
			exit_message_until = Time.get_ticks_msec() + 2000
			refresh_prompt()
			return

	elif can_board and is_instance_valid(nearby_player):
		ship.board(nearby_player)

	refresh_prompt()
