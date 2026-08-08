"""Build normalized glTF props and the procedural plant roster in Blender.

Run with:
  blender --background --python tools/build_assets.py -- <old-model-root> <output-root>
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
if len(ARGS) != 2:
    raise SystemExit("Expected source model root and output root")

SOURCE_ROOT = Path(ARGS[0]).resolve()
OUTPUT_ROOT = Path(ARGS[1]).resolve()
PROP_ROOT = OUTPUT_ROOT / "props"
PLANT_ROOT = OUTPUT_ROOT / "plants"
PROP_ROOT.mkdir(parents=True, exist_ok=True)
PLANT_ROOT.mkdir(parents=True, exist_ok=True)


PROP_SOURCES = {
    "bed": ("furniture/Bed/bed.fbx", 2.15),
    "desk_setup": ("furniture/desk+setup/desk+setup.fbx", 2.45),
    "fridge": ("furniture/fridge/fridge.fbx", 1.90),
    "lower_cabinet": ("furniture/Lower_Kitchen_Cabinet/Lower_Kitchen_Cabinet.fbx", 1.05),
    "microwave": ("furniture/Microwave/microwave.fbx", 0.55),
    "nightstand": ("furniture/night_stand/Nightstand.fbx", 0.65),
    "oven": ("furniture/Oven/oven.fbx", 0.90),
    "storage_shelf": ("furniture/Storage_Shelf/storage_shelf.fbx", 2.10),
    "stovetop": ("furniture/Stovetop/Untitled.fbx", 0.65),
    "upper_cabinet": ("furniture/Upper_Kitchen_Cabinet/Upper_Kitchen_Cabinet.fbx", 1.00),
    "greenhouse": ("map/Greenhouse/greenhouse_5x3m.fbx", 5.00),
    "garden_faucet": ("map/Garden_Faucet/garden_faucet.fbx", 0.72),
    "watering_can": ("equipment/Watering_Can/watering_can.fbx", 0.48),
    "trowel": ("equipment/Trowel/trowel.fbx", 0.36),
    "secateurs": ("equipment/Secateur/secateur.fbx", 0.27),
    "empty_pot": ("equipment/pots/ornament plants/empty/ornament_plants_pot_empty.fbx", 0.34),
    "soil_bag": ("supplies/soil/ornament plants/ornament_plants_soil.fbx", 0.52),
    "fertilizer_bag": ("supplies/fertilizer/ornament_plants/ornament_plants_fertilizer.fbx", 0.52),
    "delivery_drone": ("vehicles/delivery_drone_empty.fbx", 1.45),
    "delivery_drone_package": ("vehicles/delivery_drone_with_package.fbx", 1.45),
}


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def material(name: str, color: tuple[float, float, float, float], roughness: float = 0.68, metallic: float = 0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    mat.use_backface_culling = False
    node = mat.node_tree.nodes.get("Principled BSDF")
    if node:
        node.inputs["Base Color"].default_value = color
        node.inputs["Roughness"].default_value = roughness
        node.inputs["Metallic"].default_value = metallic
    return mat


def smooth_mesh(obj) -> None:
    if obj.type != "MESH":
        return
    for poly in obj.data.polygons:
        poly.use_smooth = True


def growth_name(kind: str, threshold: float, suffix: str) -> str:
    return f"{kind}_g{int(round(threshold * 1000)):03d}_{suffix}"


def mesh_object(name: str, vertices, faces, mat, location=(0.0, 0.0, 0.0)):
    mesh = bpy.data.meshes.new(f"{name}_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.data.materials.append(mat)
    smooth_mesh(obj)
    return obj


def cylinder_between(name: str, start: Vector, end: Vector, radius: float, mat, vertices: int = 9):
    delta = end - start
    length = max(delta.length, 0.001)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=length, location=(start + end) * 0.5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(delta.normalized())
    obj.data.materials.append(mat)
    smooth_mesh(obj)
    return obj


def sphere(name: str, location: Vector, radius: float, mat, scale=(1.0, 1.0, 1.0)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    smooth_mesh(obj)
    return obj


def leaf(
    name: str,
    base: Vector,
    direction: Vector,
    length: float,
    width: float,
    mat,
    threshold: float,
    shape: str = "ellipse",
    curve: float = 0.06,
    serration: float = 0.0,
    vein_mat=None,
    segments: int = 12,
):
    vertices = []
    faces = []
    for index in range(segments + 1):
        t = index / segments
        if shape == "heart":
            profile = math.sin(math.pi * t) ** 0.62
            profile *= 0.78 + 0.34 * math.exp(-((t - 0.23) / 0.18) ** 2)
        elif shape == "lance":
            profile = math.sin(math.pi * t) ** 1.18
        elif shape == "blade":
            profile = max(0.0, math.sin(math.pi * t)) ** 0.30 * (1.0 - 0.30 * t)
        elif shape == "spade":
            profile = math.sin(math.pi * t) ** 0.52 * (1.15 - 0.35 * t)
        else:
            profile = math.sin(math.pi * t) ** 0.78
        if serration and index not in (0, segments):
            profile *= 1.0 + serration * (1.0 if index % 2 else -0.45)
        half = width * profile * 0.5
        y = length * t
        z = curve * math.sin(math.pi * t) + curve * 0.20 * t
        vertices.extend([(-half, y, z), (half, y, z)])
        if index:
            a = (index - 1) * 2
            b = index * 2
            faces.append((a, a + 1, b + 1, b))
    obj = mesh_object(growth_name("leaf", threshold, name), vertices, faces, mat, base)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 1.0, 0.0)).rotation_difference(direction.normalized())
    if vein_mat:
        vein_start = base + direction.normalized() * (length * 0.08) + Vector((0.0, 0.0, 0.007))
        vein_end = base + direction.normalized() * (length * 0.86) + Vector((0.0, 0.0, curve * 0.55 + 0.008))
        cylinder_between(growth_name("vein", threshold, name), vein_start, vein_end, max(width * 0.012, 0.002), vein_mat, 6)
    return obj


def petal_ring(prefix: str, center: Vector, count: int, length: float, width: float, mat, threshold: float, tilt: float = 0.12):
    for index in range(count):
        angle = math.tau * index / count
        direction = Vector((math.cos(angle), math.sin(angle), tilt)).normalized()
        leaf(f"{prefix}_{index:02d}", center, direction, length, width, mat, threshold, "lance", length * 0.10, 0.0, None, 7)


def add_standard_pot() -> None:
    clay = material("Pot_Terracotta", (0.44, 0.20, 0.12, 1.0), 0.84)
    rim = material("Pot_Rim", (0.55, 0.27, 0.16, 1.0), 0.78)
    soil = material("Potting_Soil", (0.055, 0.032, 0.020, 1.0), 0.98)
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.145, radius2=0.19, depth=0.25, location=(0.0, 0.0, 0.125))
    pot = bpy.context.object
    pot.name = "pot_static"
    pot.data.materials.append(clay)
    smooth_mesh(pot)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.177, minor_radius=0.018, major_segments=24, minor_segments=8, location=(0.0, 0.0, 0.245))
    pot_rim = bpy.context.object
    pot_rim.name = "pot_rim_static"
    pot_rim.data.materials.append(rim)
    smooth_mesh(pot_rim)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.168, depth=0.014, location=(0.0, 0.0, 0.247))
    dirt = bpy.context.object
    dirt.name = "soil_static"
    dirt.data.materials.append(soil)


def common_materials():
    return {
        "stem": material("Stem", (0.08, 0.30, 0.105, 1.0), 0.76),
        "stem_light": material("Stem_Light", (0.20, 0.43, 0.16, 1.0), 0.74),
        "leaf": material("Leaf_Deep", (0.045, 0.25, 0.105, 1.0), 0.70),
        "leaf_mid": material("Leaf_Mid", (0.08, 0.37, 0.15, 1.0), 0.68),
        "leaf_light": material("Leaf_Light", (0.20, 0.48, 0.19, 1.0), 0.72),
        "vein": material("Leaf_Vein", (0.39, 0.62, 0.31, 1.0), 0.75),
        "white": material("Flower_White", (0.93, 0.95, 0.84, 1.0), 0.58),
        "yellow": material("Flower_Yellow", (0.96, 0.61, 0.08, 1.0), 0.66),
        "purple": material("Flower_Purple", (0.43, 0.18, 0.52, 1.0), 0.70),
        "pink": material("Flower_Pink", (0.90, 0.36, 0.49, 1.0), 0.62),
        "brown": material("Flower_Center", (0.20, 0.085, 0.025, 1.0), 0.92),
        "aloe": material("Aloe", (0.12, 0.39, 0.20, 1.0), 0.62),
        "aloe_edge": material("Aloe_Edge", (0.42, 0.68, 0.30, 1.0), 0.70),
        "silver": material("Silver_Leaf", (0.25, 0.40, 0.29, 1.0), 0.80),
    }


def radial_direction(angle: float, up: float = 0.28) -> Vector:
    return Vector((math.cos(angle), math.sin(angle), up)).normalized()


def generate_monstera(m):
    for i in range(11):
        threshold = 0.08 + i * 0.068
        angle = i * 2.399
        stem_end = Vector((0.09 * math.cos(angle), 0.09 * math.sin(angle), 0.34 + i * 0.043))
        cylinder_between(growth_name("stem", threshold, f"monstera_{i}"), Vector((0, 0, 0.24)), stem_end, 0.011 + i * 0.0005, m["stem"])
        direction = radial_direction(angle, 0.20 + 0.035 * i)
        leaf(f"monstera_{i}", stem_end, direction, 0.34 + 0.018 * i, 0.25 + 0.012 * i, m["leaf"], threshold, "spade", 0.075, 0.08, m["vein"], 14)


def generate_alocasia(m):
    for i in range(8):
        threshold = 0.10 + i * 0.09
        angle = i * 2.21
        end = Vector((0.11 * math.cos(angle), 0.11 * math.sin(angle), 0.36 + i * 0.045))
        cylinder_between(growth_name("stem", threshold, f"alocasia_{i}"), Vector((0, 0, 0.24)), end, 0.010, m["stem_light"])
        leaf(f"alocasia_{i}", end, radial_direction(angle, 0.12), 0.38 + 0.025 * i, 0.28 + 0.012 * i, m["leaf"], threshold, "spade", 0.055, 0.0, m["vein"], 13)


def generate_pothos(m):
    vine_points = [Vector((0, 0, 0.27))]
    for i in range(11):
        t = (i + 1) / 11.0
        vine_points.append(Vector((0.30 * math.sin(t * 4.5), 0.20 * math.cos(t * 3.6), 0.30 - t * 0.25)))
    for i in range(11):
        threshold = 0.08 + i * 0.075
        cylinder_between(growth_name("vine", threshold, f"pothos_{i}"), vine_points[i], vine_points[i + 1], 0.006, m["stem_light"], 7)
        angle = i * 2.53
        direction = radial_direction(angle, 0.10)
        leaf(f"pothos_{i}", vine_points[i + 1], direction, 0.18 + i * 0.006, 0.15 + i * 0.005, m["leaf_mid"] if i % 3 else m["leaf_light"], threshold, "heart", 0.03, 0.0, m["vein"], 10)


def generate_snake_plant(m):
    for i in range(15):
        threshold = 0.06 + i * 0.058
        angle = i * 2.399
        base = Vector((0.07 * math.cos(angle), 0.07 * math.sin(angle), 0.24))
        height = 0.35 + (i % 5) * 0.11
        direction = Vector((0.10 * math.cos(angle), 0.10 * math.sin(angle), 1.0)).normalized()
        leaf(f"snake_{i}", base, direction, height, 0.075 + (i % 3) * 0.012, m["leaf_mid"] if i % 2 else m["leaf"], threshold, "blade", 0.025, 0.04, m["vein"], 11)


def generate_peace_lily(m):
    for i in range(12):
        threshold = 0.07 + i * 0.055
        angle = i * 2.399
        end = Vector((0.07 * math.cos(angle), 0.07 * math.sin(angle), 0.29 + (i % 4) * 0.045))
        cylinder_between(growth_name("stem", threshold, f"peace_{i}"), Vector((0, 0, 0.24)), end, 0.007, m["stem"])
        leaf(f"peace_{i}", end, radial_direction(angle, 0.24), 0.30 + (i % 4) * 0.04, 0.115 + (i % 3) * 0.014, m["leaf"], threshold, "lance", 0.055, 0.0, m["vein"], 12)
    for i in range(3):
        threshold = 0.70 + i * 0.08
        angle = i * 2.3 + 0.6
        end = Vector((0.08 * math.cos(angle), 0.08 * math.sin(angle), 0.74 + i * 0.08))
        cylinder_between(growth_name("flower_stem", threshold, f"peace_{i}"), Vector((0, 0, 0.25)), end, 0.007, m["stem_light"])
        leaf(f"peace_flower_{i}", end, radial_direction(angle, 0.35), 0.19, 0.10, m["white"], threshold, "spade", 0.045, 0.0, None, 10)
        cylinder_between(growth_name("spadix", threshold, f"peace_{i}"), end + Vector((0, 0, 0.015)), end + Vector((0, 0, 0.13)), 0.012, m["yellow"], 8)


def generate_boston_fern(m):
    for i in range(12):
        threshold = 0.06 + i * 0.06
        angle = i * 2.399
        start = Vector((0, 0, 0.25))
        end = Vector((0.34 * math.cos(angle), 0.34 * math.sin(angle), 0.50 + (i % 3) * 0.07))
        cylinder_between(growth_name("frond", threshold, f"fern_{i}"), start, end, 0.005, m["stem_light"], 7)
        axis = (end - start).normalized()
        side = axis.cross(Vector((0, 0, 1))).normalized()
        if side.length < 0.1:
            side = Vector((1, 0, 0))
        for j in range(1, 9):
            t = j / 10.0
            base = start.lerp(end, t)
            size = 0.12 * (1.0 - 0.45 * t)
            for sign in (-1, 1):
                direction = (side * sign + axis * 0.30 + Vector((0, 0, 0.08))).normalized()
                leaf(f"fern_{i}_{j}_{sign}", base, direction, size, size * 0.36, m["leaf_mid"], min(0.95, threshold + j * 0.012), "lance", 0.012, 0.0, None, 6)


def generate_lily(m):
    for i in range(7):
        threshold = 0.06 + i * 0.07
        angle = i * 2.399
        base = Vector((0.03 * math.cos(angle), 0.03 * math.sin(angle), 0.24))
        end = Vector((0.07 * math.cos(angle), 0.07 * math.sin(angle), 0.52 + i * 0.075))
        cylinder_between(growth_name("stem", threshold, f"lily_{i}"), base, end, 0.009, m["stem_light"])
        if i < 6:
            leaf(f"lily_leaf_{i}", base + Vector((0, 0, 0.12 + i * 0.06)), radial_direction(angle, 0.18), 0.30, 0.07, m["leaf_mid"], threshold + 0.04, "lance", 0.035, 0.0, m["vein"], 9)
        if i >= 4:
            bloom = min(0.92, threshold + 0.24)
            petal_ring(f"lily_bloom_{i}", end, 6, 0.16, 0.07, m["white"] if i % 2 else m["pink"], bloom, 0.22)
            sphere(growth_name("stamen", bloom, f"lily_{i}"), end + Vector((0, 0, 0.025)), 0.025, m["yellow"], (1, 1, 0.7))


def generate_sunflower(m):
    start = Vector((0, 0, 0.24))
    end = Vector((0, 0, 1.15))
    cylinder_between(growth_name("stem", 0.08, "sunflower"), start, end, 0.024, m["stem_light"], 12)
    for i in range(7):
        threshold = 0.12 + i * 0.09
        z = 0.38 + i * 0.10
        angle = i * 2.3
        base = Vector((0, 0, z))
        leaf(f"sunflower_leaf_{i}", base, radial_direction(angle, 0.12), 0.31, 0.18, m["leaf_mid"], threshold, "heart", 0.055, 0.10, m["vein"], 11)
    bloom = 0.78
    petal_ring("sunflower_petal", end, 22, 0.23, 0.08, m["yellow"], bloom, 0.05)
    sphere(growth_name("flower_center", bloom, "sunflower"), end + Vector((0, 0, 0.01)), 0.15, m["brown"], (1.0, 1.0, 0.30))


def generate_lavender(m):
    for i in range(24):
        threshold = 0.05 + i * 0.033
        angle = i * 2.399
        radius = 0.02 + (i % 5) * 0.012
        start = Vector((radius * math.cos(angle), radius * math.sin(angle), 0.24))
        end = Vector((radius * 1.7 * math.cos(angle), radius * 1.7 * math.sin(angle), 0.48 + (i % 7) * 0.045))
        cylinder_between(growth_name("stem", threshold, f"lavender_{i}"), start, end, 0.0045, m["silver"], 7)
        for j in range(4):
            bud = end - Vector((0, 0, j * 0.035))
            sphere(growth_name("bud", min(0.96, threshold + 0.18), f"lavender_{i}_{j}"), bud, 0.022, m["purple"], (0.75, 0.75, 1.25))
        if i % 2 == 0:
            leaf(f"lavender_leaf_{i}", start + Vector((0, 0, 0.12)), radial_direction(angle, 0.10), 0.12, 0.025, m["silver"], threshold, "lance", 0.01, 0.0, None, 6)


def generate_mint(m):
    for i in range(10):
        threshold = 0.06 + i * 0.07
        angle = i * 2.399
        base = Vector((0.05 * math.cos(angle), 0.05 * math.sin(angle), 0.24))
        end = Vector((0.10 * math.cos(angle), 0.10 * math.sin(angle), 0.48 + (i % 5) * 0.07))
        cylinder_between(growth_name("stem", threshold, f"mint_{i}"), base, end, 0.006, m["stem_light"], 7)
        axis = (end - base).normalized()
        for j in range(3):
            level = base.lerp(end, 0.35 + j * 0.22)
            side_angle = angle + j * 1.45
            for sign in (-1, 1):
                direction = radial_direction(side_angle + (math.pi if sign < 0 else 0), 0.18)
                leaf(f"mint_{i}_{j}_{sign}", level, direction, 0.13, 0.075, m["leaf_light"] if (i + j) % 3 == 0 else m["leaf_mid"], min(0.95, threshold + j * 0.035), "ellipse", 0.025, 0.16, m["vein"], 9)


def generate_aloe(m):
    for ring in range(3):
        count = 7 + ring * 3
        for i in range(count):
            threshold = 0.05 + (ring * 10 + i) * 0.026
            angle = math.tau * i / count + ring * 0.45
            base = Vector((0.025 * math.cos(angle), 0.025 * math.sin(angle), 0.24))
            direction = radial_direction(angle, 0.76 - ring * 0.17)
            leaf(f"aloe_{ring}_{i}", base, direction, 0.34 + ring * 0.06, 0.095 + ring * 0.018, m["aloe"], threshold, "blade", 0.08, 0.10, m["aloe_edge"], 10)


def generate_echeveria(m):
    index = 0
    for ring, (count, length, width, up) in enumerate(((8, 0.15, 0.105, 0.62), (11, 0.22, 0.13, 0.38), (15, 0.29, 0.15, 0.20))):
        for i in range(count):
            threshold = 0.04 + index * 0.024
            index += 1
            angle = math.tau * i / count + ring * 0.37
            base = Vector((0.0, 0.0, 0.245 + ring * 0.012))
            leaf(f"echeveria_{ring}_{i}", base, radial_direction(angle, up), length, width, m["aloe_edge"] if (i + ring) % 4 else m["aloe"], threshold, "spade", 0.06, 0.0, m["vein"], 9)


PLANT_BUILDERS = {
    "monstera_deliciosa": generate_monstera,
    "alocasia_polly": generate_alocasia,
    "golden_pothos": generate_pothos,
    "snake_plant": generate_snake_plant,
    "peace_lily": generate_peace_lily,
    "boston_fern": generate_boston_fern,
    "lily": generate_lily,
    "sunflower": generate_sunflower,
    "lavender": generate_lavender,
    "mint": generate_mint,
    "aloe_vera": generate_aloe,
    "echeveria": generate_echeveria,
}


def export_glb(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_apply=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
    )


def scene_bounds(objects):
    corners = []
    for obj in objects:
        if obj.type == "MESH":
            corners.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if not corners:
        raise RuntimeError("Imported file contains no mesh bounds")
    minimum = Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners)))
    maximum = Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners)))
    return minimum, maximum


def normalize_imported(objects, target_max_dimension: float) -> None:
    minimum, maximum = scene_bounds(objects)
    size = maximum - minimum
    scale = target_max_dimension / max(size.x, size.y, size.z, 0.001)
    center = Vector(((minimum.x + maximum.x) * 0.5, (minimum.y + maximum.y) * 0.5, minimum.z))
    transform = Matrix.Scale(scale, 4) @ Matrix.Translation(-center)
    object_set = set(objects)
    for obj in objects:
        if obj.parent not in object_set:
            obj.matrix_world = transform @ obj.matrix_world


def convert_prop(slug: str, relative_path: str, target_max_dimension: float) -> None:
    source = SOURCE_ROOT / relative_path
    if not source.exists():
        print(f"ASSET_SKIP {slug}: missing {source}")
        return
    reset_scene()
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(source))
    imported = [obj for obj in bpy.data.objects if obj not in before]
    for obj in list(imported):
        if obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj, do_unlink=True)
            imported.remove(obj)
    normalize_imported(imported, target_max_dimension)
    for obj in imported:
        smooth_mesh(obj)
    output = PROP_ROOT / f"{slug}.glb"
    export_glb(output)
    minimum, maximum = scene_bounds(imported)
    size = maximum - minimum
    print(f"ASSET_PROP {slug}: objects={len(imported)} size=({size.x:.3f},{size.y:.3f},{size.z:.3f}) output={output}")


def build_plant(slug: str, builder) -> None:
    reset_scene()
    add_standard_pot()
    mats = common_materials()
    builder(mats)
    output = PLANT_ROOT / f"{slug}.glb"
    export_glb(output)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    vertices = sum(len(obj.data.vertices) for obj in meshes)
    triangles = sum(len(obj.data.loop_triangles) for obj in meshes)
    print(f"ASSET_PLANT {slug}: meshes={len(meshes)} vertices={vertices} triangles={triangles} output={output}")


def main() -> None:
    for slug, (relative_path, target_dimension) in PROP_SOURCES.items():
        convert_prop(slug, relative_path, target_dimension)
    for slug, builder in PLANT_BUILDERS.items():
        build_plant(slug, builder)
    print(f"ASSET_BUILD_COMPLETE props={len(PROP_SOURCES)} plants={len(PLANT_BUILDERS)}")


if __name__ == "__main__":
    main()
