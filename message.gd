extends Area3D

var player_near := false
var treasure_found := false
var player_body = null

@onready var treasure_music: AudioStreamPlayer3D = get_tree().current_scene.get_node_or_null("TreasureMusic")
@onready var interaction_message = get_tree().current_scene.get_node_or_null("UI/InteractionMessage")
@onready var treasure_message = get_tree().current_scene.get_node_or_null("UI/TreasureMessage")

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player") and not treasure_found:
		player_near = true
		player_body = body

		if interaction_message:
			interaction_message.text = "Press E to Open"
			interaction_message.visible = true

func _on_body_exited(body):
	if body == player_body:
		player_near = false
		player_body = null

		if interaction_message:
			interaction_message.visible = false

func _process(_delta):
	if player_near and not treasure_found:
		if Input.is_key_pressed(KEY_E):
			find_treasure()

func find_treasure():
	treasure_found = true

	if interaction_message:
		interaction_message.visible = false

	if treasure_message:
		treasure_message.text = "🏆 TREASURE FOUND!"
		treasure_message.visible = true

	if treasure_music:
		treasure_music.play()

	await get_tree().create_timer(4.0).timeout

	if treasure_message:
		treasure_message.visible = false
