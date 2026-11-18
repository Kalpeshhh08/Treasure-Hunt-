extends Area3D

var player_near := false
var treasure_found := false
var player_body = null

@onready var treasure_music = get_tree().current_scene.get_node_or_null("TreasureMusic")
@onready var treasure_message = get_tree().current_scene.get_node_or_null("UI/TreasureMessage")

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_near = true
		player_body = body
		print("PLAYER NEAR CHEST - PRESS E")

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

	print("TREASURE FOUND!")

	if treasure_message:
		treasure_message.text = "🏆 TREASURE FOUND!"
		treasure_message.visible = true

	if treasure_music:
		treasure_music.play()
