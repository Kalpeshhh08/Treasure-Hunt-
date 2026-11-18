extends Area3D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player") and not body.on_ship:
		# Preserve the countdown through jumps out of and back into water.
		body.in_water = true
