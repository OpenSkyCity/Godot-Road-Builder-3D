extends Spatial

var current_building: BuildingType
export(NodePath) var road_network_path
onready var road_network = get_node(road_network_path) as RoadNetwork
export(NodePath) var buildings_path
onready var buildings = get_node(buildings_path)
export(NodePath) var quad_tree_path
onready var quad_tree = get_node(quad_tree_path)

var ghost_instance: Spatial
var enabled
func _input(event):
	if event is InputEventKey:
		if event.scancode == KEY_G and event.pressed:
			enabled = !enabled
			if enabled:
				if current_building:
					ghost_instance = current_building.instance()
					buildings.add_child(ghost_instance)
			elif !enabled:
				if ghost_instance:
					buildings.remove_child(ghost_instance)
					ghost_instance.queue_free()
	if !enabled:
		return
	if event is InputEventKey:
		if event.scancode == KEY_0:
			current_building = BuildingType.new("test_id", "Test Name", load("res://models/building1.tscn"))
			if ghost_instance:
				buildings.remove_child(ghost_instance)
				ghost_instance.queue_free()
			ghost_instance = current_building.instance()
			buildings.add_child(ghost_instance)

	if event is InputEventMouseMotion:
		if current_building:
			var building_point = _cast_ray_to(event.position)
			building_point = building_point.snapped(Vector3(0.25, 0, 0.25))
			var buildings = quad_tree.query(get_aabb())
			if !buildings:
				# material overlay
				test_and_set_material(preload("res://building_system/buildable.tres"))
			else:
				test_and_set_material_overlay(preload("res://building_system/non_buildable.tres"))
				
			if is_vec_nan(building_point):
				return
#			print(building_point)
			var segment = road_network.get_closest_segment(building_point)
			if segment:
				var closest_point = segment.project_point(building_point)
				var direction = (closest_point - building_point).normalized()

				
				var point: Vector3 = closest_point + direction * (-segment.road_network_info.width/2 + -1)
				
				var building_transform = Transform.IDENTITY
				point.y = 0.02
				var b_scale = ghost_instance.global_transform.basis.get_scale()
				building_transform.origin = point

				var a = closest_point - point
				var b = current_building.door_face_direction
				var angle_a = atan2(a.z, a.x)
				var angle_b = atan2(b.z, b.x)
				var angle = angle_b - angle_a
				
				building_transform.basis = building_transform.basis.rotated(Vector3.UP, angle)
				building_transform.basis = building_transform.basis.scaled(b_scale)
				ghost_instance.global_transform = building_transform

			else:
				building_point.y = 0.02
				ghost_instance.global_transform.origin = building_point
				
	
	if event is InputEventMouseButton:
		if current_building and event.button_index == BUTTON_LEFT and event.pressed:
			
			var building_point = _cast_ray_to(event.position)
			if is_vec_nan(building_point):
				return
			building_point.y = 0.02
			building_point = building_point.snapped(Vector3(0.25, 0, 0.25))
			var segment = road_network.get_closest_segment(building_point)
			if segment:
				var closest_point = segment.project_point(building_point)
				var direction = (closest_point - building_point).normalized()
				var point = closest_point + direction * (-segment.road_network_info.width/2 + -1)
				var building_transform = Transform.IDENTITY
				var b_scale = ghost_instance.global_transform.basis.get_scale()
				point.y = 0.02
				building_transform.origin = point
				
				var a = closest_point - point
				var b = current_building.door_face_direction
				var angle_a = atan2(a.z, a.x)
				var angle_b = atan2(b.z, b.x)
				var angle = angle_b - angle_a
				
				building_transform.basis = building_transform.basis.rotated(Vector3.UP, angle)
				building_transform.basis = building_transform.basis.scaled(b_scale)
				var new_building = current_building.instance()
				buildings.add_child(new_building)
				new_building.global_transform = building_transform
				quad_tree.add_body(new_building, new_building.get_aabb())
				var expanded_aabb = new_building.get_aabb()
				DrawingUtils.draw_box_with_aabb($"ImmediateGeometry", expanded_aabb)

func get_aabb():
	return ghost_instance.get_aabb()

func test_and_set_material(p_material):
	var test_mesh = ghost_instance.get_child(0).get_child(ghost_instance._mesh_child_index_array[randi() % ghost_instance._mesh_child_index_array.size()]).mesh as Mesh
	var test_material = test_mesh.surface_get_material(randi() % test_mesh.get_surface_count())
	if test_material == p_material:
		for index in current_building._mesh_child_index_array:
			var child = ghost_instance.get_child(0).get_child(index) as MeshInstance
			for material_index in range(child.get_surface_material_count()):
				var material = child.mesh.surface_get_material(material_index)
				material = p_material
				child.mesh.surface_set_material(material_index, material)

func test_and_set_material_overlay(p_material):
	var test_mesh = ghost_instance.get_child(0).get_child(ghost_instance._mesh_child_index_array[randi() % ghost_instance._mesh_child_index_array.size()]).mesh as Mesh
	var test_material = test_mesh.surface_get_material(randi() % test_mesh.get_surface_count())
	if test_material == p_material:
		for index in current_building._mesh_child_index_array:
			var child = ghost_instance.get_child(0).get_child(index) as MeshInstance
			for material_index in range(child.get_surface_material_count()):
				var material = child.mesh.surface_get_material(material_index)
				material.next_pass = p_material
				child.mesh.surface_set_material(material_index, material)

#func _process(delta):
#	print("------------------------------------------")
#	print_stray_nodes()
#	print("-------------------------------------------")
#
# attempt - 1: failed
#var building_transform = Transform.IDENTITY
#building_transform.origin = point
#var new_transform = building_transform.looking_at(closest_point, Vector3.UP)
#new_transform = new_transform.rotated(Vector3.UP, deg2rad(90))
#new_transform.basis.x = Vector3(1, 0, 0)
#new_transform = new_transform.scaled(Vector3(2, 2, 2))
#ghost_instance.global_transform = new_transform
	
##				ghost_instance.global_transform = new_transform
#				prints(rad2deg(closest_point_dir.angle_to(door_face_dir)), closest_point_dir, door_face_dir)

##				building_transform.basis = Basis(door_face_dir.cross(closest_point_dir))
#				building_transform.basis = Basis(Vector3.UP, atan2(-building_face_dir.z, building_face_dir.x))
#				print(building_transform.basis.get_euler())
#				print(door_face_dir.cross(closest_point_dir).normalized())

#				direction.y = 0
#				print(direction)
#				new_transform = new_transform.rotated(Vector3.UP, door_face_dir.dot(closest_point_dir))
# var door_face_dir = current_building.door_face_direction
#				var closest_point_dir = closest_point - point
#				direction.y = 0
#				var building_face_dir = closest_point_dir - door_face_dir
#
#				building_transform = building_transform.rotated(Vector3.UP, atan2(-building_face_dir.z, building_face_dir.x))

func _cast_ray_to(postion: Vector2):
	var camera = get_viewport().get_camera()
	var from = camera.project_ray_origin(postion)
	var to = from + camera.project_ray_normal(postion) * camera.far
	return get_world().direct_space_state.intersect_ray(from, to).get("position", Vector3(NAN, NAN, NAN))

func is_vec_nan(vec) -> bool:
	if typeof(vec) == TYPE_VECTOR3:
		return is_nan(vec.x) and is_nan(vec.y) and is_nan(vec.z)
	if typeof(vec) == TYPE_VECTOR2:
		return is_nan(vec.x) and is_nan(vec.y)
	if typeof(vec) == TYPE_REAL:
		return is_nan(vec)
	return false
