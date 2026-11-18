extends Node3D

func _ready():
	var rock = StandardMaterial3D.new()
	rock.albedo_texture = preload("res://Maps/rc1.jpg")
	rock.roughness = 0.95
	rock.uv1_triplanar = true
	rock.uv1_world_triplanar = true
	rock.uv1_scale = Vector3.ONE * 0.06
	rock.cull_mode = BaseMaterial3D.CULL_DISABLED
	for child in get_children():
		if not child is MeshInstance3D or child.mesh == null:
			continue
		if child.mesh.get_surface_count() == 0 or child.get_aabb().size.length() < 0.01:
			continue
		# Leave the imported prop and distant sphere unchanged.
		if child.name in ["mainbody_Cube", "Sphere", "Plane"]:
			continue
		child.material_override = rock
		var shape = child.mesh.create_trimesh_shape()
		if shape == null:
			continue
		shape.backface_collision = true
		# Bake transforms into vertices to avoid scaled physics bodies.
		var faces = shape.get_faces()
		for i in range(faces.size()):
			faces[i] = child.global_transform * faces[i]
		shape.set_faces(faces)
		var body = StaticBody3D.new()
		body.name = String(child.name) + "_WalkCollision"
		add_child(body)
		body.top_level = true
		body.global_transform = Transform3D.IDENTITY
		var collision = CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
