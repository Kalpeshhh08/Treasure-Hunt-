"""Treasure Island starter environment for Blender 4.x.

Run from Blender's Scripting workspace with the Text Editor's Run Script button.
It creates a new collection named Treasure_Island_Generated and leaves other
scene objects untouched.
"""

import bpy
import math
import random
from mathutils import Vector

random.seed(12)

COLLECTION_NAME = "Treasure_Island_Generated"


def material(name, color, metallic=0.0, roughness=0.65):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


SAND = material("TI_Sand", (0.76, 0.49, 0.20), roughness=0.92)
GRASS = material("TI_Grass", (0.08, 0.30, 0.045), roughness=0.96)
GRASS_LIGHT = material("TI_GrassLight", (0.15, 0.42, 0.08), roughness=0.9)
WATER = material("TI_Water", (0.015, 0.20, 0.33), metallic=0.15, roughness=0.18)
ROCK = material("TI_Rock", (0.18, 0.22, 0.20), roughness=0.9)
ROCK_LIGHT = material("TI_RockLight", (0.31, 0.34, 0.29), roughness=0.88)
TRUNK = material("TI_PalmTrunk", (0.18, 0.065, 0.018), roughness=0.9)
LEAF = material("TI_PalmLeaf", (0.025, 0.24, 0.045), roughness=0.75)
WOOD = material("TI_Wood", (0.20, 0.075, 0.018), roughness=0.88)
ROPE = material("TI_Rope", (0.50, 0.31, 0.11), roughness=0.95)
GOLD = material("TI_Gold", (0.95, 0.52, 0.035), metallic=0.82, roughness=0.28)
CHEST = material("TI_Chest", (0.13, 0.035, 0.008), roughness=0.76)


old = bpy.data.collections.get(COLLECTION_NAME)
if old:
    for obj in list(old.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(old)
col = bpy.data.collections.new(COLLECTION_NAME)
bpy.context.scene.collection.children.link(col)


def link(obj):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)
    return obj


