extends Area3D

var player_near := false
var treasure_found := false
var player_body = null

@onready var TreasureMusic: AudioStreamPlayer3D = get_tree().current_scene.get_node_or_null("TreasureMusic")

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	print("Treasure chest ready!")

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_near = true
		player_body = body
		print("Player near chest - Press E")

func _on_body_exited(body):
	if body == player_body:
		player_near = false
		player_body = null

func _process(_delta):
	if player_near and not treasure_found:
		if Input.is_key_pressed(KEY_E):
			find_treasure()

func find_treasure():
	treasure_found = true

	print("🏆 TREASURE FOUND!")

	# Play pirate music
	if TreasureMusic:
		TreasureMusic.play()
		print("🏴‍☠️ Pirate music started!")
	else:
		print("ERROR: TreasureMusic not found!")

	# Show treasure message if it exists
	var message = get_tree().current_scene.get_node_or_null("UI/TreasureMessage")

	if message:
		message.text = "🏆 TREASURE FOUND!"
		message.visible = true

		await get_tree().create_timer(4.0).timeout

		if is_instance_valid(message):
			message.visible = false