def smooth(obj):
    if obj.type == 'MESH':
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def uv_sphere(name, loc, scale, mat, segments=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    obj = link(bpy.context.object)
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return smooth(obj)


def cube(name, loc, scale, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    obj = link(bpy.context.object)
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Soft edges", 'BEVEL')
        mod.width = bevel
        mod.segments = 2
    return obj


def cylinder(name, loc, radius, depth, mat, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    obj = link(bpy.context.object)
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def cone(name, loc, radius1, radius2, depth, mat, vertices=12):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=loc)
    obj = link(bpy.context.object)
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def palm(x, y, height=5.4, lean=0.12):
    # segmented, slightly leaning trunk
    base = Vector((x, y, 0.65))
    tip = base + Vector((lean * height, 0.0, height))
    direction = tip - base
    mid = (base + tip) / 2
    trunk = cone("Palm trunk", mid, 0.18, 0.105, direction.length, TRUNK, 10)
    trunk.rotation_mode = 'QUATERNION'
    trunk.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    for i in range(4):
        z = 1.2 + i * (height / 4.4)
        ring = cylinder("Palm trunk ring", (x + lean * z, y, z), 0.19 - i * 0.014, 0.055, ROPE, 10)
    crown = tip
    for i in range(9):
        angle = i * math.tau / 9 + random.uniform(-0.12, 0.12)
        length = random.uniform(2.25, 2.8)
        leaf = cone("Palm frond", crown + Vector((math.cos(angle), math.sin(angle), -0.14)) * (length * 0.43),
                    0.34, 0.05, length, LEAF, 6)
        leaf.rotation_euler = (math.radians(72), 0, angle + math.pi / 2)


def rock(x, y, size=0.8):
    obj = uv_sphere("Rock", (x, y, size * 0.34), (size, size * 0.78, size * 0.55), ROCK if size > 0.65 else ROCK_LIGHT, 12, 7)
    obj.rotation_euler = (random.random(), random.random(), random.random())
    return obj


def dock():
    # Extends toward the open water on the west edge.
    for x in [-9, -11, -13, -15, -17]:
        for y in [-1.05, -0.35, 0.35, 1.05]:
            plank = cube("Dock plank", (x, y, 0.63), (0.95, 0.31, 0.10), WOOD, 0.035)
            plank.rotation_euler[2] = random.uniform(-0.025, 0.025)
        for y in [-1.4, 1.4]:
            post = cylinder("Dock post", (x, y, 0.65), 0.13, 1.35, WOOD, 10)
            post.rotation_euler[0] = random.uniform(-0.02, 0.02)
    rope = cube("Dock rope rail", (-14, 1.35, 1.2), (3.5, 0.025, 0.025), ROPE)
    rope.rotation_euler[1] = math.radians(-2)


# Ocean water plane
bpy.ops.mesh.primitive_plane_add(size=2, location=(0, 0, 0))
ocean = link(bpy.context.object)
ocean.name = "Ocean_Water"
ocean.scale = (70, 70, 1)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
ocean.data.materials.append(WATER)

# Island layers: sand shoreline, raised grass interior, organic rock cliffs
shore = cylinder("Sand shoreline", (0, 0, 0.18), 12.5, 0.38, SAND, 64)
shore.scale.y = 0.83
grass = cylinder("Grass plateau", (0.7, 0.3, 0.43), 9.5, 0.32, GRASS, 64)
grass.scale.y = 0.78

for angle in range(0, 360, 20):
    a = math.radians(angle)
    r = random.uniform(7.6, 10.1)
    x, y = math.cos(a) * r, math.sin(a) * r * 0.75
    s = random.uniform(0.8, 1.65)
    obj = uv_sphere("Coastal cliff", (x, y, 0.56), (s, s * random.uniform(0.75, 1.15), s * 0.9), ROCK, 14, 8)
    obj.rotation_euler = (random.uniform(-0.22, 0.22), random.uniform(-0.22, 0.22), random.random() * math.tau)

# Small hill and a cave entrance facing south-east.
hill = uv_sphere("Island hill", (3.4, 2.2, 1.15), (4.8, 3.4, 2.5), GRASS, 28, 14)
for x, y, s in [(5.8, 0.0, 1.8), (6.6, 1.1, 1.3), (4.6, -1.5, 1.15), (7.0, -1.2, 1.0)]:
    rock(x, y, s)
cave = uv_sphere("Cave darkness", (5.6, -0.55, 1.18), (1.45, 0.45, 1.25), material("TI_Cave", (0.006, 0.008, 0.006), roughness=1.0), 16, 8)

# Palm grove and shrub/rock dressing.
for args in [(-3.5, 4.2, 5.4, 0.06), (-1.2, 5.3, 6.5, -0.08), (1.1, 4.4, 5.2, 0.13), (4.0, 3.6, 5.8, -0.10), (-4.8, -4.0, 5.8, 0.12), (-1.8, -5.2, 6.4, 0.04), (2.6, -4.6, 5.3, -0.08)]:
    palm(*args)
for i in range(45):
    angle = random.random() * math.tau
    radius = random.uniform(3.5, 9.7)
    x, y = math.cos(angle) * radius, math.sin(angle) * radius * 0.73
    if x < -7 and abs(y) < 2.5:
        continue
    if random.random() < 0.58:
        rock(x, y, random.uniform(0.22, 0.76))
    else:
        shrub = uv_sphere("Jungle shrub", (x, y, 0.83), (random.uniform(0.28, 0.62), random.uniform(0.28, 0.62), random.uniform(0.25, 0.55)), GRASS_LIGHT, 10, 6)

# Dock and an obvious treasure destination.
dock()
chest_base = cube("Treasure chest base", (5.55, -0.55, 1.42), (0.72, 0.43, 0.40), CHEST, 0.07)
lid = cube("Treasure chest lid", (5.55, -0.55, 1.86), (0.74, 0.45, 0.16), CHEST, 0.07)
lid.rotation_euler[0] = math.radians(-18)
lock = cube("Treasure chest lock", (5.55, -1.00, 1.58), (0.11, 0.04, 0.13), GOLD, 0.015)
for x in [5.10, 6.00]:
    cube("Chest gold band", (x, -1.00, 1.58), (0.045, 0.025, 0.34), GOLD)

# A warm sun light for an immediately attractive viewport preview.
light_data = bpy.data.lights.new("Treasure sun", 'SUN')
light_data.energy = 2.0
sun = bpy.data.objects.new("Treasure sun", light_data)
col.objects.link(sun)
sun.rotation_euler = (math.radians(35), math.radians(-20), math.radians(35))

# World background and scene units for Godot-friendly scale.
bpy.context.scene.world.color = (0.035, 0.09, 0.16)
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.scene.unit_settings.length_unit = 'METERS'

# Select the generated collection contents so the user can instantly inspect/export it.
bpy.ops.object.select_all(action='DESELECT')
for obj in col.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = shore

print("Treasure Island created: terrain, water, palms, cliffs, dock, cave, and chest.")
